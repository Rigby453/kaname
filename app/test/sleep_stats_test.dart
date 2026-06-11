// Юнит-тесты для чистых функций sleep_stats.dart.
// Без Flutter-зависимостей: plain Dart + flutter_test.

import 'package:app/core/database/database.dart';
import 'package:app/features/health/sleep_stats.dart';
import 'package:flutter_test/flutter_test.dart';

// Хелпер: создать тестовую запись сна
SleepLogsTableData _log({
  required DateTime startAt,
  DateTime? endAt,
}) {
  return SleepLogsTableData(
    id: 'test-id',
    startAt: startAt,
    endAt: endAt,
    createdAt: startAt,
  );
}

void main() {
  group('nightDuration', () {
    test('обычная ночь: 7.5 часов', () {
      final log = _log(
        startAt: DateTime(2024, 1, 15, 23, 0),
        endAt: DateTime(2024, 1, 16, 6, 30),
      );
      final duration = nightDuration(log);
      expect(duration.inMinutes, 7 * 60 + 30);
    });

    test('endAt == null → Duration.zero', () {
      final log = _log(startAt: DateTime(2024, 1, 15, 23, 0));
      expect(nightDuration(log), Duration.zero);
    });
  });

  group('nightlyHours', () {
    test('пустой список → все нули', () {
      final today = DateTime(2024, 1, 20);
      final result = nightlyHours([], today, 7);
      expect(result, hasLength(7));
      expect(result.every((e) => e.hours == 0.0), isTrue);
    });

    test('обычная ночь через полночь попадает в день пробуждения', () {
      // Лёг 22:00 14-го, проснулся 06:00 15-го → 8 часов, день = 15-е
      final log = _log(
        startAt: DateTime.utc(2024, 1, 14, 22, 0),
        endAt: DateTime.utc(2024, 1, 15, 6, 0),
      );
      final today = DateTime.utc(2024, 1, 15);
      final result = nightlyHours([log], today, 7);

      // Индекс 6 — сегодня (15-е)
      expect(result.last.day, DateTime.utc(2024, 1, 15));
      expect(result.last.hours, closeTo(8.0, 0.001));

      // Остальные дни — нули
      for (var i = 0; i < 6; i++) {
        expect(result[i].hours, 0.0);
      }
    });

    test('два сегмента в один день суммируются', () {
      // Дневной сон 14:00–15:30 (1.5 ч) + ночь 23:00–06:00 (7 ч) — обе за 16-е
      final nap = _log(
        startAt: DateTime.utc(2024, 1, 16, 14, 0),
        endAt: DateTime.utc(2024, 1, 16, 15, 30),
      );
      final night = _log(
        startAt: DateTime.utc(2024, 1, 15, 23, 0),
        endAt: DateTime.utc(2024, 1, 16, 6, 0),
      );
      final today = DateTime.utc(2024, 1, 16);
      final result = nightlyHours([nap, night], today, 7);

      // Сегодня (индекс 6) должно быть 8.5 часов
      expect(result.last.hours, closeTo(8.5, 0.001));
    });

    test('список из 7 элементов; индекс 0 — самый старый день', () {
      final today = DateTime.utc(2024, 1, 20);
      final result = nightlyHours([], today, 7);
      // Индекс 0 — 7 дней назад, индекс 6 — сегодня
      expect(result[0].day, DateTime.utc(2024, 1, 14));
      expect(result[6].day, DateTime.utc(2024, 1, 20));
    });
  });
}
