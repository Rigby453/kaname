// Виджет-тест листа «Собрать программу» (ai_workout_sheet.dart).
//
// Проверяем FREE/template-путь end-to-end: открыть лист → нажать «Build program»
// → программа сохранилась в in-memory Drift (WorkoutsTable + WorkoutExercisesTable).
// Сеть НЕ трогаем (только free-путь). Паттерн ProviderScope + NativeDatabase.memory
// скопирован из screens_smoke_all_test.dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/l10n/strings/health_b.dart' show healthBStrings;
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/health/ai_workout_sheet.dart';

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

  // Крошечный харнесс: кнопка, открывающая лист через showAiWorkoutSheet.
  Widget harness() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => showAiWorkoutSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'FREE «Build program» сохраняет дни и упражнения в Drift',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // Открыть лист.
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // анимация открытия листа

    // Лист открылся: видна кнопка сборки (free) — текст из l10n.
    final buildBtn = find.text(enS('workout.ai_build_free'));
    expect(buildBtn, findsOneWidget);

    // Кнопка в самом низу прокручиваемого листа — на тест-вьюпорте (800x600)
    // она ниже сгиба, прямой tap промахивается. Прокручиваем её в видимую зону.
    await tester.ensureVisible(buildBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // Нажать «Build program» (дефолты анкеты: muscle / beginner / bodyweight / 3 дня).
    await tester.tap(buildBtn);
    // Сохранение асинхронное (Drift) — даём ему отработать на реальном клоке.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Проверяем БД напрямую.
    final dao = WorkoutsDao(db);
    // Чтение Drift-стрима ТОЛЬКО внутри runAsync: под фейковыми часами теста
    // .first иначе зависает (zero-duration таймер стрима не срабатывает).
    final workouts = (await tester.runAsync(() => dao.watchWorkouts().first))!;
    // beginner @ 3 дня → full-body сплит = 3 шаблона.
    expect(workouts.length, 3);

    // Каждый шаблон содержит хотя бы одно упражнение.
    var totalExercises = 0;
    for (final w in workouts) {
      final ex = (await tester.runAsync(() => dao.watchExercises(w.id).first))!;
      expect(ex, isNotEmpty, reason: w.name);
      totalExercises += ex.length;
      // reps записан как int; technique хранит исходный диапазон ("8-12" и т.п.).
      for (final e in ex) {
        expect(e.reps, greaterThan(0));
        expect(e.technique, isNotNull);
      }
    }
    expect(totalExercises, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

/// Резолвит английскую строку напрямую из фрагмента l10n (тест-локаль = en).
String enS(String key) => healthBStrings[key]?['en'] ?? key;
