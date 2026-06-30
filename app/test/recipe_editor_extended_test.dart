// Виджет-тесты расширенного редактора рецептов (#25 описание/шаги/видео,
// #27 live-поиск ингредиентов). См. lib/features/food/recipe_editor_screen.dart.
//
// Харнесс — копия паттерна food_search_sheet_display_test.dart: ProviderScope
// с appDatabaseProvider/sharedPreferencesProvider/apiClientProvider overrides,
// MaterialApp(home: RecipeEditorScreen(...)). Seeding Drift — внутри
// tester.runAsync (правило проекта: seeding в потоках Drift может зависнуть
// под фейковым тестовым clock без runAsync).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/recipes_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/food/recipe_editor_screen.dart';
import 'package:app/services/api/api_client.dart' show ApiClient, apiClientProvider;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема (без GoogleFonts — ускоряет тесты)
// ---------------------------------------------------------------------------
ThemeData _testTheme() => ThemeData.dark().copyWith(
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

// ---------------------------------------------------------------------------
// Фейковый ApiClient, считающий вызовы foodSearch (для проверки дебаунса #27)
// ---------------------------------------------------------------------------
class _CountingApiClient extends ApiClient {
  _CountingApiClient(super.prefs);

  int callCount = 0;
  final List<String> queries = [];

  @override
  Future<List<dynamic>> foodSearch(String query) async {
    callCount++;
    queries.add(query);
    return const [
      {
        'name': 'Greek Salad',
        'brand': null,
        'per_100g': {'calories': 52.0, 'protein': 2.1, 'fat': 3.5, 'carbs': 3.7},
      },
    ];
  }
}

// ---------------------------------------------------------------------------
// Тестовый стенд
// ---------------------------------------------------------------------------
Widget _harness(
  AppDatabase db,
  SharedPreferences prefs, {
  required String recipeId,
  ApiClient? apiClient,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
    ],
    child: MaterialApp(
      theme: _testTheme(),
      // disableAnimations: KaiMascot запускает бесконечную idle-анимацию
      // дыхания (_breathCtrl.repeat) в пустом состоянии редактора — без этого
      // pumpAndSettle() никогда не «осядет» (см. kai_mascot.dart::_startLoops,
      // kai_mascot_tap_test.dart использует тот же приём). textScaler — для
      // overflow-гейта (CLAUDE.md: 320px + textScale 1.5–2.0).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: RecipeEditorScreen(recipeId: recipeId),
    ),
  );
}

void main() {
  late AppDatabase db;
  late RecipesDao dao;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = RecipesDao(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  /// Закрыть экран и дождаться завершения оставшихся таймеров Drift
  /// (StreamQueryStore.markAsClosed планирует Timer(Duration.zero) на отмену
  /// подписки потока) — иначе binding падает на «Pending timers» в конце
  /// теста. Паттерн скопирован из food_search_sheet_display_test.dart.
  Future<void> flush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  // ---------------------------------------------------------------------------
  // #25 — пустой (только что созданный) рецепт показывает KaiMascot-подсказку
  // и три кнопки быстрого старта (описание / шаг / ингредиент).
  // ---------------------------------------------------------------------------
  testWidgets(
    'совершенно новый рецепт показывает подсказку и три кнопки быстрого старта',
    (tester) async {
      await tester.runAsync(() async {
        final id = await dao.createRecipe('New recipe');
        await tester.pumpWidget(_harness(db, prefs, recipeId: id));
        await tester.pumpAndSettle();

        expect(find.text('Add description'), findsOneWidget);
        expect(find.text('Add step'), findsOneWidget);
        // «Add ingredient» виден дважды: в пустом состоянии + в нижней панели
        expect(find.text('Add ingredient'), findsNWidgets(2));
      });
      await flush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // #25 — описание: диалог сохраняет текст, текст виден в секции, DAO обновлён
  // ---------------------------------------------------------------------------
  testWidgets(
    'описание рецепта: диалог сохраняет текст и отображается в секции',
    (tester) async {
      await tester.runAsync(() async {
        final id = await dao.createRecipe('Pancakes');
        await dao.addIngredient(recipeId: id, name: 'Flour', grams: 100);
        await tester.pumpWidget(_harness(db, prefs, recipeId: id));
        await tester.pumpAndSettle();

        expect(find.text('No description yet'), findsOneWidget);

        // Первый «Edit»-карандаш в дереве — секция Description (рендерится
        // раньше секции Video).
        await tester.tap(find.byTooltip('Edit').first);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          'Fluffy breakfast pancakes',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Fluffy breakfast pancakes'), findsOneWidget);
        final saved = (await dao.watchRecipes().first).single;
        expect(saved.description, 'Fluffy breakfast pancakes');
      });
      await flush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // #25 — шаги приготовления: добавление, отображение, удаление + Undo
  // ---------------------------------------------------------------------------
  testWidgets(
    'шаг приготовления: добавление отображает текст; удаление снимает его, Undo возвращает',
    (tester) async {
      await tester.runAsync(() async {
        final id = await dao.createRecipe('Fried rice');
        await dao.addIngredient(recipeId: id, name: 'Rice', grams: 200);
        await tester.pumpWidget(_harness(db, prefs, recipeId: id));
        await tester.pumpAndSettle();

        expect(find.text('No steps yet'), findsOneWidget);

        await tester.tap(find.text('Add step'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'Boil the rice');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Boil the rice'), findsOneWidget);
        final stepsAfterAdd = await dao.watchSteps(id).first;
        expect(stepsAfterAdd, hasLength(1));

        // Trash первой строки в дереве — шаг (Steps-секция рендерится перед
        // Ingredients-секцией, где тоже есть кнопка «Delete»).
        await tester.tap(find.byTooltip('Delete').first);
        await tester.pumpAndSettle();

        expect(find.text('Boil the rice'), findsNothing);
        expect(find.text('Step removed'), findsOneWidget);
        expect(await dao.watchSteps(id).first, isEmpty);

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        expect(find.text('Boil the rice'), findsOneWidget);
        expect(await dao.watchSteps(id).first, hasLength(1));
      });
      await flush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // #25 — видео-ссылка: валидация http(s)://, сохранение, fallback при открытии
  // ---------------------------------------------------------------------------
  testWidgets(
    'видео-ссылка: невалидный текст — ошибка; валидный — сохраняется и отображается',
    (tester) async {
      await tester.runAsync(() async {
        final id = await dao.createRecipe('Omelette');
        await dao.addIngredient(recipeId: id, name: 'Eggs', grams: 100);
        await tester.pumpWidget(_harness(db, prefs, recipeId: id));
        await tester.pumpAndSettle();

        // Video-секция — внизу списка, за пределами стартового viewport'а
        // в тесте (ListView виртуализирует офскрин-детей) — докручиваем.
        await tester.scrollUntilVisible(
          find.text('No video link yet'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('No video link yet'), findsOneWidget);

        // Второй «Edit»-карандаш в дереве — секция Video.
        await tester.tap(find.byTooltip('Edit').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'not a url');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(
          find.text('Enter a link starting with http:// or https://'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byType(TextField).first,
          'https://example.com/omelette',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.textContaining('https://example.com/omelette'), findsOneWidget);
        final saved = (await dao.watchRecipes().first).single;
        expect(saved.videoUrl, 'https://example.com/omelette');

        // Платформенный канал url_launcher не имеет нативной реализации в
        // юнит-тестах (нет мока) — главное, что тап не роняет экран
        // независимо от того, ответит ли launchUrl true/false/исключением.
        await tester.tap(find.byTooltip('Open video'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      });
      await flush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // #27 — поиск ингредиента: live-поиск с дебаунсом ~300мс, без нажатия кнопки
  // ---------------------------------------------------------------------------
  testWidgets(
    '#27 поиск ингредиента: запрос уходит автоматически после паузы в наборе',
    (tester) async {
      final api = _CountingApiClient(prefs);
      await tester.runAsync(() async {
        final id = await dao.createRecipe('Salad');
        await dao.updateDescription(id, 'Fresh veggie salad');
        await tester.pumpWidget(_harness(db, prefs, recipeId: id, apiClient: api));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add ingredient'));
        await tester.pumpAndSettle();

        // Печатаем БЕЗ нажатия кнопки поиска
        await tester.enterText(find.byType(TextField).first, 'greek');
        expect(api.callCount, 0); // дебаунс ещё не сработал

        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(api.callCount, 1);
        expect(api.queries.single, 'greek');
        expect(find.text('Greek Salad'), findsOneWidget);
      });
      await flush(tester);
    },
  );

  testWidgets(
    '#27 быстрый повторный ввод схлопывается в один сетевой запрос (debounce отменяется)',
    (tester) async {
      final api = _CountingApiClient(prefs);
      await tester.runAsync(() async {
        final id = await dao.createRecipe('Salad');
        await dao.updateDescription(id, 'Fresh veggie salad');
        await tester.pumpWidget(_harness(db, prefs, recipeId: id, apiClient: api));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add ingredient'));
        await tester.pumpAndSettle();

        final field = find.byType(TextField).first;
        await tester.enterText(field, 'g');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        await tester.enterText(field, 'gr');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        await tester.enterText(field, 'gre');

        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(api.callCount, 1);
        expect(api.queries.single, 'gre');
      });
      await flush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // Overflow gate (CLAUDE.md anti-regression): 320px ширина + textScale 1.5
  // на полностью заполненном рецепте (описание/шаги с длинным текстом/
  // ингредиенты/видео-ссылка) — без RenderFlex-исключений.
  // ---------------------------------------------------------------------------
  testWidgets(
    'overflow: 320px + textScale 1.5 на заполненном рецепте не падает',
    (tester) async {
      await tester.runAsync(() async {
        final id = await dao.createRecipe('Stress test recipe');
        await dao.updateDescription(
          id,
          'A very long description that should wrap across several lines '
          'without causing any RenderFlex overflow even on a narrow 320px '
          'screen with a large accessibility text scale factor applied.',
        );
        await dao.addStep(
          recipeId: id,
          text: 'A very long step description that wraps across multiple '
              'lines to make sure the step row layout never overflows '
              'horizontally regardless of text scale.',
        );
        await dao.addStep(recipeId: id, text: 'Second short step');
        await dao.addIngredient(
          recipeId: id,
          name: 'Extra virgin olive oil with a fairly long product name',
          grams: 15,
        );
        await dao.addIngredient(recipeId: id, name: 'Salt', grams: 2);
        await dao.updateVideoUrl(
          id,
          'https://example.com/a/very/long/video/url/that/might/wrap',
        );

        await tester.binding.setSurfaceSize(const Size(320, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_harness(db, prefs, recipeId: id, textScale: 1.5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
      });
      await flush(tester);
    },
  );
}
