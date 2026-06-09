// Чистая логика питания (КБЖУ). Числа приходят из Open Food Facts (на 100 г);
// здесь только масштабирование под порцию и суммирование за день. Без I/O —
// легко тестируется.

/// КБЖУ (+ сахар/клетчатка). null = неизвестно.
class Nutrition {
  const Nutrition({
    this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.sugar,
    this.fiber,
  });

  final double? calories;
  final double? protein;
  final double? fat;
  final double? carbs;
  final double? sugar;
  final double? fiber;
}

double? _scale(double? per100, double grams) =>
    per100 == null ? null : per100 * grams / 100.0;

/// Масштабирует значения «на 100 г» под фактические [grams]. null остаётся null.
Nutrition scaleNutrition(Nutrition per100g, double grams) {
  return Nutrition(
    calories: _scale(per100g.calories, grams),
    protein: _scale(per100g.protein, grams),
    fat: _scale(per100g.fat, grams),
    carbs: _scale(per100g.carbs, grams),
    sugar: _scale(per100g.sugar, grams),
    fiber: _scale(per100g.fiber, grams),
  );
}

/// Сумма за день. null трактуем как 0 (для итогов).
Nutrition sumNutrition(Iterable<Nutrition> items) {
  double c = 0, p = 0, f = 0, cb = 0, s = 0, fb = 0;
  for (final n in items) {
    c += n.calories ?? 0;
    p += n.protein ?? 0;
    f += n.fat ?? 0;
    cb += n.carbs ?? 0;
    s += n.sugar ?? 0;
    fb += n.fiber ?? 0;
  }
  return Nutrition(
    calories: c,
    protein: p,
    fat: f,
    carbs: cb,
    sugar: s,
    fiber: fb,
  );
}
