// Тесты политики запроса оценки (E3) и счётчика запусков (инфраструктура).
//
// Нет pumpAndSettle, нет Drift, нет Flutter-виджетов.
// SharedPreferences мокируется через setMockInitialValues.
// InAppReview — инъекция через InAppReviewDelegate.

import 'package:app/core/settings/app_usage.dart';
import 'package:app/services/rating/rating_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Фиктивная реализация InAppReviewDelegate
// ---------------------------------------------------------------------------

class _FakeReview implements InAppReviewDelegate {
  bool available = true;
  int reviewRequested = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    reviewRequested++;
  }
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  // ─── shouldRequestRating — чистая политика ────────────────────────────────

  group('shouldRequestRating', () {
    test('возвращает false если уже запрашивали', () {
      expect(
        shouldRequestRating(
          launchCount: 10,
          daysSinceFirstLaunch: 10,
          alreadyRequested: true,
        ),
        isFalse,
      );
    });

    test('возвращает false если launchCount < 4 И daysSince < 3', () {
      expect(
        shouldRequestRating(
          launchCount: 3,
          daysSinceFirstLaunch: 2,
          alreadyRequested: false,
        ),
        isFalse,
      );
    });

    test('возвращает false при launchCount=0, daysSince=0', () {
      expect(
        shouldRequestRating(
          launchCount: 0,
          daysSinceFirstLaunch: 0,
          alreadyRequested: false,
        ),
        isFalse,
      );
    });

    test('возвращает true при launchCount == 4 (граница), daysSince=0', () {
      expect(
        shouldRequestRating(
          launchCount: 4,
          daysSinceFirstLaunch: 0,
          alreadyRequested: false,
        ),
        isTrue,
      );
    });

    test('возвращает true при launchCount > 4', () {
      expect(
        shouldRequestRating(
          launchCount: 10,
          daysSinceFirstLaunch: 0,
          alreadyRequested: false,
        ),
        isTrue,
      );
    });

    test('возвращает true при daysSince == 3 (граница), launchCount < 4', () {
      expect(
        shouldRequestRating(
          launchCount: 1,
          daysSinceFirstLaunch: 3,
          alreadyRequested: false,
        ),
        isTrue,
      );
    });

    test('возвращает true при daysSince > 3, launchCount < 4', () {
      expect(
        shouldRequestRating(
          launchCount: 2,
          daysSinceFirstLaunch: 7,
          alreadyRequested: false,
        ),
        isTrue,
      );
    });
  });

  // ─── incrementLaunchCount + getLaunchCount + getFirstLaunchAt ────────────

  group('incrementLaunchCount', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('первый вызов: launchCount=1, first_launch_at записан', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(getLaunchCount(prefs), 0);
      expect(getFirstLaunchAt(prefs), isNull);

      await incrementLaunchCount(prefs);

      expect(getLaunchCount(prefs), 1);
      expect(getFirstLaunchAt(prefs), isNotNull);
    });

    test('первый вызов: first_launch_at — корректная дата (parseable)', () async {
      final prefs = await SharedPreferences.getInstance();
      await incrementLaunchCount(prefs);

      final first = getFirstLaunchAt(prefs);
      expect(first, isNotNull);
      // Дата должна быть не раньше условного «начала тестов» и не в будущем
      expect(first!.isBefore(DateTime.now().add(const Duration(seconds: 1))),
          isTrue);
    });

    test('второй вызов: launchCount=2, first_launch_at не перезаписывается',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await incrementLaunchCount(prefs);
      final firstAt = getFirstLaunchAt(prefs);

      await incrementLaunchCount(prefs);

      expect(getLaunchCount(prefs), 2);
      // first_launch_at остался тем же объектом (сравниваем строки из prefs)
      expect(getFirstLaunchAt(prefs)?.toIso8601String(),
          firstAt?.toIso8601String());
    });

    test('три вызова → launchCount=3', () async {
      final prefs = await SharedPreferences.getInstance();
      await incrementLaunchCount(prefs);
      await incrementLaunchCount(prefs);
      await incrementLaunchCount(prefs);
      expect(getLaunchCount(prefs), 3);
    });

    test('предустановленное значение учитывается: startAt=5 → после +1 = 6',
        () async {
      SharedPreferences.setMockInitialValues({
        kLaunchCountKey: 5,
        kFirstLaunchAtKey: DateTime(2026, 1, 1).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      await incrementLaunchCount(prefs);
      expect(getLaunchCount(prefs), 6);
      // first_launch_at не трогается (count был не 0)
      expect(getFirstLaunchAt(prefs), DateTime(2026, 1, 1));
    });
  });

  // ─── RatingService.maybeRequestReview — с fake InAppReview ────────────────

  group('RatingService.maybeRequestReview', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('не показывает при launchCount < 4 И daysSince < 3', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLaunchCountKey, 2);
      await prefs.setString(
          kFirstLaunchAtKey, DateTime.now().toIso8601String());

      final fake = _FakeReview();
      final service = RatingService(prefs, review: fake);

      await service.maybeRequestReview();

      expect(fake.reviewRequested, 0);
      expect(prefs.getBool(kRatingRequestedKey), isNull);
    });

    test('показывает при launchCount >= 4', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLaunchCountKey, 5);
      await prefs.setString(
          kFirstLaunchAtKey, DateTime.now().toIso8601String());

      final fake = _FakeReview();
      final service = RatingService(prefs, review: fake);

      await service.maybeRequestReview();

      expect(fake.reviewRequested, 1);
      expect(prefs.getBool(kRatingRequestedKey), isTrue);
    });

    test('показывает при daysSince >= 3 (launchCount < 4)', () async {
      SharedPreferences.setMockInitialValues({
        kLaunchCountKey: 1,
        kFirstLaunchAtKey:
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final fake = _FakeReview();
      final service = RatingService(prefs, review: fake);

      await service.maybeRequestReview();

      expect(fake.reviewRequested, 1);
    });

    test('повторный вызов не показывает (already_requested=true)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLaunchCountKey, 10);
      await prefs.setString(
          kFirstLaunchAtKey, DateTime.now().toIso8601String());
      await prefs.setBool(kRatingRequestedKey, true);

      final fake = _FakeReview();
      final service = RatingService(prefs, review: fake);

      await service.maybeRequestReview();

      expect(fake.reviewRequested, 0);
    });

    test('два вызова подряд — requestReview вызван ровно один раз', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLaunchCountKey, 5);
      await prefs.setString(
          kFirstLaunchAtKey, DateTime.now().toIso8601String());

      final fake = _FakeReview();
      final service = RatingService(prefs, review: fake);

      await service.maybeRequestReview();
      await service.maybeRequestReview(); // флаг уже true

      expect(fake.reviewRequested, 1);
    });

    test('когда isAvailable=false — requestReview не вызывается', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLaunchCountKey, 5);
      await prefs.setString(
          kFirstLaunchAtKey, DateTime.now().toIso8601String());

      final fake = _FakeReview()..available = false;
      final service = RatingService(prefs, review: fake);

      await service.maybeRequestReview();

      expect(fake.reviewRequested, 0);
      // Флаг НЕ должен быть записан (показа не было → можно попробовать позже)
      expect(prefs.getBool(kRatingRequestedKey), isNull);
    });

    test('исключение в requestReview поглощается (не кидает наружу)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kLaunchCountKey, 5);
      await prefs.setString(
          kFirstLaunchAtKey, DateTime.now().toIso8601String());

      // Fake с исключением внутри requestReview
      final fakeThrowing = _ThrowingReview();
      final service = RatingService(prefs, review: fakeThrowing);

      // Не должно кидать
      expect(() => service.maybeRequestReview(), returnsNormally);
      await service.maybeRequestReview();
    });
  });
}

/// Fake, кидающий исключение в requestReview — проверяем что try/catch работает.
class _ThrowingReview implements InAppReviewDelegate {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestReview() async {
    throw Exception('Simulated platform exception');
  }
}
