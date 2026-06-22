// Юнит-тесты классической схемы слотов приёмов пищи (meal_slots.dart).

import 'package:app/features/food/meal_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mealsForCount — классическая схема', () {
    test('n == 3 → завтрак, обед, ужин', () {
      expect(mealsForCount(3), ['breakfast', 'lunch', 'dinner']);
    });

    test('n == 4 → завтрак, обед, полдник, ужин', () {
      expect(
        mealsForCount(4),
        ['breakfast', 'lunch', 'afternoon_snack', 'dinner'],
      );
    });

    test('n == 5 → завтрак, второй завтрак, обед, полдник, ужин', () {
      expect(
        mealsForCount(5),
        ['breakfast', 'second_breakfast', 'lunch', 'afternoon_snack', 'dinner'],
      );
    });

    test('зажим для n <= 2 — первые n из базовой тройки', () {
      expect(mealsForCount(1), ['breakfast']);
      expect(mealsForCount(2), ['breakfast', 'lunch']);
      expect(mealsForCount(0), ['breakfast']);
    });

    test('n >= 6 — пятёрка плюс завершающий snack', () {
      expect(mealsForCount(6), [
        'breakfast',
        'second_breakfast',
        'lunch',
        'afternoon_snack',
        'dinner',
        'snack',
      ]);
      expect(mealsForCount(99), hasLength(6));
    });

    test('ключи слотов уникальны (важно для группировки)', () {
      for (final n in [3, 4, 5, 6]) {
        final slots = mealsForCount(n);
        expect(slots.toSet(), hasLength(slots.length), reason: 'n=$n');
      }
    });
  });

  group('kMealSlotOrder', () {
    test('содержит все слоты в каноническом порядке', () {
      expect(kMealSlotOrder, [
        'breakfast',
        'second_breakfast',
        'lunch',
        'afternoon_snack',
        'dinner',
        'snack',
      ]);
    });

    test('все слоты из mealsForCount присутствуют в kMealSlotOrder', () {
      for (final n in [3, 4, 5, 6]) {
        for (final slot in mealsForCount(n)) {
          expect(kMealSlotOrder, contains(slot), reason: 'n=$n slot=$slot');
        }
      }
    });
  });
}
