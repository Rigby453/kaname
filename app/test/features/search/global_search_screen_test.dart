// Виджет-тесты экрана глобального поиска (#17, часть 2/2 — UI).
//
// Харнесс — явный ProviderContainer (UncontrolledProviderScope): экран пишет
// в globalSearchQueryProvider через Timer-дебаунс (~300мс) и читает
// globalSearchResultsProvider(query), который делает реальный IO по Drift
// (in-memory sqlite). Всё взаимодействие идёт ВНУТРИ tester.runAsync (тот же
// приём, что #27 debounce-тесты в recipe_editor_extended_test.dart) — так
// настоящий Timer и настоящий Future реально прогрессируют по wall-clock,
// а не через fake-async pump(duration). После пересечения дебаунса мы
// дополнительно ЯВНО ждём `container.read(provider(query).future)` — это тот
// же самый (мемоизированный по ключу) провайдер, что слушает виджет, поэтому
// после его резолва в дереве уже нет "in-flight" future и pumpAndSettle не
// нужен: одного `tester.pump()` достаточно, а бесконечный CircularProgressIndicator
// (индикатор загрузки) к этому моменту уже не рисуется — избегаем зависания
// pumpAndSettle на бесконечной анимации спиннера (см. rules.md).
//
// НЕ покрываем здесь тапы по строкам (навигация) — они уходят в go_router
// (context.push/go), которого в этом лёгком харнессе нет; сама навигационная
// логика — тонкий switch на (kind,id,date), проверенный чтением кода.

import 'package:app/core/database/daos/day_logs_dao.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/daos/recipes_dao.dart';
import 'package:app/core/database/daos/shopping_dao.dart';
import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/search/global_search_screen.dart';
import 'package:app/features/search/search_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Тестовая тема — тот же набор полей, что в screens_smoke_test.dart /
/// overflow_audit_test.dart (FocusThemeExtension обязателен для экрана).
ThemeData testTheme() {
  return ThemeData.dark().copyWith(
    extensions: const [
      FocusThemeExtension(
        textMuted: Color(0xFF9E9070),
        ember: Color(0xFFFF6A3D),
        border: Color(0xFF3A3020),
        surfaceElevated: Color(0xFF2E2618),
        textFaint: Color(0xFF736850),
        accentMuted: Color(0xFF26290F),
        success: Color(0xFF4BAF6F),
        borderStrong: Color(0xFF524630),
      ),
    ],
  );
}

Future<void> insertItem(
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
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    itemsDao = ItemsDao(db);
    dayLogsDao = DayLogsDao(db);
    recipesDao = RecipesDao(db);
    shoppingDao = ShoppingDao(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(overrides: [
      itemsDaoProvider.overrideWithValue(itemsDao),
      dayLogsDaoProvider.overrideWithValue(dayLogsDao),
      recipesDaoProvider.overrideWithValue(recipesDao),
      shoppingDaoProvider.overrideWithValue(shoppingDao),
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget harness({Size size = const Size(390, 800), double textScale = 1.0}) {
    return UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: testTheme(),
          home: const GlobalSearchScreen(),
        ),
      ),
    );
  }

  /// Печатает [query] в поле поиска, пересекает дебаунс (~300мс, реальный
  /// wall-clock — вызывающий уже внутри tester.runAsync) и ЯВНО дожидается
  /// резолва globalSearchResultsProvider(query) перед финальным pump().
  Future<void> typeAndWaitForResults(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await Future<void>.delayed(const Duration(milliseconds: 400)); // > 300мс дебаунс
    await tester.pump(); // виджет замечает новый query, запускает провайдер
    await container.read(globalSearchResultsProvider(query).future);
    await tester.pump(); // рендерим уже готовый AsyncData
  }

  /// Drift markAsClosed создаёт zero-duration таймер при отписке стримов —
  /// размонтируем дерево и прокачиваем кадр, чтобы он не утёк за пределы теста.
  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> setSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('GlobalSearchScreen — empty query', () {
    testWidgets('no sections rendered, no exception', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Пустой запрос — ни секций (ListView), ни ошибок.
      expect(find.byType(ListView), findsNothing);
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    });
  });

  group('GlobalSearchScreen — seeded query', () {
    testWidgets('renders sections with matching hits across all 4 kinds',
        (tester) async {
      await tester.runAsync(() async {
        await insertItem(
          itemsDao,
          id: 'task-1',
          title: 'Zephyrglobal task title',
          scheduledAt: DateTime(2026, 5, 1, 9),
        );
        await dayLogsDao.saveForDate(
          date: DateTime(2026, 5, 2),
          mood: 4,
          note: 'Zephyrglobal diary note about the day.',
        );
        final recipeId = await recipesDao.createRecipe('Zephyrglobal recipe name');
        // Никаких дополнительных полей не нужно — совпадение уже по имени.
        expect(recipeId, isNotEmpty);
        await shoppingDao.insertItem(
          name: 'Zephyrglobal shopping item',
          quantity: '2 pcs',
        );

        await tester.pumpWidget(harness());
        await tester.pump();

        await typeAndWaitForResults(tester, 'zephyrglobal');

        // Заголовки секций (EN — дефолтная локаль в тестовом MaterialApp).
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('Diary'), findsOneWidget);
        expect(find.text('Recipes'), findsOneWidget);
        expect(find.text('Shopping'), findsOneWidget);

        // Сами хиты.
        expect(find.text('Zephyrglobal task title'), findsOneWidget);
        expect(find.textContaining('Zephyrglobal diary'), findsOneWidget);
        expect(find.text('Zephyrglobal recipe name'), findsOneWidget);
        expect(find.text('Zephyrglobal shopping item'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      await unmountAndFlush(tester);
    });

    testWidgets('unmatched query shows no-results empty state', (tester) async {
      await tester.runAsync(() async {
        await insertItem(
          itemsDao,
          id: 'task-1',
          title: 'Something else entirely',
        );

        await tester.pumpWidget(harness());
        await tester.pump();

        await typeAndWaitForResults(tester, 'doesnotexistanywhere');

        expect(find.byType(ListView), findsNothing);
        expect(find.text('No results'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      await unmountAndFlush(tester);
    });
  });

  group('GlobalSearchScreen — overflow audit (gate B)', () {
    testWidgets('320px + textScale 2.0 with long results: no overflow',
        (tester) async {
      final longTitle = 'Zephyrlong ${'task title word ' * 12}wraps a lot';
      final longNote = 'Zephyrlong ${'diary note filler text ' * 12}end';
      final longRecipeName = 'Zephyrlong ${'recipe name repeated word ' * 12}end';
      final longShoppingName =
          'Zephyrlong ${'shopping item description ' * 12}end';

      await tester.runAsync(() async {
        await insertItem(itemsDao, id: 'task-1', title: longTitle);
        await dayLogsDao.saveForDate(
          date: DateTime(2026, 5, 3),
          mood: 3,
          note: longNote,
        );
        await recipesDao.createRecipe(longRecipeName);
        await shoppingDao.insertItem(
          name: longShoppingName,
          quantity: '20 kg extra long quantity description text',
        );

        const narrowSize = Size(320, 760);
        await setSize(tester, narrowSize);
        await tester.pumpWidget(harness(size: narrowSize, textScale: 2.0));
        await tester.pump();

        await typeAndWaitForResults(tester, 'zephyrlong');

        // Если бы был overflow — pump() внутри typeAndWaitForResults уже
        // бросил бы FlutterError; дополнительно подтверждаем явно.
        expect(tester.takeException(), isNull);
      });

      await unmountAndFlush(tester);
    });
  });
}
