// Юнит-тесты чистой функции nextInstanceAfterNow.
//
// Корневая причина бага D1 (залп ~10 уведомлений на холодном старте):
//   rescheduleAllReminders() после D1 использует exactAllowWhileIdle.
//   Если первый TZDateTime был в прошлом — exact-alarm срабатывает немедленно.
//   Функция nextInstanceAfterNow гарантирует, что первое вхождение ВСЕГДА
//   строго в будущем. Эти тесты доказывают инвариант без мока плагина.
//
// Не трогаем: notification_schedule_mode_test.dart (другой файл, свой scope).
//
// Что тестируем:
//   • время в прошлом → +1 день
//   • время в будущем → сегодня
//   • ровно now (граница) → +1 день (isAfter строгое, == считается прошлым)
//   • с минутами (обе стороны границы)
//   • граничные даты (конец месяца, конец года, полночь)
//   • все 5 слотов осанки [10,12,14,16,18] при старте в 12:35 (сценарий бага)

import 'package:app/services/notifications/notification_service.dart'
    show nextInstanceAfterNow;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location utc;

  setUpAll(() {
    // Инициализируем базу часовых поясов один раз для всех тестов.
    // UTC не зависит от DST — детерминированные результаты на любой машине.
    tzdata.initializeTimeZones();
  });

  setUp(() {
    utc = tz.getLocation('UTC');
  });

  // ---------------------------------------------------------------------------
  // Базовые кейсы (требование задачи)
  // ---------------------------------------------------------------------------

  group('nextInstanceAfterNow — базовые кейсы', () {
    test('время раньше now сегодня → завтра', () {
      // Сценарий бага: старт в 12:35, утренний разбор в 08:00 → должен быть завтра.
      final now = tz.TZDateTime(utc, 2024, 6, 15, 12, 35);
      final result = nextInstanceAfterNow(8, 0, now);
      expect(result.day, 16, reason: 'прошедшее время → следующий день');
      expect(result.hour, 8);
      expect(result.minute, 0);
      expect(result.isAfter(now), isTrue,
          reason: 'результат всегда строго после now');
    });

    test('время позже now сегодня → сегодня', () {
      // 07:00 → вечерний разбор 20:00 ещё впереди → сегодня.
      final now = tz.TZDateTime(utc, 2024, 6, 15, 7, 0);
      final result = nextInstanceAfterNow(20, 0, now);
      expect(result.day, 15, reason: 'будущее время → тот же день');
      expect(result.hour, 20);
      expect(result.isAfter(now), isTrue);
    });

    test('ровно now (==) → следующее вхождение (+1 день)', () {
      // isAfter строгое: scheduled == now → NOT isAfter → +1 день.
      // Крайний случай: алармы с нулевым опережением стреляют немедленно.
      final now = tz.TZDateTime(utc, 2024, 6, 15, 8, 0);
      final result = nextInstanceAfterNow(8, 0, now);
      expect(result.day, 16,
          reason: 'ровно now не считается "строго в будущем" → завтра');
      expect(result.isAfter(now), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Проверки с ненулевыми минутами
  // ---------------------------------------------------------------------------

  group('nextInstanceAfterNow — с минутами', () {
    test('08:29 → target 08:30 → сегодня', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 8, 29);
      final result = nextInstanceAfterNow(8, 30, now);
      expect(result.day, 15);
      expect(result.minute, 30);
      expect(result.isAfter(now), isTrue);
    });

    test('08:31 → target 08:30 → завтра', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 8, 31);
      final result = nextInstanceAfterNow(8, 30, now);
      expect(result.day, 16);
      expect(result.isAfter(now), isTrue);
    });

    test('08:30 ровно → target 08:30 → завтра (граница)', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 8, 30);
      final result = nextInstanceAfterNow(8, 30, now);
      expect(result.day, 16,
          reason: 'ровно на минуте — тот же edge-case что и ровно now');
      expect(result.isAfter(now), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Граничные даты
  // ---------------------------------------------------------------------------

  group('nextInstanceAfterNow — граничные даты', () {
    test('конец месяца → переход на 1-е следующего месяца', () {
      final now = tz.TZDateTime(utc, 2024, 6, 30, 12, 0);
      final result = nextInstanceAfterNow(8, 0, now);
      expect(result.year, 2024);
      expect(result.month, 7);
      expect(result.day, 1);
      expect(result.isAfter(now), isTrue);
    });

    test('конец года → переход на 1 января следующего года', () {
      final now = tz.TZDateTime(utc, 2024, 12, 31, 23, 0);
      final result = nextInstanceAfterNow(20, 0, now);
      expect(result.year, 2025);
      expect(result.month, 1);
      expect(result.day, 1);
      expect(result.isAfter(now), isTrue);
    });

    test('полночь: 00:01 → target 00:00 → завтра', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 0, 1);
      final result = nextInstanceAfterNow(0, 0, now);
      expect(result.day, 16);
      expect(result.isAfter(now), isTrue);
    });

    test('за минуту до полуночи: 23:59 → target 23:00 → завтра', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 23, 59);
      final result = nextInstanceAfterNow(23, 0, now);
      expect(result.day, 16);
      expect(result.isAfter(now), isTrue);
    });

    test('февраль → переход на 1 марта (не-висок. год)', () {
      final now = tz.TZDateTime(utc, 2023, 2, 28, 12, 0);
      final result = nextInstanceAfterNow(8, 0, now);
      expect(result.month, 3);
      expect(result.day, 1);
      expect(result.isAfter(now), isTrue);
    });

    test('февраль → переход на 29-е (високос. год 2024)', () {
      final now = tz.TZDateTime(utc, 2024, 2, 28, 12, 0);
      final result = nextInstanceAfterNow(8, 0, now);
      expect(result.month, 2);
      expect(result.day, 29, reason: '2024 — високосный, февраль имеет 29 дней');
      expect(result.isAfter(now), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Сценарий бага: все слоты осанки при старте в 12:35
  // ---------------------------------------------------------------------------

  group('nextInstanceAfterNow — осанка (воспроизводим баг D1)', () {
    // Слоты осанки: 10, 12, 14, 16, 18. При старте в 12:35:
    //   10:00 — прошло → должен быть завтра
    //   12:00 — прошло → должен быть завтра
    //   14:00 — в будущем → сегодня
    //   16:00 — в будущем → сегодня
    //   18:00 — в будущем → сегодня
    // Без fix все прошедшие exact-alarm стреляли бы немедленно.
    const postureHours = [10, 12, 14, 16, 18];

    test('все 5 слотов строго после now=12:35', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 12, 35);
      for (final h in postureHours) {
        final result = nextInstanceAfterNow(h, 0, now);
        expect(
          result.isAfter(now),
          isTrue,
          reason: 'слот $h:00 — ожидается строго в будущем, получено $result',
        );
      }
    });

    test('прошедшие слоты 10:00 и 12:00 → завтра', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 12, 35);
      expect(nextInstanceAfterNow(10, 0, now).day, 16,
          reason: '10:00 < 12:35 → следующий день');
      expect(nextInstanceAfterNow(12, 0, now).day, 16,
          reason: '12:00 < 12:35 → следующий день');
    });

    test('будущие слоты 14, 16, 18 → сегодня', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 12, 35);
      for (final h in [14, 16, 18]) {
        final result = nextInstanceAfterNow(h, 0, now);
        expect(result.day, 15,
            reason: '$h:00 > 12:35 → тот же день, получено $result');
      }
    });

    test('12:00 ровно (граница) → завтра, не немедленно', () {
      // Если old bug: exact-alarm на 12:00 при now=12:00 стрелял бы сразу.
      final now = tz.TZDateTime(utc, 2024, 6, 15, 12, 0);
      final result = nextInstanceAfterNow(12, 0, now);
      expect(result.day, 16,
          reason: 'ровно now — не «строго в будущем» → следующий день');
    });

    test('все слоты строго в будущем при старте в 00:01', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 0, 1);
      for (final h in postureHours) {
        expect(nextInstanceAfterNow(h, 0, now).isAfter(now), isTrue);
      }
    });

    test('все слоты строго в будущем при старте в 23:59', () {
      final now = tz.TZDateTime(utc, 2024, 6, 15, 23, 59);
      for (final h in postureHours) {
        expect(nextInstanceAfterNow(h, 0, now).isAfter(now), isTrue);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Проверки инварианта для всех 24 часов
  // ---------------------------------------------------------------------------

  group('nextInstanceAfterNow — инвариант для всех часов', () {
    test('результат всегда строго после now для любого часа и any "now"', () {
      final testNows = [
        tz.TZDateTime(utc, 2024, 6, 15, 0, 0),
        tz.TZDateTime(utc, 2024, 6, 15, 8, 0),
        tz.TZDateTime(utc, 2024, 6, 15, 12, 35),
        tz.TZDateTime(utc, 2024, 6, 15, 23, 59),
      ];
      for (final now in testNows) {
        for (var h = 0; h < 24; h++) {
          final result = nextInstanceAfterNow(h, 0, now);
          expect(
            result.isAfter(now),
            isTrue,
            reason: 'now=${now.hour}:${now.minute}, target=$h:00 → не в будущем',
          );
        }
      }
    });
  });
}
