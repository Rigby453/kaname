// Инфраструктура счётчика запусков приложения.
// Ключи SharedPreferences:
//   app_launch_count  — int, количество холодных стартов
//   first_launch_at   — ISO-строка, дата первого запуска
//
// Используется: E3 (in_app_review → rating_service.dart), G2 (геймификация).
// Инкремент вызывается ОДИН РАЗ за запуск — в main() до runApp().

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Ключи — экспортируются для тестов и сервисов
// ---------------------------------------------------------------------------

const String kLaunchCountKey = 'app_launch_count';
const String kFirstLaunchAtKey = 'first_launch_at';

// ---------------------------------------------------------------------------
// Чистые функции — тестируемы без Riverpod и Flutter
// ---------------------------------------------------------------------------

/// Текущий счётчик холодных стартов (0 если ещё не инициализирован).
int getLaunchCount(SharedPreferences prefs) =>
    prefs.getInt(kLaunchCountKey) ?? 0;

/// Дата первого запуска или null при ещё не зафиксированном старте.
DateTime? getFirstLaunchAt(SharedPreferences prefs) {
  final raw = prefs.getString(kFirstLaunchAtKey);
  return raw == null ? null : DateTime.tryParse(raw);
}

/// Количество полных дней с первого запуска; 0 если дата ещё не записана.
int getDaysSinceFirstLaunch(SharedPreferences prefs) {
  final first = getFirstLaunchAt(prefs);
  if (first == null) return 0;
  return DateTime.now().difference(first).inDays;
}

/// Инкрементирует счётчик запусков.
/// При первом вызове (count == 0) также фиксирует [kFirstLaunchAtKey].
/// Вызывать ровно ОДИН РАЗ за холодный старт (в main(), до runApp()).
Future<void> incrementLaunchCount(SharedPreferences prefs) async {
  final count = getLaunchCount(prefs);
  if (count == 0) {
    // Первый запуск — сохраняем дату
    await prefs.setString(kFirstLaunchAtKey, DateTime.now().toIso8601String());
  }
  await prefs.setInt(kLaunchCountKey, count + 1);
}

// ---------------------------------------------------------------------------
// AppUsage — объект-обёртка с геттерами (для Riverpod-провайдера)
// ---------------------------------------------------------------------------

class AppUsage {
  const AppUsage(this._prefs);
  final SharedPreferences _prefs;

  /// Сколько раз запущено приложение (включая текущий запуск).
  int get launchCount => getLaunchCount(_prefs);

  /// Когда первый раз запустили приложение; null до первого инкремента.
  DateTime? get firstLaunchAt => getFirstLaunchAt(_prefs);

  /// Дней с первого запуска (0 если дата не зафиксирована).
  int get daysSinceFirstLaunch => getDaysSinceFirstLaunch(_prefs);
}

/// Провайдер AppUsage. Данные уже в памяти к моменту build() — синхронный.
/// Стадия G2 читает launchCount / firstLaunchAt / daysSinceFirstLaunch отсюда.
final appUsageProvider = Provider<AppUsage>((ref) {
  return AppUsage(ref.watch(sharedPreferencesProvider));
});
