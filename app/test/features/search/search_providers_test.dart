// Юнит-тесты для globalSearchResultsProvider (#17, слой данных).
// In-memory Drift (без Flutter platform-каналов) + Riverpod ProviderContainer
// с оверрайдом DAO-провайдеров на DAO, построенные над этой in-memory БД —
// тот же паттерн, что profile_identity_test.dart (overrideWithValue), но для
// DAO вместо SharedPreferences.
//
// Каждый тестовый keyword — уникальное "нонсенс"-слово с префиксом zephyr*,
// чтобы секции не пересекались случайно и было легко проверить изоляцию
// (слово из задачи не должно находиться в дневнике/рецептах/покупках и т.п).

import 'package:app/core/database/daos/day_logs_dao.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/daos/recipes_dao.dart';
import 'package:app/core/database/daos/shopping_dao.dart';
import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/features/search/search_providers.dart';
import 'package:app/features/search/search_results_model.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _insertItem(
  ItemsDao dao, {
  required String id,
  required String title,
  DateTime? scheduledAt,
}) {
  final now = DateTime.now();
  return dao.insertItem(
    ItemsTableCompanion(
      id: Value(id),
      userId: const Value('local'),
      title: Value(title),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(scheduledAt ?? now),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ItemsDao itemsDao;
  late DayLogsDao dayLogsDao;
  late RecipesDao recipesDao;
  late ShoppingDao shoppingDao;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    itemsDao = ItemsDao(db);
    dayLogsDao = DayLogsDao(db);
    recipesDao = RecipesDao(db);
    shoppingDao = ShoppingDao(db);

    // Сидинг тестовых данных — по 1-2 записи на сущность, каждая с уникальным
    // ключевым словом.
    await _insertItem(
      itemsDao,
      id: 'task-1',
      title: 'Zephyrtask project review',
      scheduledAt: DateTime(2026, 3, 10, 9),
    );
    await _insertItem(
      itemsDao,
      id: 'task-2',
      title: 'Unrelated grocery run',
      scheduledAt: DateTime(2026, 3, 11, 9),
    );

    await dayLogsDao.saveForDate(
      date: DateTime(2026, 3, 12),
      mood: 4,
      note: 'Felt zephyrdiary and calm after the walk today.',
    );

    final recipeId = await recipesDao.createRecipe('Zephyrrecipe Pie');
    await recipesDao.updateDescription(recipeId, 'Bake slowly at low heat.');

    final plainRecipeId = await recipesDao.createRecipe('Plain Cake');
    await recipesDao.updateDescription(
      plainRecipeId,
      'Contains a zephyrdesc unique flavor note.',
    );

    await shoppingDao.insertItem(name: 'Zephyrshop milk', quantity: '2 L');
    await shoppingDao.insertItem(name: 'Bread');

    container = ProviderContainer(overrides: [
      itemsDaoProvider.overrideWithValue(itemsDao),
      dayLogsDaoProvider.overrideWithValue(dayLogsDao),
      recipesDaoProvider.overrideWithValue(recipesDao),
      shoppingDaoProvider.overrideWithValue(shoppingDao),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('globalSearchResultsProvider — empty query', () {
    test('empty string returns GlobalSearchResults.empty() without hitting DB',
        () async {
      final results =
          await container.read(globalSearchResultsProvider('').future);
      expect(results.isEmpty, isTrue);
      expect(results.totalCount, 0);
    });

    test('whitespace-only query returns empty results', () async {
      final results =
          await container.read(globalSearchResultsProvider('   ').future);
      expect(results.isEmpty, isTrue);
    });
  });

  group('globalSearchResultsProvider — tasks', () {
    test('matches a task by title substring, other sections empty', () async {
      final results = await container
          .read(globalSearchResultsProvider('zephyrtask').future);

      expect(results.tasks, hasLength(1));
      expect(results.tasks.single.id, 'task-1');
      expect(results.tasks.single.kind, SearchHitKind.task);
      expect(results.tasks.single.title, 'Zephyrtask project review');
      expect(results.tasks.single.date, DateTime(2026, 3, 10, 9));

      expect(results.diary, isEmpty);
      expect(results.recipes, isEmpty);
      expect(results.shopping, isEmpty);
    });

    test('is case-insensitive', () async {
      final results = await container
          .read(globalSearchResultsProvider('ZEPHYRTASK').future);
      expect(results.tasks, hasLength(1));
    });

    test('does not match unrelated task titles', () async {
      final results = await container
          .read(globalSearchResultsProvider('zephyrtask').future);
      expect(
        results.tasks.any((h) => h.id == 'task-2'),
        isFalse,
      );
    });
  });

  group('globalSearchResultsProvider — diary', () {
    test('matches a day log by note substring, other sections empty',
        () async {
      final results = await container
          .read(globalSearchResultsProvider('zephyrdiary').future);

      expect(results.diary, hasLength(1));
      final hit = results.diary.single;
      expect(hit.kind, SearchHitKind.diary);
      expect(hit.title.toLowerCase(), contains('zephyrdiary'));
      // Drift возвращает DateTime без гарантии сохранённого isUtc-флага
      // (тот же приём, что в diary_history_test.dart) — сравниваем через
      // toUtc(), а не напрямую с DateTime.utc(...).
      expect(hit.date, isNotNull);
      expect(hit.date!.toUtc(), DateTime.utc(2026, 3, 12));

      expect(results.tasks, isEmpty);
      expect(results.recipes, isEmpty);
      expect(results.shopping, isEmpty);
    });

    test('is case-insensitive', () async {
      final results = await container
          .read(globalSearchResultsProvider('ZephyrDiary').future);
      expect(results.diary, hasLength(1));
    });
  });

  group('globalSearchResultsProvider — recipes', () {
    test('matches recipe by name, snippet is null when match is in name',
        () async {
      final results = await container
          .read(globalSearchResultsProvider('zephyrrecipe').future);

      expect(results.recipes, hasLength(1));
      final hit = results.recipes.single;
      expect(hit.kind, SearchHitKind.recipe);
      expect(hit.title, 'Zephyrrecipe Pie');
      expect(hit.snippet, isNull);

      expect(results.tasks, isEmpty);
      expect(results.diary, isEmpty);
      expect(results.shopping, isEmpty);
    });

    test('matches recipe by description, snippet carries the excerpt',
        () async {
      final results = await container
          .read(globalSearchResultsProvider('zephyrdesc').future);

      expect(results.recipes, hasLength(1));
      final hit = results.recipes.single;
      expect(hit.title, 'Plain Cake');
      expect(hit.snippet, isNotNull);
      expect(hit.snippet!.toLowerCase(), contains('zephyrdesc'));
    });
  });

  group('globalSearchResultsProvider — shopping', () {
    test('matches shopping item by name, other sections empty', () async {
      final results = await container
          .read(globalSearchResultsProvider('zephyrshop').future);

      expect(results.shopping, hasLength(1));
      final hit = results.shopping.single;
      expect(hit.kind, SearchHitKind.shopping);
      expect(hit.title, 'Zephyrshop milk');

      expect(results.tasks, isEmpty);
      expect(results.diary, isEmpty);
      expect(results.recipes, isEmpty);
    });

    test('is case-insensitive', () async {
      final results = await container
          .read(globalSearchResultsProvider('ZEPHYRSHOP').future);
      expect(results.shopping, hasLength(1));
    });
  });

  group('globalSearchResultsProvider — no matches', () {
    test('unknown query returns fully empty results', () async {
      final results = await container
          .read(globalSearchResultsProvider('doesnotexistanywhere').future);
      expect(results.isEmpty, isTrue);
      expect(results.totalCount, 0);
    });
  });
}
