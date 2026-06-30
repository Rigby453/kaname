// Тесты #22: переключатель периода День/Неделя/Месяц в WaterReportScreen +
// фикс триажа water-weekly-headline-sum (главный показатель Недели/Месяца
// должен быть СРЕДНЕЕ/день, а не сумма за период — было 4750 вместо 679/день).
//
// Также чистые юнит-тесты бакетинга внутридневного графика (waterHourlyBuckets/
// waterHourlyLabels) — без BuildContext, без Flutter pump.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/core/widgets/period_switcher.dart';
import 'package:app/features/health/water_report_screen.dart';
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

Future<void> _insertWater(
  AppDatabase db,
  int amountMl,
  DateTime loggedAt,
  String id,
) {
  return db.into(db.waterLogsTable).insert(
        WaterLogsTableCompanion(
          id: Value(id),
          amountMl: Value(amountMl),
          loggedAt: Value(loggedAt),
        ),
      );
}

void main() {
  group('waterHourlyBuckets / waterHourlyLabels — чистые функции', () {
    test('бакетит записи по 4-часовым интервалам (6 бакетов)', () {
      final logs = [
        WaterLogsTableData(
          id: '1',
          amountMl: 250,
          loggedAt: DateTime(2026, 1, 1, 7), // бакет 1 (4-8)
        ),
        WaterLogsTableData(
          id: '2',
          amountMl: 300,
          loggedAt: DateTime(2026, 1, 1, 9), // бакет 2 (8-12)
        ),
        WaterLogsTableData(
          id: '3',
          amountMl: 200,
          loggedAt: DateTime(2026, 1, 1, 7, 30), // тот же бакет 1, что и #1
        ),
      ];

      final buckets = waterHourlyBuckets(logs);
      expect(buckets, hasLength(6));
      expect(buckets[1], 450); // 250 + 200
      expect(buckets[2], 300);
      expect(buckets[0], 0);
    });

    test('пустой список → все бакеты по нулям', () {
      expect(waterHourlyBuckets(const []), List.filled(6, 0));
    });

    test('лейблы бакетов — часы начала, без l10n', () {
      expect(
        waterHourlyLabels(),
        ['00', '04', '08', '12', '16', '20'],
      );
    });
  });

  group('ReportPeriodX.days', () {
    test('day=1, week=7, month=30', () {
      expect(ReportPeriod.day.days, 1);
      expect(ReportPeriod.week.days, 7);
      expect(ReportPeriod.month.days, 30);
    });
  });

  group('WaterReportScreen — Week period headline', () {
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
          home: const WaterReportScreen(),
        ),
      );
    }

    // Прокачка экрана: первичный pump + реальные микротаски для Drift-стримов
    // (runAsync) + ещё пара кадров для анимаций — копия из screens_smoke_all_test.dart
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
      'headline = average/day (1.0L), NOT sum over the week (7.0L) — '
      'триаж water-weekly-headline-sum',
      (tester) async {
        await tester.runAsync(() async {
          final today = DateTime.now();
          final todayMidnight = DateTime(today.year, today.month, today.day);
          // 7 дней по 1000 мл/день = 7000 мл суммарно. Если бы headline
          // показывал сумму — была бы «7.0L»; правильно — «1.0L» среднее.
          for (var i = 0; i < 7; i++) {
            await _insertWater(
              db,
              1000,
              todayMidnight
                  .subtract(Duration(days: i))
                  .add(const Duration(hours: 9)),
              'w-$i',
            );
          }
        });

        await tester.pumpWidget(harness());
        await settle(tester);

        // Режим День по умолчанию — total сегодняшнего дня = 1000 мл = «1.0L».
        expect(find.text('1.0L'), findsOneWidget);

        // Переключаемся на Неделю.
        await tester.tap(find.text('Week'));
        await settle(tester);

        // headline подписан «Avg / day» и равен среднему — «1.0L».
        expect(find.text('Avg / day'), findsOneWidget);
        expect(find.text('1.0L'), findsOneWidget);
        // Сумма за неделю (баг) не должна нигде отображаться как headline.
        expect(find.text('7.0L'), findsNothing);

        await unmountAndFlush(tester);
      },
    );

    testWidgets(
      'PeriodSwitcher переключает Day/Week/Month, DateNavigator не падает',
      (tester) async {
        await tester.pumpWidget(harness());
        await settle(tester);

        expect(find.text('Day'), findsOneWidget);
        expect(find.text('Week'), findsOneWidget);
        expect(find.text('Month'), findsOneWidget);

        await tester.tap(find.text('Month'));
        await settle(tester);
        expect(find.text('Goal days'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Day'));
        await settle(tester);
        expect(tester.takeException(), isNull);

        await unmountAndFlush(tester);
      },
    );
  });
}
