// Виджет-тесты ветки отрисовки листа поиска еды (_FoodSearchSheetState.build).
//
// Проверяет исправление Bug 1: при пустом поле поиска и непустых _results
// (состояние после ИИ-фото-распознавания) должен отрисовываться ListView
// совпадений, а НЕ секция «Недавнее».
//
// Без исправления условие `_controller.text.trim().isEmpty && _recentLoaded`
// возвращало true и «Недавнее» перекрывало список совпадений.
// После исправления: `&& _results.isEmpty` добавлено — список совпадений виден.
//
// Для инъекции состояния (без запуска камеры) используется
// `showFoodSearchSheetWithPreset` — @visibleForTesting-хелпер из food_screen.dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/food/food_screen.dart' show showFoodSearchSheetWithPreset;
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
// Тестовый стенд
// ---------------------------------------------------------------------------
Widget _harness(
  AppDatabase db,
  SharedPreferences prefs, {
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: _testTheme(),
      home: Scaffold(body: child),
    ),
  );
}

/// Типичный продукт-объект (структура совпадает с API /food/search).
const _kTestProducts = [
  {
    'name': 'Greek Salad',
    'brand': null,
    'per_100g': {'calories': 52.0, 'protein': 2.1, 'fat': 3.5, 'carbs': 3.7},
  },
  {
    'name': 'Caesar Salad',
    'brand': null,
    'per_100g': {'calories': 120.0, 'protein': 4.0, 'fat': 8.0, 'carbs': 7.0},
  },
];

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  /// Закрыть bottom sheet и дождаться завершения оставшихся таймеров Drift.
  Future<void> flush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  // ---------------------------------------------------------------------------
  // Bug 1 fix: пустое поле + непустые _results → список совпадений, не «Недавнее»
  // ---------------------------------------------------------------------------
  testWidgets(
    'при пустом поле и предустановленных результатах виден список совпадений (не «Недавнее»)',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _harness(
            db,
            prefs,
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showFoodSearchSheetWithPreset(
                  ctx,
                  presetResults: _kTestProducts,
                  presetAiNote: 'AI: greek salad (87%) — pick a match',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.pump();

        // Открываем лист с предустановленными результатами (симуляция ИИ-фото)
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Bug 1 fix: результаты должны быть видны несмотря на пустое поле
        expect(find.textContaining('Greek Salad'), findsOneWidget);
        expect(find.textContaining('Caesar Salad'), findsOneWidget);

        // Секция «Недавнее» (Recent) должна быть скрыта — результаты перекрывают её
        expect(find.textContaining('Recent'), findsNothing);
        expect(find.textContaining('Недавнее'), findsNothing);

        // Подпись ИИ отображается над результатами
        expect(find.textContaining('87%'), findsOneWidget);
      });
      await flush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // Регресс: без результатов и пустое поле → «Недавнее» по-прежнему не видно,
  // если в БД нет истории (не сломали стандартное поведение)
  // ---------------------------------------------------------------------------
  testWidgets(
    'при пустом поле и отсутствии результатов и истории — лист пуст (без «Недавнее»)',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _harness(
            db,
            prefs,
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showFoodSearchSheetWithPreset(
                  ctx,
                  presetResults: const [],
                  presetAiNote: null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Нет продуктов, нет истории — показывается только заголовок листа («Add»)
        // и поле поиска; секция «Недавнее» скрыта (recentLogs пуст).
        expect(find.textContaining('Greek Salad'), findsNothing);
        expect(find.textContaining('Caesar Salad'), findsNothing);
        expect(find.textContaining('Recent'), findsNothing);
      });
      await flush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // Тест тапа: тап по ListTile продукта вызывает диалог порции (_PortionDialog)
  // ---------------------------------------------------------------------------
  testWidgets(
    'тап по ListTile продукта открывает диалог порции',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _harness(
            db,
            prefs,
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showFoodSearchSheetWithPreset(
                  ctx,
                  presetResults: _kTestProducts,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Тапаем по первому результату
        await tester.tap(find.textContaining('Greek Salad'));
        await tester.pumpAndSettle();

        // Диалог порции должен появиться (содержит название продукта в заголовке)
        expect(find.textContaining('Greek Salad'), findsAtLeastNWidgets(1));
        // Поле граммов ('Grams') из _PortionDialog
        expect(find.textContaining('Grams'), findsOneWidget);
      });
      await flush(tester);
    },
  );
}
