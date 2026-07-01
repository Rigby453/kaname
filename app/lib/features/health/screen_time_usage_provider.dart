// Провайдер реального использования экранного времени на Android.
//
// Читает per-package usage через плагин usage_stats (требует спец-разрешение
// PACKAGE_USAGE_STATS — «Доступ к данным об использовании»), агрегирует минуты
// по нашим 6 категориям через categorizeUsageMinutes() и отдаёт UI:
//   - состояние разрешения (granted / denied / unknown),
//   - использованные минуты по категориям за сегодня (с локальной полуночи),
//   - сырые минуты по пакетам (для per-app breakdown),
//   - resolved-категории для каждого пакета (для отображения в per-app UI),
//   - loading / error.
//
// Платформенная защита: плагин дёргается ТОЛЬКО на Android. На iOS / web / в
// тестах провайдер сразу отдаёт «нет разрешения, пустые данные» и не падает.
// Блокировки приложений НЕТ — Android не позволяет обычным приложениям блокировать
// чужие приложения; мы только показываем использование и предупреждаем о лимите.
//
// Android-fallback: для пакетов, не найденных в нашем whitelist kPackageToCategory,
// запрашиваем ApplicationInfo.category через MethodChannel "kaizen/app_category".
// Это позволяет играм (CATEGORY_GAME=0) попасть в 'games', а не пропасть.
// При любой ошибке канала — пакеты уходят в 'other' (минуты не теряются).
//
// Пользовательские переопределения читаются из screenTimeOverridesProvider
// (SharedPreferences) и применяются с наивысшим приоритетом.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:usage_stats/usage_stats.dart';

import 'screen_time_categories.dart';
import 'screen_time_overrides_provider.dart';

/// Состояние разрешения на доступ к статистике использования.
enum UsagePermissionStatus { unknown, granted, denied }

/// Иммутабельное состояние экрана использования.
@immutable
class ScreenTimeUsageState {
  const ScreenTimeUsageState({
    this.permission = UsagePermissionStatus.unknown,
    this.usedMinutes = const <String, int>{},
    this.perPackageMinutes = const <String, int>{},
    this.perPackageCategories = const <String, String>{},
    this.isLoading = false,
    this.hasError = false,
  });

  /// Текущий статус разрешения.
  final UsagePermissionStatus permission;

  /// Использованные минуты по категориям (social/video/games/browsing/messaging/other).
  /// Пустая карта = нет данных (нет разрешения / не Android).
  final Map<String, int> usedMinutes;

  /// Сырые минуты по пакетам: packageName → minutes (до агрегации).
  /// Используется для per-app breakdown в UI. Пустая = нет данных.
  final Map<String, int> perPackageMinutes;

  /// Resolved-категория для каждого пакета: packageName → ourCategory.
  /// Учитывает пользовательские оверрайды, whitelist и android-категории.
  /// Используется в UI для отображения текущей категории конкретного приложения.
  final Map<String, String> perPackageCategories;

  /// Идёт загрузка/обновление.
  final bool isLoading;

  /// Произошла ошибка при запросе (плагин кинул исключение).
  final bool hasError;

  /// true, если можно показывать цифры использования.
  bool get isGranted => permission == UsagePermissionStatus.granted;

  ScreenTimeUsageState copyWith({
    UsagePermissionStatus? permission,
    Map<String, int>? usedMinutes,
    Map<String, int>? perPackageMinutes,
    Map<String, String>? perPackageCategories,
    bool? isLoading,
    bool? hasError,
  }) {
    return ScreenTimeUsageState(
      permission: permission ?? this.permission,
      usedMinutes: usedMinutes ?? this.usedMinutes,
      perPackageMinutes: perPackageMinutes ?? this.perPackageMinutes,
      perPackageCategories: perPackageCategories ?? this.perPackageCategories,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// Поддерживается ли реальный сбор статистики (только Android, не в вебе).
bool get _isAndroid {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid;
  } catch (_) {
    // В юнит-тестах Platform может бросать — считаем «не Android».
    return false;
  }
}

/// MethodChannel для получения Android-категорий пакетов.
/// Реализация на Kotlin-стороне — в MainActivity.kt.
const _kAppCategoryChannel = MethodChannel('kaizen/app_category');

/// Запрашивает Android-категории для списка пакетов и преобразует
/// в наши категориальные ключи через [androidCategoryToOurCategory].
/// Возвращает пустую карту если канал недоступен (не-Android, тесты, ошибка).
Future<Map<String, String>> _fetchAndroidCategoryOverrides(
  List<String> packages,
) async {
  if (packages.isEmpty) return const <String, String>{};
  try {
    final raw = await _kAppCategoryChannel.invokeMethod<Map<Object?, Object?>>(
      'getAppCategories',
      packages,
    );
    if (raw == null) return const <String, String>{};

    final result = <String, String>{};
    raw.forEach((pkg, cat) {
      final pkgStr = pkg as String?;
      final catInt = cat as int?;
      if (pkgStr == null || catInt == null) return;
      final ourCat = androidCategoryToOurCategory(catInt);
      if (ourCat != null) {
        result[pkgStr] = ourCat;
      }
      // null ourCat → пакет попадёт в 'other' внутри categorizeUsageMinutes
    });
    return result;
  } catch (_) {
    // Канал недоступен или ошибка прошивки — fallback: пакеты пойдут в 'other'.
    return const <String, String>{};
  }
}

class ScreenTimeUsageNotifier extends StateNotifier<ScreenTimeUsageState> {
  /// [ref] опционален — null допустим в тестах, где нотифайер создаётся напрямую.
  /// В production передаётся через StateNotifierProvider, чтобы читать overrides.
  ScreenTimeUsageNotifier([Ref? ref])
      : _ref = ref,
        super(const ScreenTimeUsageState()) {
    // Стартовая проверка разрешения + загрузка (без блокировки конструктора).
    if (_isAndroid) {
      refresh();
    } else {
      // Не-Android / тесты: сразу «нет разрешения», пустые данные.
      state = state.copyWith(permission: UsagePermissionStatus.denied);
    }
  }

  final Ref? _ref;

  /// Перепроверяет разрешение и, если оно есть, заново читает использование.
  /// Безопасно вызывать на любой платформе — на не-Android ничего не делает.
  Future<void> refresh() async {
    if (!_isAndroid) {
      state = state.copyWith(
        permission: UsagePermissionStatus.denied,
        usedMinutes: const <String, int>{},
        perPackageMinutes: const <String, int>{},
        perPackageCategories: const <String, String>{},
        isLoading: false,
        hasError: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final granted = (await UsageStats.checkUsagePermission()) ?? false;
      if (!granted) {
        state = state.copyWith(
          permission: UsagePermissionStatus.denied,
          usedMinutes: const <String, int>{},
          perPackageMinutes: const <String, int>{},
          perPackageCategories: const <String, String>{},
          isLoading: false,
        );
        return;
      }

      final (usedMinutes, perPackageMinutes, perPackageCategories) =
          await _queryTodayUsage();
      state = state.copyWith(
        permission: UsagePermissionStatus.granted,
        usedMinutes: usedMinutes,
        perPackageMinutes: perPackageMinutes,
        perPackageCategories: perPackageCategories,
        isLoading: false,
      );
    } catch (_) {
      // Плагин/прошивка (MIUI/HyperOS) могут вести себя нестабильно —
      // не роняем UI, показываем состояние ошибки.
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  /// Открывает системный экран «Доступ к данным об использовании», чтобы
  /// пользователь выдал разрешение. После возврата UI должен вызвать [refresh].
  Future<void> requestPermission() async {
    if (!_isAndroid) return;
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {
      // Игнорируем — пользователь увидит, что разрешение не выдано, после refresh.
    }
  }

  /// Запрашивает использование за сегодня (с локальной полуночи до «сейчас»),
  /// конвертирует мс → минуты и агрегирует по категориям.
  ///
  /// ВАЖНО: используем queryEvents() + реконструкцию из сырых событий, а НЕ
  /// queryAndAggregateUsageStats() — последний отдаёт ВЕСЬ totalTimeInForeground
  /// дневного бакета для любого пакета, чей бакет пересекается с окном
  /// [midnight, now), без клиппинга. Сразу после полуночи это даёт утечку
  /// вчерашнего использования в «сегодня» (баг ~8ч при реальном ~0). См.
  /// [computeForegroundMinutesFromEvents] в screen_time_categories.dart.
  ///
  /// Пользовательские оверрайды из [screenTimeOverridesProvider] применяются
  /// с наивысшим приоритетом (выше whitelist и android-категорий).
  ///
  /// Возвращает кортеж (usedMinutes, perPackageMinutes, perPackageCategories).
  Future<
      (
        Map<String, int>,
        Map<String, int>,
        Map<String, String>,
      )> _queryTodayUsage() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    final rawEvents = await UsageStats.queryEvents(midnight, now);

    // Конвертируем плагинные события (строковые поля) в плоские записи для
    // чистой функции — она ничего не знает о плагине и легко тестируется.
    final eventRecords = <UsageEventRecord>[];
    for (final event in rawEvents) {
      final package = event.packageName;
      final type = event.eventTypeValue;
      final tsMs = event.timeStampDate?.millisecondsSinceEpoch;
      if (package == null || type == null || tsMs == null) continue;
      eventRecords.add(
        UsageEventRecord(package: package, type: type, timestampMs: tsMs),
      );
    }

    // packageName → минуты в foreground за сегодня, уже клипованные к
    // [midnight, now] (ceil: 1–59 сек = 1 мин, чтобы короткие сессии,
    // например игра 30 сек ночью, не терялись при floor-делении на 60000).
    final rawPerPackageMinutes =
        computeForegroundMinutesFromEvents(eventRecords, midnight, now);

    // Убираем лаунчер/системный UI (#8) — Android считает их «в фокусе»
    // почти весь день, что без фильтрации завышает «Всего сегодня» в разы,
    // хотя реальные приложения по отдельности посчитаны верно.
    final perPackageMinutes = filterTrackedPackages(rawPerPackageMinutes);

    // Читаем пользовательские оверрайды (наивысший приоритет).
    // _ref может быть null в тестах — тогда оверрайдов нет.
    final userOverrides = _ref?.read(screenTimeOverridesProvider) ?? const <String, String>{};

    // Находим пакеты, которых НЕТ в нашем whitelist и НЕТ в user overrides —
    // для них нужен Android-fallback через ApplicationInfo.category.
    final unknownPackages = perPackageMinutes.keys
        .where((pkg) =>
            !kPackageToCategory.containsKey(pkg) &&
            !userOverrides.containsKey(pkg))
        .toList();

    // Запрашиваем Android-категории для неизвестных пакетов.
    // На не-Android / в тестах _fetchAndroidCategoryOverrides вернёт {}.
    final androidOverrides = _isAndroid
        ? await _fetchAndroidCategoryOverrides(unknownPackages)
        : const <String, String>{};

    // Агрегированные итоги по категориям.
    final usedMinutes = categorizeUsageMinutes(
      perPackageMinutes,
      androidCategoryOverrides: androidOverrides,
      userOverrides: userOverrides,
    );

    // Resolved-категория для каждого пакета (для per-app UI).
    final perPackageCategories = <String, String>{};
    for (final pkg in perPackageMinutes.keys) {
      perPackageCategories[pkg] = resolvePackageCategory(
        pkg,
        androidCategoryOverrides: androidOverrides,
        userOverrides: userOverrides,
      );
    }

    return (usedMinutes, perPackageMinutes, perPackageCategories);
  }
}

final screenTimeUsageProvider =
    StateNotifierProvider<ScreenTimeUsageNotifier, ScreenTimeUsageState>(
  // ref передаётся, чтобы нотифайер мог читать screenTimeOverridesProvider.
  (ref) => ScreenTimeUsageNotifier(ref),
);
