// Unit-тесты для RecipesDao (SPEC C5, Phase 1).
// In-memory Drift — без Flutter-зависимостей, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/recipes_dao.dart';
import 'package:app/features/food/food_nutrition.dart';
import 'package:app/features/food/recipe_nutrition.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late RecipesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = RecipesDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('createRecipe → watchRecipes возвращает рецепт', () async {
    final id = await dao.createRecipe('Fried rice');
    final all = await dao.watchRecipes().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.name, 'Fried rice');
  });

  test('addIngredient сохраняет снапшот на 100 г; totals считаются', () async {
    final id = await dao.createRecipe('Fried rice');
    await dao.addIngredient(
      recipeId: id,
      name: 'Rice',
      grams: 200,
      per100g: const Nutrition(calories: 130, protein: 2.7),
    );
    await dao.addIngredient(
      recipeId: id,
      name: 'Egg',
      grams: 50,
      per100g: const Nutrition(calories: 155, protein: 13),
    );

    final ings = await dao.watchIngredients(id).first;
    expect(ings, hasLength(2));
    // Порядок по sortOrder = порядок добавления
    expect(ings[0].name, 'Rice');
    expect(ings[1].name, 'Egg');

    final totals = recipeTotals(ings);
    expect(totals.totalGrams, 250);
    expect(totals.total.calories, closeTo(130 * 2 + 155 * 0.5, 0.001));
  });

  test('updateIngredientGrams меняет граммы', () async {
    final id = await dao.createRecipe('Soup');
    await dao.addIngredient(recipeId: id, name: 'Potato', grams: 100);
    final ing = (await dao.watchIngredients(id).first).single;

    await dao.updateIngredientGrams(ing.id, 250);
    final updated = (await dao.watchIngredients(id).first).single;
    expect(updated.grams, 250);
  });

  test('removeIngredient удаляет только указанный', () async {
    final id = await dao.createRecipe('Salad');
    await dao.addIngredient(recipeId: id, name: 'Tomato', grams: 100);
    await dao.addIngredient(recipeId: id, name: 'Cucumber', grams: 100);

    final ings = await dao.watchIngredients(id).first;
    await dao.removeIngredient(ings.first.id);

    final rest = await dao.watchIngredients(id).first;
    expect(rest, hasLength(1));
    expect(rest.single.name, 'Cucumber');
  });

  test('deleteRecipe удаляет рецепт каскадно с ингредиентами', () async {
    final id = await dao.createRecipe('Pasta');
    await dao.addIngredient(recipeId: id, name: 'Spaghetti', grams: 100);
    final other = await dao.createRecipe('Other');
    await dao.addIngredient(recipeId: other, name: 'Bread', grams: 50);

    await dao.deleteRecipe(id);

    expect(await dao.watchRecipes().first, hasLength(1));
    expect(await dao.watchIngredients(id).first, isEmpty);
    // Чужие ингредиенты не задеты
    expect(await dao.watchIngredients(other).first, hasLength(1));
  });

  test('renameRecipe меняет имя, updatedAt не уходит в прошлое', () async {
    final id = await dao.createRecipe('Old name');
    final before = (await dao.watchRecipes().first).single.updatedAt;

    await dao.renameRecipe(id, 'New name');

    final after = (await dao.watchRecipes().first).single;
    expect(after.name, 'New name');
    // Drift хранит DateTime с точностью до секунды — строгий isAfter
    // здесь ненадёжен, проверяем монотонность.
    expect(after.updatedAt.isBefore(before), isFalse);
  });

  // ---------------------------------------------------------------------------
  // #25 расширенный редактор: description / videoUrl / шаги (schemaVersion 23)
  // ---------------------------------------------------------------------------

  test('updateDescription сохраняет и убирает описание', () async {
    final id = await dao.createRecipe('Pancakes');
    expect((await dao.watchRecipes().first).single.description, isNull);

    await dao.updateDescription(id, 'Fluffy breakfast pancakes');
    expect(
      (await dao.watchRecipes().first).single.description,
      'Fluffy breakfast pancakes',
    );

    // Пустая строка убирает описание (null)
    await dao.updateDescription(id, '');
    expect((await dao.watchRecipes().first).single.description, isNull);
  });

  test('updateVideoUrl сохраняет и убирает ссылку', () async {
    final id = await dao.createRecipe('Omelette');
    await dao.updateVideoUrl(id, 'https://example.com/omelette');
    expect(
      (await dao.watchRecipes().first).single.videoUrl,
      'https://example.com/omelette',
    );

    await dao.updateVideoUrl(id, null);
    expect((await dao.watchRecipes().first).single.videoUrl, isNull);
  });

  test('addStep → watchSteps возвращает шаги по sortOrder', () async {
    final id = await dao.createRecipe('Fried rice');
    await dao.addStep(recipeId: id, text: 'Boil the rice');
    await dao.addStep(
      recipeId: id,
      text: 'Fry with egg and vegetables',
      photoPath: '/tmp/step2.jpg',
    );

    final steps = await dao.watchSteps(id).first;
    expect(steps, hasLength(2));
    expect(steps[0].stepText, 'Boil the rice');
    expect(steps[0].photoPath, isNull);
    expect(steps[1].stepText, 'Fry with egg and vegetables');
    expect(steps[1].photoPath, '/tmp/step2.jpg');
    expect(steps[0].sortOrder, lessThan(steps[1].sortOrder));
  });

  test('updateStep меняет текст и фото шага', () async {
    final id = await dao.createRecipe('Soup');
    await dao.addStep(recipeId: id, text: 'Chop vegetables');
    final step = (await dao.watchSteps(id).first).single;

    await dao.updateStep(step.id, text: 'Chop and sauté vegetables', photoPath: '/tmp/a.jpg');

    final updated = (await dao.watchSteps(id).first).single;
    expect(updated.stepText, 'Chop and sauté vegetables');
    expect(updated.photoPath, '/tmp/a.jpg');
  });

  test('removeStep удаляет только указанный шаг; restoreStep возвращает его', () async {
    final id = await dao.createRecipe('Salad');
    await dao.addStep(recipeId: id, text: 'Wash greens');
    await dao.addStep(recipeId: id, text: 'Add dressing');

    final steps = await dao.watchSteps(id).first;
    final removed = steps.first;
    await dao.removeStep(removed.id);

    final afterRemove = await dao.watchSteps(id).first;
    expect(afterRemove, hasLength(1));
    expect(afterRemove.single.stepText, 'Add dressing');

    await dao.restoreStep(removed);
    final afterRestore = await dao.watchSteps(id).first;
    expect(afterRestore, hasLength(2));
    expect(afterRestore.map((s) => s.stepText), contains('Wash greens'));
  });

  test('deleteRecipe удаляет шаги вместе с рецептом; restoreRecipe восстанавливает их', () async {
    final id = await dao.createRecipe('Stew');
    await dao.addIngredient(recipeId: id, name: 'Beef', grams: 300);
    await dao.addStep(recipeId: id, text: 'Brown the beef');
    await dao.updateDescription(id, 'Slow-cooked beef stew');
    await dao.updateVideoUrl(id, 'https://example.com/stew');

    final recipe = (await dao.watchRecipes().first).single;
    final ingredients = await dao.watchIngredients(id).first;
    final steps = await dao.watchSteps(id).first;

    await dao.deleteRecipe(id);
    expect(await dao.watchSteps(id).first, isEmpty);
    expect(await dao.watchRecipes().first, isEmpty);

    await dao.restoreRecipe(recipe, ingredients, steps: steps);

    final restored = (await dao.watchRecipes().first).single;
    expect(restored.description, 'Slow-cooked beef stew');
    expect(restored.videoUrl, 'https://example.com/stew');
    expect(await dao.watchIngredients(id).first, hasLength(1));
    final restoredSteps = await dao.watchSteps(id).first;
    expect(restoredSteps, hasLength(1));
    expect(restoredSteps.single.stepText, 'Brown the beef');
  });
}
