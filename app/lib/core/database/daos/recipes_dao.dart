// DAO для рецептов (SPEC C5, Phase 1).
// Пользователь собирает блюдо из ингредиентов; числа КБЖУ считаются локально.
// Готовый рецепт логируется как обычная строка food_logs.
//
// #25 расширенный редактор (schemaVersion 23): description/videoUrl на самом
// рецепте + таблица recipe_steps (шаги приготовления, текст + опц. фото).
// Файлы фото шагов НЕ удаляются с диска при removeStep/deleteRecipe —
// упрощённая модель (как и у вложений задач до confirm-flow), здесь же ещё и
// чтобы Undo-snackbar (restoreStep) мог восстановить строку без повторного
// выбора фото. Небольшой риск осиротевших файлов на диске — приемлемо для MVP.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';
import '../../../features/food/food_nutrition.dart';

part 'recipes_dao.g.dart';

@DriftAccessor(tables: [RecipesTable, RecipeIngredientsTable, RecipeStepsTable])
class RecipesDao extends DatabaseAccessor<AppDatabase>
    with _$RecipesDaoMixin {
  RecipesDao(super.db);

  // ---------------------------------------------------------------------------
  // Рецепты
  // ---------------------------------------------------------------------------

  /// Реактивный список всех рецептов, сортировка: самые свежие первыми.
  Stream<List<RecipesTableData>> watchRecipes() {
    return (select(recipesTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Реактивно: один рецепт по id (null, если удалён).
  Stream<RecipesTableData?> watchRecipe(String id) {
    return (select(recipesTable)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Создать новый рецепт; возвращает id созданной записи.
  Future<String> createRecipe(String name) async {
    final id = uuidV4();
    final now = DateTime.now();
    await into(recipesTable).insert(
      RecipesTableCompanion(
        id: Value(id),
        name: Value(name),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  /// Переименовать рецепт; сдвигает updatedAt.
  Future<void> renameRecipe(String id, String name) async {
    await (update(recipesTable)..where((t) => t.id.equals(id))).write(
      RecipesTableCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Обновить текстовое описание рецепта (#25). [description] = null или
  /// пустая строка убирает описание.
  Future<void> updateDescription(String id, String? description) async {
    await (update(recipesTable)..where((t) => t.id.equals(id))).write(
      RecipesTableCompanion(
        description: Value(
          (description == null || description.isEmpty) ? null : description,
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Обновить ссылку на видео рецепта (#25). [videoUrl] = null или пустая
  /// строка убирает ссылку.
  Future<void> updateVideoUrl(String id, String? videoUrl) async {
    await (update(recipesTable)..where((t) => t.id.equals(id))).write(
      RecipesTableCompanion(
        videoUrl: Value(
          (videoUrl == null || videoUrl.isEmpty) ? null : videoUrl,
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Удалить рецепт и все его ингредиенты + шаги (каскад в транзакции).
  Future<void> deleteRecipe(String id) async {
    await transaction(() async {
      await (delete(recipeIngredientsTable)
            ..where((t) => t.recipeId.equals(id)))
          .go();
      await (delete(recipeStepsTable)..where((t) => t.recipeId.equals(id)))
          .go();
      await (delete(recipesTable)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Восстановить удалённый рецепт + все его ингредиенты + шаги (Undo-паттерн).
  /// Вызывается из Undo-snackbar после удаления через SwipeToDelete.
  /// [steps] опционален (по умолчанию пуст) — старые вызовы без снапшота шагов
  /// продолжают работать (рецепт восстановится без шагов).
  Future<void> restoreRecipe(
    RecipesTableData recipe,
    List<RecipeIngredientsTableData> ingredients, {
    List<RecipeStepsTableData> steps = const [],
  }) async {
    await transaction(() async {
      // Восстановить запись рецепта (insertOnConflictUpdate — безопасно при race)
      await into(recipesTable).insertOnConflictUpdate(
        RecipesTableCompanion(
          id: Value(recipe.id),
          name: Value(recipe.name),
          description: Value(recipe.description),
          videoUrl: Value(recipe.videoUrl),
          createdAt: Value(recipe.createdAt),
          updatedAt: Value(recipe.updatedAt),
        ),
      );
      // Восстановить все ингредиенты в исходном порядке
      for (final ing in ingredients) {
        await into(recipeIngredientsTable).insertOnConflictUpdate(
          RecipeIngredientsTableCompanion(
            id: Value(ing.id),
            recipeId: Value(ing.recipeId),
            name: Value(ing.name),
            grams: Value(ing.grams),
            calories: Value(ing.calories),
            protein: Value(ing.protein),
            fat: Value(ing.fat),
            carbs: Value(ing.carbs),
            sugar: Value(ing.sugar),
            fiber: Value(ing.fiber),
            sortOrder: Value(ing.sortOrder),
          ),
        );
      }
      // Восстановить все шаги в исходном порядке
      for (final step in steps) {
        await into(recipeStepsTable).insertOnConflictUpdate(
          RecipeStepsTableCompanion(
            id: Value(step.id),
            recipeId: Value(step.recipeId),
            stepText: Value(step.stepText),
            photoPath: Value(step.photoPath),
            sortOrder: Value(step.sortOrder),
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Ингредиенты
  // ---------------------------------------------------------------------------

  /// Реактивный список ингредиентов рецепта, сортировка: по sortOrder.
  Stream<List<RecipeIngredientsTableData>> watchIngredients(String recipeId) {
    return (select(recipeIngredientsTable)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Добавить ингредиент. [per100g] — значения «на 100 г» из базы продуктов;
  /// копируются в строку ингредиента (snapshot).
  Future<void> addIngredient({
    required String recipeId,
    required String name,
    required double grams,
    Nutrition? per100g,
  }) async {
    // sortOrder = текущее кол-во ингредиентов
    final existing = await (select(recipeIngredientsTable)
          ..where((t) => t.recipeId.equals(recipeId)))
        .get();
    final sortOrder = existing.length;

    await into(recipeIngredientsTable).insert(
      RecipeIngredientsTableCompanion(
        id: Value(uuidV4()),
        recipeId: Value(recipeId),
        name: Value(name),
        grams: Value(grams),
        calories: Value(per100g?.calories),
        protein: Value(per100g?.protein),
        fat: Value(per100g?.fat),
        carbs: Value(per100g?.carbs),
        sugar: Value(per100g?.sugar),
        fiber: Value(per100g?.fiber),
        sortOrder: Value(sortOrder),
      ),
    );

    // Обновляем updatedAt у родительского рецепта
    await (update(recipesTable)..where((t) => t.id.equals(recipeId))).write(
      RecipesTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Удалить ингредиент по id.
  Future<void> removeIngredient(String id) async {
    // Читаем recipeId до удаления, чтобы обновить updatedAt рецепта
    final row = await (select(recipeIngredientsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (delete(recipeIngredientsTable)..where((t) => t.id.equals(id))).go();
    if (row != null) {
      await (update(recipesTable)
            ..where((t) => t.id.equals(row.recipeId)))
          .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }

  /// Восстановить удалённый ингредиент по снапшоту (Undo-паттерн).
  /// Сохраняет оригинальный id и все поля — без изменений схемы БД.
  Future<void> restoreIngredient(RecipeIngredientsTableData snapshot) async {
    // insertOnConflictUpdate: если ингредиент вдруг ещё не удалён — обновляем.
    await into(recipeIngredientsTable).insertOnConflictUpdate(
      RecipeIngredientsTableCompanion(
        id: Value(snapshot.id),
        recipeId: Value(snapshot.recipeId),
        name: Value(snapshot.name),
        grams: Value(snapshot.grams),
        calories: Value(snapshot.calories),
        protein: Value(snapshot.protein),
        fat: Value(snapshot.fat),
        carbs: Value(snapshot.carbs),
        sugar: Value(snapshot.sugar),
        fiber: Value(snapshot.fiber),
        sortOrder: Value(snapshot.sortOrder),
      ),
    );
    // Обновляем updatedAt рецепта
    await (update(recipesTable)
          ..where((t) => t.id.equals(snapshot.recipeId)))
        .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
  }

  /// Обновить граммы ингредиента.
  Future<void> updateIngredientGrams(String id, double grams) async {
    final row = await (select(recipeIngredientsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (update(recipeIngredientsTable)..where((t) => t.id.equals(id))).write(
      RecipeIngredientsTableCompanion(grams: Value(grams)),
    );
    if (row != null) {
      await (update(recipesTable)
            ..where((t) => t.id.equals(row.recipeId)))
          .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }

  // ---------------------------------------------------------------------------
  // Шаги приготовления (#25, schemaVersion 23)
  // ---------------------------------------------------------------------------

  /// Реактивный список шагов рецепта, сортировка: по sortOrder.
  Stream<List<RecipeStepsTableData>> watchSteps(String recipeId) {
    return (select(recipeStepsTable)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Добавить шаг приготовления. [photoPath] — путь/data-URI уже сохранённого
  /// на диске фото (хранение делает UI, см. recipe_editor_screen.dart).
  Future<void> addStep({
    required String recipeId,
    required String text,
    String? photoPath,
  }) async {
    final existing = await (select(recipeStepsTable)
          ..where((t) => t.recipeId.equals(recipeId)))
        .get();
    final sortOrder = existing.length;

    await into(recipeStepsTable).insert(
      RecipeStepsTableCompanion(
        id: Value(uuidV4()),
        recipeId: Value(recipeId),
        stepText: Value(text),
        photoPath: Value(photoPath),
        sortOrder: Value(sortOrder),
      ),
    );

    await (update(recipesTable)..where((t) => t.id.equals(recipeId))).write(
      RecipesTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Обновить текст и/или фото существующего шага (полная перезапись обоих
  /// полей — проще, чем частичные апдейты, и хватает для редактора).
  Future<void> updateStep(
    String id, {
    required String text,
    required String? photoPath,
  }) async {
    final row = await (select(recipeStepsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (update(recipeStepsTable)..where((t) => t.id.equals(id))).write(
      RecipeStepsTableCompanion(
        stepText: Value(text),
        photoPath: Value(photoPath),
      ),
    );
    if (row != null) {
      await (update(recipesTable)
            ..where((t) => t.id.equals(row.recipeId)))
          .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }

  /// Удалить шаг по id. НЕ удаляет файл фото с диска (см. комментарий
  /// у класса) — это позволяет restoreStep() безопасно отменить удаление.
  Future<void> removeStep(String id) async {
    final row = await (select(recipeStepsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (delete(recipeStepsTable)..where((t) => t.id.equals(id))).go();
    if (row != null) {
      await (update(recipesTable)
            ..where((t) => t.id.equals(row.recipeId)))
          .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }

  /// Восстановить удалённый шаг по снапшоту (Undo-паттерн, как у ингредиентов).
  Future<void> restoreStep(RecipeStepsTableData snapshot) async {
    await into(recipeStepsTable).insertOnConflictUpdate(
      RecipeStepsTableCompanion(
        id: Value(snapshot.id),
        recipeId: Value(snapshot.recipeId),
        stepText: Value(snapshot.stepText),
        photoPath: Value(snapshot.photoPath),
        sortOrder: Value(snapshot.sortOrder),
      ),
    );
    await (update(recipesTable)
          ..where((t) => t.id.equals(snapshot.recipeId)))
        .write(RecipesTableCompanion(updatedAt: Value(DateTime.now())));
  }
}
