// Юнит-тесты для goalsToFeatureFlags (goal_flags_mapper.dart).
// Чистая функция — не требует Flutter, SharedPreferences или ProviderContainer.
//
// Проверяем:
//   1. Каждая цель онбординга (study/procrastination/routine/free_time/exams)
//      не включает ни одного тяжёлого флага (результат: all false).
//   2. Пустой набор → all false.
//   3. Смешанный набор текущих целей → all false.
//   4. Будущая цель 'fitness' → nutrition=true, workout=true.
//   5. Будущая цель 'body' → nutrition=true, workout=true.
//   6. Будущая цель 'wellness' → meditationLibrary=true, breathingEditor=true.
//   7. Будущая цель 'meditation' → meditationLibrary=true (breathing=false).
//   8. Будущая цель 'breathing' → breathingEditor=true (meditation=false).
//   9. Комбо fitness+wellness → все 4 флага true.
//   10. 'routine' НЕ включает health L2-флаги.

import 'package:app/features/onboarding/goal_flags_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Хелпер для краткости.
  GoalFlags flags(List<String> goalIds) =>
      goalsToFeatureFlags(goalIds.toSet());

  group('текущие цели онбординга — все флаги false', () {
    test("'study' → all false", () {
      final f = flags(['study']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test("'procrastination' → all false", () {
      final f = flags(['procrastination']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test("'routine' → all false (сон/вода L1; тяжёлые L2 не включаем)", () {
      final f = flags(['routine']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test("'free_time' → all false", () {
      final f = flags(['free_time']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test("'exams' → all false", () {
      final f = flags(['exams']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test('пустой набор → all false', () {
      final f = flags([]);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test('все текущие цели вместе → all false', () {
      final f = flags([
        'study',
        'procrastination',
        'routine',
        'free_time',
        'exams',
      ]);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });
  });

  group('будущие цели — включают нужные флаги', () {
    test("'fitness' → nutrition=true, workout=true", () {
      final f = flags(['fitness']);
      expect(f.nutrition, isTrue);
      expect(f.workout, isTrue);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test("'body' → nutrition=true, workout=true", () {
      final f = flags(['body']);
      expect(f.nutrition, isTrue);
      expect(f.workout, isTrue);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test("'wellness' → meditationLibrary=true, breathingEditor=true", () {
      final f = flags(['wellness']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isTrue);
      expect(f.breathingEditor, isTrue);
    });

    test("'meditation' → meditationLibrary=true, breathing=false", () {
      final f = flags(['meditation']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isTrue);
      expect(f.breathingEditor, isFalse);
    });

    test("'breathing' → breathingEditor=true, meditation=false", () {
      final f = flags(['breathing']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isTrue);
    });

    test("'fitness' + 'wellness' → все 4 флага true", () {
      final f = flags(['fitness', 'wellness']);
      expect(f.nutrition, isTrue);
      expect(f.workout, isTrue);
      expect(f.meditationLibrary, isTrue);
      expect(f.breathingEditor, isTrue);
    });
  });

  group('изоляция флагов', () {
    test("'study' + 'fitness' → только nutrition+workout; meditation/breathing false", () {
      final f = flags(['study', 'fitness']);
      expect(f.nutrition, isTrue);
      expect(f.workout, isTrue);
      expect(f.meditationLibrary, isFalse);
      expect(f.breathingEditor, isFalse);
    });

    test("'routine' + 'meditation' → только meditationLibrary; nutrition/workout false", () {
      final f = flags(['routine', 'meditation']);
      expect(f.nutrition, isFalse);
      expect(f.workout, isFalse);
      expect(f.meditationLibrary, isTrue);
      expect(f.breathingEditor, isFalse);
    });
  });
}
