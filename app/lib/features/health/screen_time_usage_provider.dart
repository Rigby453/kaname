// Провайдер реального использования экранного времени на Android.
//
// Читает per-package usage через плагин usage_stats (требует спец-разрешение
// PACKAGE_USAGE_STATS — «Доступ к данным об использовании»), агрегирует минуты
// по нашим 5 категориям через categorizeUsageMinutes() и отдаёт UI:
//   - состояние разрешения (granted / denied / unknown),
//   - использованные минуты по категориям за сегодня (с локальной полуночи),
//   - loading / error.
//
// Платформенная защита: плагин дёргается ТОЛЬКО на Android. На iOS / web / в
// тестах провайдер сразу отдаёт «нет разрешения, пустые данные» и не падает.
// Блокировки приложений НЕТ — Android не позволяет обычным приложениям блокировать
// чужие приложения; мы только показываем использование и предупреждаем о лимите.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:usage_stats/usage_stats.dart';

import 'screen_time_categories.dart';

/// Состояние разрешения на доступ к статистике использования.
enum UsagePermissionStatus { unknown, granted, denied }

/// Иммутабельное состояние экрана использования.
@immutable
class ScreenTimeUsageState {
  const ScreenTimeUsageState({
    this.permission = UsagePermissionStatus.unknown,
    this.usedMinutes = const <String, int>{},
    this.isLoading = false,
    this.hasError = false,
  });

  /// Текущий статус разрешения.
  final UsagePermissionStatus permission;

  /// Использованные минуты по категориям (social/video/games/browsing/messaging).
  /// Пустая карта = нет данных (нет разрешения / не Android).
  final Map<String, int> usedMinutes;

  /// Идёт загрузка/обновление.
  final bool isLoading;

  /// Произошла ошибка при запросе (плагин кинул исключение).
  final bool hasError;

  /// true, если можно показывать цифры использования.
  bool get isGranted => permission == UsagePermissionStatus.granted;

  ScreenTimeUsageState copyWith({
    UsagePermissionStatus? permission,
    Map<String, int>? usedMinutes,
    bool? isLoading,
    bool? hasError,
  }) {
    return ScreenTimeUsageState(
      permission: permission ?? this.permission,
      usedMinutes: usedMinutes ?? this.usedMinutes,
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

class ScreenTimeUsageNotifier extends StateNotifier<ScreenTimeUsageState> {
  ScreenTimeUsageNotifier() : super(const ScreenTimeUsageState()) {
    // Стартовая проверка разрешения + загрузка (без блокировки конструктора).
    if (_isAndroid) {
      refresh();
    } else {
      // Не-Android / тесты: сразу «нет разрешения», пустые данные.
      state = state.copyWith(permission: UsagePermissionStatus.denied);
    }
  }

  /// Перепроверяет разрешение и, если оно есть, заново читает использование.
  /// Безопасно вызывать на любой платформе — на не-Android ничего не делает.
  Future<void> refresh() async {
    if (!_isAndroid) {
      state = state.copyWith(
        permission: UsagePermissionStatus.denied,
        usedMinutes: const <String, int>{},
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
          isLoading: false,
        );
        return;
      }

      final used = await _queryTodayUsage();
      state = state.copyWith(
        permission: UsagePermissionStatus.granted,
        usedMinutes: used,
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
  Future<Map<String, int>> _queryTodayUsage() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    final perPackageStats =
        await UsageStats.queryAndAggregateUsageStats(midnight, now);

    // packageName → минуты в foreground за сегодня.
    final perPackageMinutes = <String, int>{};
    perPackageStats.forEach((package, info) {
      final ms = info.totalTimeInForegroundMs ?? 0;
      if (ms <= 0) return;
      final minutes = ms ~/ 60000; // мс → целые минуты
      if (minutes <= 0) return;
      perPackageMinutes[package] = minutes;
    });

    return categorizeUsageMinutes(perPackageMinutes);
  }
}

final screenTimeUsageProvider =
    StateNotifierProvider<ScreenTimeUsageNotifier, ScreenTimeUsageState>(
  (ref) => ScreenTimeUsageNotifier(),
);
