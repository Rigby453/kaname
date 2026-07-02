// workout_editor_undo_test.dart
// Регресс-тест Defect 2: «удаление упражнения из редактора тренировки».
//
// Wave 4 (2026-07) убрала Undo-снэкбар во всём приложении и заменила его
// confirm-диалогом перед деструктивным удалением (см. docs/decisions.md,
// core/widgets/swipe_to_delete.dart::showDeleteConfirmDialog).
// Файл переписан под НОВОЕ поведение — тестируем confirm-flow, а не Undo.
//
// Verifies:
//   a) Тап по кнопке-корзине открывает блокирующий confirm-диалог
//      (dialog.delete_confirm_title), а НЕ Undo-снэкбар — упражнение пока
//      не удалено.
//   b) Cancel в диалоге сохраняет упражнение (удаления не произошло).
//   c) Delete в диалоге удаляет упражнение (без Undo).
//
// Таймер тоста (showAppToast) после подтверждённого удаления прокачивается
// в конце теста (3), чтобы не оставлять pending timers — как раньше.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/health/workout_editor_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Seed: создать тренировку + одно упражнение. Возвращает workoutId.
// ---------------------------------------------------------------------------

Future<String> _seedWorkout(WidgetTester tester, AppDatabase db) async {
  late String workoutId;
  await tester.runAsync(() async {
    // WorkoutsDao не является геттером AppDatabase — создаём напрямую.
    final dao = WorkoutsDao(db);
    workoutId = await dao.createWorkout('Test Workout');
    await dao.addExercise(
      workoutId: workoutId,
      name: 'Push-up',
      sets: 3,
      reps: 10,
    );
  });
  return workoutId;
}

// ---------------------------------------------------------------------------
// Тестовая тема (FocusThemeExtension required by WorkoutEditorScreen)
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
// Settle/unmount helpers
// ---------------------------------------------------------------------------

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}

Widget _harness(Widget screen, AppDatabase db, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(390, 800)),
      child: MaterialApp(
        theme: _testTheme(),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: screen,
      ),
    ),
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
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Defect 2(a): confirm-диалог появляется после тапа по корзине,
  // Undo-снэкбара больше нет.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
      'delete shows confirm dialog, not an Undo snackbar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workoutId = await _seedWorkout(tester, db);

    await tester.pumpWidget(
        _harness(WorkoutEditorScreen(workoutId: workoutId), db, prefs));
    await _settle(tester);

    // Упражнение должно отображаться.
    expect(find.text('Push-up'), findsOneWidget);

    // Тапаем кнопку удаления (trailing IconButton с PhosphorIcons.trash()).
    // Trash-иконка единственна при одном упражнении (history-иконка другая).
    await tester.tap(find.byIcon(PhosphorIcons.trash()).last);
    await tester.pump(); // открывается showDialog
    await tester.pump(const Duration(milliseconds: 300)); // dialog enter animation

    // Confirm-диалог должен появиться (AlertDialog с title/Cancel/Delete),
    // Undo-снэкбара НЕТ.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete?'), findsOneWidget); // dialog.delete_confirm_title (en)
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
    expect(
      find.text('Undo'),
      findsNothing,
      reason: 'Undo-снэкбар убран (wave 4) — теперь блокирующий confirm-диалог',
    );

    // Диалог блокирует — упражнение ещё не удалено.
    expect(find.text('Push-up'), findsOneWidget);

    await _unmount(tester);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Defect 2(b): Cancel в диалоге сохраняет упражнение.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
      'cancel keeps the exercise',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workoutId = await _seedWorkout(tester, db);

    await tester.pumpWidget(
        _harness(WorkoutEditorScreen(workoutId: workoutId), db, prefs));
    await _settle(tester);

    expect(find.text('Push-up'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIcons.trash()).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

    // Отменяем удаление.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump(); // dialog pop
    await tester.pump(const Duration(milliseconds: 300)); // dialog exit animation

    // Диалог закрылся, упражнение по-прежнему на месте (ничего не удалено).
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Push-up'),
      findsOneWidget,
      reason: 'Cancel не должен удалять упражнение',
    );

    await _unmount(tester);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Defect 2(c): Delete в диалоге удаляет упражнение (без Undo).
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
      'confirm deletes the exercise',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workoutId = await _seedWorkout(tester, db);

    await tester.pumpWidget(
        _harness(WorkoutEditorScreen(workoutId: workoutId), db, prefs));
    await _settle(tester);

    expect(find.text('Push-up'), findsOneWidget);

    // Открываем confirm-диалог заново.
    await tester.tap(find.byIcon(PhosphorIcons.trash()).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);

    // Подтверждаем удаление.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump(); // dialog pop → suspend at await removeExercise
    await tester.pump(); // microtask: removeExercise resolves → showAppToast
    await _settle(tester); // Drift stream emits → exercises list обновляется

    // Упражнение должно исчезнуть, без Undo.
    expect(
      find.text('Push-up'),
      findsNothing,
      reason: 'Delete должен удалить упражнение окончательно',
    );
    expect(find.text('Undo'), findsNothing);

    // Прокачиваем таймер автоскрытия тоста, чтобы не оставлять pending timers.
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
