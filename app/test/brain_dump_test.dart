// Тесты ИИ-онбординга «брейн-дамп» (Волна 6, этап 3, brain_dump_screen.dart +
// brain_dump_preview.dart).
//
// 1) Юнит-тесты чистой функции parseOnboardingPlan (валидный план, deadline-
//    маппинг — решение C, мусорные элементы отброшены, food_prefs игнорится
//    без падения).
// 2) Юнит-тесты чистой функции activeHintIndex (пороги по 60 символов).
// 3) Виджет-тест BrainDumpScreen: 320px + textScale 2.0 без overflow.
// 4) Виджет-тесты BrainDumpPreviewScreen: рендер целей+задач с
//    переключателями; «Принять план» сохраняет только включённые записи
//    (реальный in-memory Drift, как в ai_quick_add_test.dart/logout_clear_test.dart).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/onboarding/brain_dump_preview.dart';
import 'package:app/features/onboarding/brain_dump_screen.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ThemeData _testTheme() {
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

void main() {
  // -------------------------------------------------------------------------
  // parseOnboardingPlan (чистая функция)
  // -------------------------------------------------------------------------
  group('parseOnboardingPlan', () {
    test('валидный план: цели + задачи', () {
      final plan = parseOnboardingPlan({
        'goals': [
          {'title': 'Learn Flutter', 'horizon': 'month'},
        ],
        'tasks': [
          {
            'title': 'Buy milk',
            'type': 'task',
            'priority': 'medium',
            'scheduled_at': '2026-07-05T10:00:00.000Z',
            'duration_minutes': 15,
          },
        ],
      });
      expect(plan.goals, hasLength(1));
      expect(plan.goals.first.title, 'Learn Flutter');
      expect(plan.goals.first.horizon, 'month');
      expect(plan.tasks, hasLength(1));
      expect(plan.tasks.first.title, 'Buy milk');
      expect(plan.tasks.first.durationMinutes, 15);
      expect(plan.isEmpty, isFalse);
    });

    test('deadline без scheduled_at → type=deadline, scheduledAt=deadline (решение C)', () {
      final plan = parseOnboardingPlan({
        'tasks': [
          {
            'title': 'Submit report',
            'type': 'task',
            'priority': 'high',
            'deadline': '2026-07-10T23:59:00.000Z',
          },
        ],
      });
      expect(plan.tasks.first.type, 'deadline');
      expect(
        plan.tasks.first.scheduledAt,
        DateTime.parse('2026-07-10T23:59:00.000Z').toLocal(),
      );
    });

    test('мусорные элементы (без title, не-Map) отброшены', () {
      final plan = parseOnboardingPlan({
        'goals': [
          {'title': ''},
          {'horizon': 'month'}, // нет title
          'not a map',
          {'title': 'Valid goal'},
        ],
        'tasks': [
          {'title': '   '},
          42,
          {'title': 'Valid task'},
        ],
      });
      expect(plan.goals, hasLength(1));
      expect(plan.goals.first.title, 'Valid goal');
      expect(plan.tasks, hasLength(1));
      expect(plan.tasks.first.title, 'Valid task');
    });

    test('невалидный горизонт → null (не мусор в поле)', () {
      final plan = parseOnboardingPlan({
        'goals': [
          {'title': 'Goal', 'horizon': 'decade'},
        ],
      });
      expect(plan.goals.first.horizon, isNull);
    });

    test('food_prefs присутствует — игнорится без падения', () {
      final plan = parseOnboardingPlan({
        'goals': <dynamic>[],
        'tasks': <dynamic>[],
        'food_prefs': {'tracks_food': true, 'tracks_water': false, 'tracks_sleep': true},
      });
      expect(plan.isEmpty, isTrue);
    });

    test('полностью пустой/битый ответ не бросает', () {
      expect(parseOnboardingPlan({}).isEmpty, isTrue);
      expect(parseOnboardingPlan({'goals': 'nope', 'tasks': null}).isEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // activeHintIndex (чистая функция)
  // -------------------------------------------------------------------------
  group('activeHintIndex', () {
    test('пустой текст → 0 отвеченных подсказок', () {
      expect(activeHintIndex(0), 0);
    });

    test('порог не пересечён (< 60) → 0', () {
      expect(activeHintIndex(59), 0);
    });

    test('порог первой подсказки пересечён (60) → 1', () {
      expect(activeHintIndex(60), 1);
      expect(activeHintIndex(119), 1);
    });

    test('второй порог (120) → 2', () {
      expect(activeHintIndex(120), 2);
    });

    test('превышение всех порогов ограничено kBrainDumpHintCount (6)', () {
      expect(activeHintIndex(1000), kBrainDumpHintCount);
      expect(activeHintIndex(360), 6);
      expect(activeHintIndex(361), 6);
    });
  });

  // -------------------------------------------------------------------------
  // Виджет-тесты
  // -------------------------------------------------------------------------
  group('widgets', () {
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

    Widget wrap(Widget child) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            theme: _testTheme(),
            home: child,
          ),
        ),
      );
    }

    /// Открывает [page] через push поверх кнопки-хоста — так же, как продакшен
    /// код открывает BrainDumpPreviewScreen (Navigator.push), и гарантирует
    /// canPop()==true (иначе Navigator.pop() внутри _accept — no-op на root route).
    Widget hostThatPushes(Widget page) {
      return Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<int>(builder: (_) => page)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets('BrainDumpScreen — 320px + textScale 2.0 без overflow',
        (tester) async {
      await tester.pumpWidget(wrap(const BrainDumpScreen()));
      await tester.pump();

      expect(find.text('Tell me what\'s going on'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('BrainDumpPreviewScreen — рендерит цели и задачи с переключателями',
        (tester) async {
      const plan = DraftPlan(
        goals: [DraftGoal(title: 'Learn Flutter', horizon: 'month')],
        tasks: [
          DraftTask(title: 'Buy milk', type: 'task', priority: 'medium'),
          DraftTask(title: 'Submit report', type: 'deadline', priority: 'high'),
        ],
      );

      await tester.pumpWidget(wrap(hostThatPushes(
        BrainDumpPreviewScreen(plan: plan, day: DateTime(2026, 7, 3)),
      )));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // push-переход

      expect(find.text('Learn Flutter'), findsOneWidget);
      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Submit report'), findsOneWidget);
      // 1 переключатель на цель + 2 на задачи = 3 Switch
      expect(find.byType(Switch), findsNWidgets(3));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('Принять план сохраняет только включённые записи', (tester) async {
      const plan = DraftPlan(
        goals: [DraftGoal(title: 'Learn Flutter', horizon: 'month')],
        tasks: [
          DraftTask(title: 'Buy milk', type: 'task', priority: 'medium'),
          DraftTask(title: 'Submit report', type: 'deadline', priority: 'high'),
        ],
      );

      await tester.pumpWidget(wrap(hostThatPushes(
        BrainDumpPreviewScreen(plan: plan, day: DateTime(2026, 7, 3)),
      )));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // push-переход

      // Выключаем третий Switch (цель + первая задача 'Buy milk' остаются
      // включёнными) — 'Submit report' исключаем.
      final switches = find.byType(Switch);
      await tester.tap(switches.at(2));
      await tester.pump();

      await tester.tap(find.text('Accept plan'));
      // Несколько «пустых» pump прогоняют цепочку await в _accept
      // (createGoal → insertItem для каждой включённой записи → SnackBar → pop).
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      final items = await db.select(db.itemsTable).get();
      final goals = await db.select(db.goalsTable).get();

      expect(goals, hasLength(1));
      expect(goals.first.title, 'Learn Flutter');
      expect(items, hasLength(1));
      expect(items.first.title, 'Buy milk');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
