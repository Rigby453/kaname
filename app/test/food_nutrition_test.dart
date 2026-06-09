// Юнит-тесты чистой логики питания (scaleNutrition / sumNutrition).

import 'package:app/features/food/food_nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scaleNutrition', () {
    test('scales per-100g values to the given grams', () {
      const per100 = Nutrition(
        calories: 400,
        protein: 10,
        fat: 20,
        carbs: 50,
        sugar: 8,
        fiber: 4,
      );
      final scaled = scaleNutrition(per100, 50);
      expect(scaled.calories, 200);
      expect(scaled.protein, 5);
      expect(scaled.fat, 10);
      expect(scaled.carbs, 25);
      expect(scaled.sugar, 4);
      expect(scaled.fiber, 2);
    });

    test('keeps nulls as null', () {
      const per100 = Nutrition(calories: 250, protein: null);
      final scaled = scaleNutrition(per100, 200);
      expect(scaled.calories, 500);
      expect(scaled.protein, isNull);
    });
  });

  group('sumNutrition', () {
    test('sums entries treating null as zero', () {
      final total = sumNutrition(const [
        Nutrition(calories: 100, protein: 5, fiber: 2),
        Nutrition(calories: 200, protein: null, fiber: 3),
      ]);
      expect(total.calories, 300);
      expect(total.protein, 5); // null трактуется как 0
      expect(total.fiber, 5);
    });

    test('empty → all zero', () {
      final total = sumNutrition(const []);
      expect(total.calories, 0);
      expect(total.protein, 0);
    });
  });
}
