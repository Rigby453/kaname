// Чистые функции для расчёта статистики сна.
// Не зависят от Flutter/Riverpod — легко тестировать.

import '../../core/database/database.dart';

/// Длительность ночи. Если endAt == null — возвращает Duration.zero.
Duration nightDuration(SleepLogsTableData log) {
  final end = log.endAt;
  if (end == null) return Duration.zero;
  return end.difference(log.startAt);
}

/// Часы сна по дням за последние [days] дней (включая [today]).
/// День определяется по дате endAt (день пробуждения).
/// Если за один день несколько записей — суммируются.
/// Возвращает список длиной [days]; индекс 0 — самый старый день, последний — [today].
/// Дни без записей имеют hours == 0.0.
List<({DateTime day, double hours})> nightlyHours(
  List<SleepLogsTableData> logs,
  DateTime today,
  int days,
) {
  // Строим карту: дата (UTC-полночь) → суммарные часы
  final map = <DateTime, double>{};

  for (final log in logs) {
    final end = log.endAt;
    if (end == null) continue;
    final bucket = DateTime.utc(end.year, end.month, end.day);
    final hours = end.difference(log.startAt).inSeconds / 3600.0;
    map[bucket] = (map[bucket] ?? 0.0) + hours;
  }

  // Генерируем слоты для последних [days] дней
  final todayUtc = DateTime.utc(today.year, today.month, today.day);
  return List.generate(days, (i) {
    final day = todayUtc.subtract(Duration(days: days - 1 - i));
    return (day: day, hours: map[day] ?? 0.0);
  });
}
