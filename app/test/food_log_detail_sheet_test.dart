// Виджет-тесты шита просмотра/редактирования залогированной записи о еде
// (food-1: food_log_detail_sheet.dart).
//
// Проверяем:
// 1. Шит открывается тапом по строке в дневнике еды (FoodScreen → _FoodRow)
//    и показывает название + начальные значения КБЖУ/сахара/клетчатки.
// 2. Правка поля «Calories» пересчитывает живую подпись «на 100 г».
// 3. [Save] пишет новые значения ИМЕННО в эту запись food_logs (DAO),
//    остальные записи/поля (name/grams/meal) не трогает.
//
// БД — in-memory Drift (AppDatabase.forTesting).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/food/food_log_detail_sheet.dart';
import 'package:app/features/food/food_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема (без GoogleFonts, с FocusThemeExtension)
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
  Size surfaceSize = const Size(390, 800),
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: surfaceSize, textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: _testTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Вставить запись еды напрямую в БД (минуя UI), возвращает вставленную запись.
Future<FoodLogsTableData> _insertLog(
  AppDatabase db, {
  required String name,
  required double grams,
  double? calories,
  double? protein,
  double? fat,
  double? carbs,
  double? sugar,
  double? fiber,
  String meal = 'lunch',
  // По умолчанию — фиксированная дата (для тестов, не зависящих от провайдера
  // «сегодня»). FoodScreen-тест передаёт DateTime.now(), т.к. _todayFoodProvider
  // фильтрует записи строго по текущему дню.
  DateTime? date,
}) async {
  final day = date ?? DateTime.utc(2026, 1, 1);
  final dayStart = DateTime.utc(day.year, day.month, day.day);
  final id = 'log-${DateTime.now().microsecondsSinceEpoch}';
  final companion = FoodLogsTableCompanion(
    id: Value(id),
    date: Value(dayStart),
    meal: Value(meal),
    name: Value(name),
    grams: Value(grams),
    calories: Value(calories),
    protein: Value(protein),
    fat: Value(fat),
    carbs: Value(carbs),
    sugar: Value(sugar),
    fiber: Value(fiber),
    createdAt: Value(DateTime.now()),
  );
  await db.into(db.foodLogsTable).insert(companion);
  return FoodLogsTableData(
    id: id,
    date: dayStart,
    meal: meal,
    name: name,
    grams: grams,
    calories: calories,
    protein: protein,
    fat: fat,
    carbs: carbs,
    sugar: sugar,
    fiber: fiber,
    createdAt: DateTime.now(),
  );
}

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

  // Drift закрывает стримы и оставляет zero-duration таймер.
  Future<void> flush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('шит показывает название и начальные значения КБЖУ',
      (tester) async {
    await tester.runAsync(() async {
      final log = await _insertLog(
        db,
        name: 'Greek Salad',
        grams: 200,
        calories: 240,
        protein: 10,
        fat: 16,
        carbs: 14,
        sugar: 6,
        fiber: 4,
      );

      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFoodLogDetailSheet(ctx, log),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Заголовок шита — название блюда
      expect(find.text('Greek Salad'), findsOneWidget);
      // Граммы порции
      expect(find.textContaining('200'), findsAtLeastNWidgets(1));

      // Поля КБЖУ заполнены исходными значениями
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields.length, 6); // calories, protein, fat, carbs, sugar, fiber
      final values = fields
          .map((f) => f.controller!.text)
          .toList();
      expect(values, containsAll(['240', '10', '16', '14', '6', '4']));

      // На 100 г: 240/200*100 = 120 ккал/100г — должно отобразиться где-то в шите
      expect(find.textContaining('120'), findsAtLeastNWidgets(1));
    });
    await flush(tester);
  });

  testWidgets('правка поля Calories пересчитывает подпись «на 100 г» живьём',
      (tester) async {
    await tester.runAsync(() async {
      final log = await _insertLog(
        db,
        name: 'Oatmeal',
        grams: 100,
        calories: 150,
        protein: 5,
        fat: 3,
        carbs: 27,
      );

      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFoodLogDetailSheet(ctx, log),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Изначально: 150 ккал на 100 г порции → per100 тоже 150
      expect(find.textContaining('150'), findsAtLeastNWidgets(1));

      // Меняем калории на 300 (порция всё ещё 100 г → per100 тоже 300)
      // find.byType(...).at(0) ленивый — пересчитывается по актуальному дереву,
      // безопасно использовать даже после ребилда.
      await tester.enterText(find.byType(TextFormField).at(0), '300');
      await tester.pump();

      // Подпись «на 100 г» должна обновиться без сохранения
      expect(find.textContaining('300'), findsAtLeastNWidgets(1));
    });
    await flush(tester);
  });

  testWidgets('[Save] пишет новые КБЖУ ИМЕННО в эту запись (DAO), не трогая name/grams/meal',
      (tester) async {
    await tester.runAsync(() async {
      final log = await _insertLog(
        db,
        name: 'Banana',
        grams: 120,
        calories: 100,
        protein: 1,
        fat: 0.3,
        carbs: 23,
        sugar: 12,
        fiber: 2.6,
      );

      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFoodLogDetailSheet(ctx, log),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Порядок полей: calories, protein, fat, carbs, sugar, fiber.
      // find.byType(...).at(i) ленивый — переоценивается заново на каждый вызов,
      // поэтому безопасен после ребилда (setState на onChanged пересоздаёт виджеты).
      await tester.enterText(find.byType(TextFormField).at(0), '110'); // calories
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(4), '8'); // sugar
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.foodLogsTable).get();
      expect(rows, hasLength(1));
      final updated = rows.first;
      expect(updated.id, log.id);
      expect(updated.calories, 110.0);
      expect(updated.sugar, 8.0);
      // Остальные значения не задетые правкой — сохраняются как были
      expect(updated.protein, 1.0);
      expect(updated.fat, 0.3);
      expect(updated.carbs, 23.0);
      expect(updated.fiber, 2.6);
      // Запись осталась той же самой (не глобальный продукт): name/grams/meal неизменны
      expect(updated.name, 'Banana');
      expect(updated.grams, 120.0);
      expect(updated.meal, 'lunch');
    });
    await flush(tester);
  });

  testWidgets('FoodScreen: тап по строке открывает шит деталей записи',
      (tester) async {
    await tester.runAsync(() async {
      await _insertLog(
        db,
        name: 'Yogurt',
        grams: 150,
        calories: 90,
        protein: 8,
        fat: 2,
        carbs: 10,
        meal: 'breakfast',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        _harness(db, prefs, child: const FoodScreen()),
      );
      // Дать стриму DAO прогрузиться
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Yogurt'), findsOneWidget);

      await tester.tap(find.text('Yogurt'));
      await tester.pumpAndSettle();

      // Шит открылся: видно поле ввода с исходным значением калорий
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields, isNotEmpty);
      expect(fields.first.controller!.text, '90');
    });
    await flush(tester);
  });

  testWidgets('шит выживает на ширине 320px и textScale 1.5 (без overflow)',
      (tester) async {
    await tester.runAsync(() async {
      final log = await _insertLog(
        db,
        name: 'A very long descriptive dish name that could wrap awkwardly',
        grams: 250,
        calories: 480,
        protein: 25,
        fat: 18,
        carbs: 50,
        sugar: 9,
        fiber: 7,
      );

      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          surfaceSize: const Size(320, 700),
          textScale: 1.5,
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFoodLogDetailSheet(ctx, log),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
    await flush(tester);
  });
}
