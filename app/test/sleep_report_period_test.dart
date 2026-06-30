// Тесты #22: переключатель периода День/Неделя/Месяц в SleepReportScreen.
// avgHours в SleepStats уже считается как среднее ПО НОЧАМ (не sum/период) —
// триаж water-weekly-headline-sum к сну неприменим, фикса не требовалось.
// Эти тесты проверяют, что окно (1/7/30 дней) реально расширяет историю,
// которую видит пользователь, и что чарт-секция (Week/Month) рендерится.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/health/sleep_report_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _insertNight(
  AppDatabase db,
  String id,
  DateTime startAt,
  DateTime endAt,
) {
  return db.into(db.sleepLogsTable).insert(
        SleepLogsTableCompanion(
          id: Value(id),
          startAt: Value(startAt),
          endAt: Value(endAt),
        ),
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

  Widget harness() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        theme: _testTheme(),
        home: const SleepReportScreen(),
      ),
    );
  }

  // Прокачка экрана: первичный pump + реальные микротаски для Drift-стримов
  // (runAsync) + ещё пара кадров — копия из screens_smoke_all_test.dart
  // (bare pumpAndSettle зависает на открытых Drift-стримах — "Pending timers").
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'Day shows only today\'s night; Week widens history to include older '
    'nights within the 7-day window',
    (tester) async {
      await tester.runAsync(() async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Сегодня: лёг в 23:00 вчера, встал в 07:00 сегодня (8ч) — endAt сегодня.
        await _insertNight(
          db,
          'n-today',
          today.subtract(const Duration(hours: 1)),
          today.add(const Duration(hours: 7)),
        );
        // 2 дня назад — тоже 8ч.
        final twoDaysAgo = today.subtract(const Duration(days: 2));
        await _insertNight(
          db,
          'n-2',
          twoDaysAgo.subtract(const Duration(hours: 1)),
          twoDaysAgo.add(const Duration(hours: 7)),
        );
        // 5 дней назад — в пределах недели, но не дня.
        final fiveDaysAgo = today.subtract(const Duration(days: 5));
        await _insertNight(
          db,
          'n-5',
          fiveDaysAgo.subtract(const Duration(hours: 1)),
          fiveDaysAgo.add(const Duration(hours: 7)),
        );
      });

      await tester.pumpWidget(harness());
      await settle(tester);

      // День — totalNights=1 (только сегодняшняя ночь).
      expect(find.text('1'), findsOneWidget);
      // Чарт-секция «Trend» не показывается в режиме День.
      expect(find.text('Trend'), findsNothing);

      // Переключаемся на Неделю — окно расширяется, видны все 3 ночи.
      await tester.tap(find.text('Week'));
      await settle(tester);

      expect(find.text('3'), findsOneWidget); // totalNights за неделю
      expect(find.text('Trend'), findsOneWidget); // бар+линия чарт появился
      expect(tester.takeException(), isNull);

      await unmountAndFlush(tester);
    },
  );

  testWidgets('Month period renders without crashing (sparse chart labels)',
      (tester) async {
    await tester.runAsync(() async {
      final today = DateTime.now();
      final base = DateTime(today.year, today.month, today.day);
      await _insertNight(
        db,
        'n-month',
        base.subtract(const Duration(hours: 1)),
        base.add(const Duration(hours: 7)),
      );
    });

    await tester.pumpWidget(harness());
    await settle(tester);

    await tester.tap(find.text('Month'));
    await settle(tester);

    expect(find.text('Trend'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await unmountAndFlush(tester);
  });
}
