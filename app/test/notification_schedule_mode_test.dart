// Юнит-тесты надёжности уведомлений (D1):
//
//  1. resolveScheduleMode — чистая функция выбора AndroidScheduleMode;
//     проверяем все три случая (null / true / false) без мока плагина.
//
//  2. taskReminderId — стабильность и диапазон хэша.
//
//  3. rescheduleAllReminders — условная логика: правильный набор методов
//     вызывается в зависимости от флагов reviewsEnabled / postureEnabled.
//     Реальный плагин не используется: методы overriding через подкласс,
//     ни одного вызова MethodChannel.

import 'package:app/services/notifications/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Подкласс-заглушка для тестирования rescheduleAllReminders
// без вызова платформенных каналов (нет MethodChannel).
// ---------------------------------------------------------------------------

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService()
      : super(
          // Конструктор FlutterLocalNotificationsPlugin создаёт MethodChannel
          // лениво — вызова канала не будет, пока мы не вызываем методы плагина.
          // Все методы, обращающиеся к плагину, переопределены ниже.
          FlutterLocalNotificationsPlugin(),
        );

  // Журнал вызовов: ключ → список аргументов.
  final List<String> calls = [];

  @override
  Future<void> init() async {
    // no-op: не вызываем tzdata, FlutterTimezone, MethodChannel.
  }

  @override
  Future<void> scheduleDailyReviews({
    int morningHour = kMorningHour,
    int eveningHour = kEveningHour,
  }) async {
    calls.add('reviews($morningHour,$eveningHour)');
  }

  @override
  Future<void> schedulePostureReminders() async {
    calls.add('posture');
  }
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. resolveScheduleMode — чистая функция, no-mock
  // -------------------------------------------------------------------------
  group('resolveScheduleMode', () {
    test(
        'null (старый Android / ответ недоступен) → exactAllowWhileIdle',
        () {
      expect(
        resolveScheduleMode(null),
        AndroidScheduleMode.exactAllowWhileIdle,
      );
    });

    test('true (разрешение выдано) → exactAllowWhileIdle', () {
      expect(
        resolveScheduleMode(true),
        AndroidScheduleMode.exactAllowWhileIdle,
      );
    });

    test(
        'false (разрешение не выдано, Android 12+) → inexactAllowWhileIdle',
        () {
      expect(
        resolveScheduleMode(false),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. taskReminderId — стабильность FNV-хэша
  // -------------------------------------------------------------------------
  group('taskReminderId', () {
    test('один и тот же itemId всегда даёт один id (детерминирован)', () {
      const id = 'task-abc-123';
      expect(
        NotificationService.taskReminderId(id),
        NotificationService.taskReminderId(id),
      );
    });

    test('разные itemId → разные id', () {
      expect(
        NotificationService.taskReminderId('task-a'),
        isNot(NotificationService.taskReminderId('task-b')),
      );
    });

    test('id >= 1_000_000 (не конфликтует с review/posture/habit диапазонами)',
        () {
      expect(
        NotificationService.taskReminderId('any-uuid') >= 1000000,
        isTrue,
      );
    });

    test('пустая строка → всё равно валидное число в диапазоне', () {
      final id = NotificationService.taskReminderId('');
      expect(id >= 1000000, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 3. rescheduleAllReminders — условная логика без MethodChannel
  // -------------------------------------------------------------------------
  group('rescheduleAllReminders', () {
    test(
        'reviewsEnabled=true, postureEnabled=false → только scheduleDailyReviews',
        () async {
      final svc = _FakeNotificationService();
      await svc.rescheduleAllReminders(
        reviewsEnabled: true,
        morningHour: 8,
        eveningHour: 20,
      );
      expect(svc.calls, ['reviews(8,20)']);
    });

    test(
        'reviewsEnabled=false, postureEnabled=true → только schedulePostureReminders',
        () async {
      final svc = _FakeNotificationService();
      await svc.rescheduleAllReminders(
        reviewsEnabled: false,
        postureEnabled: true,
      );
      expect(svc.calls, ['posture']);
    });

    test('оба флага true → reviews + posture в правильном порядке', () async {
      final svc = _FakeNotificationService();
      await svc.rescheduleAllReminders(
        reviewsEnabled: true,
        morningHour: 9,
        eveningHour: 21,
        postureEnabled: true,
      );
      expect(svc.calls, ['reviews(9,21)', 'posture']);
    });

    test(
        'оба флага false → ни одного вызова планирования',
        () async {
      final svc = _FakeNotificationService();
      await svc.rescheduleAllReminders(
        reviewsEnabled: false,
        postureEnabled: false,
      );
      expect(svc.calls, isEmpty);
    });

    test('кастомные часы разборов передаются в scheduleDailyReviews', () async {
      final svc = _FakeNotificationService();
      await svc.rescheduleAllReminders(
        reviewsEnabled: true,
        morningHour: 7,
        eveningHour: 22,
      );
      expect(svc.calls, contains('reviews(7,22)'));
    });
  });
}
