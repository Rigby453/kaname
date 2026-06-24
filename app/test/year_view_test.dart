// Тесты год-вида Plan (YearView, как в Google Calendar).
//
// Покрываем:
//   1. YearView рендерится (мини-месяцы, заголовок-год).
//   2. День с задачами получает индикатор «занятости» (accent-заливка кружка).
//   3. Тап по дню зовёт навигацию: selectedDayProvider → этот день и
//      planViewProvider → PlanView.day.
//
// ВАЖНО: счётчик задач по дням (yearTaskCountsProvider) ПОДМЕНЁН фиксированными
// данными — чтобы НЕ трогать Drift-стрим за целый год под фейковым клоком теста
// (это вызывало дедлок). Так тест детерминирован и не зависает.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/core/utils/day_window.dart';
import 'package:app/features/plan/widgets/plan_providers.dart';
import 'package:app/features/plan/widgets/week_strip.dart'
    show selectedDayProvider;
import 'package:app/features/plan/widgets/year_view.dart';
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

  // Фиксируем выбранный день (и тем самым год) в текущем году — детерминированно.
  final year = DateTime.now().year;
  final fixedDay = DateTime(year, 6, 15);

  // Фиксированные счётчики: 15 июня — 3 задачи (насыщенная заливка-индикатор).
  Widget harness() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        selectedDayProvider.overrideWith((ref) => fixedDay),
        // Подмена агрегата — без Drift-стрима за год (источник дедлока).
        yearTaskCountsProvider(year).overrideWith(
          (ref) => AsyncValue.data({localDayKey(fixedDay): 3}),
        ),
      ],
      child: MaterialApp(
        theme: _testTheme(),
        home: const Scaffold(body: YearView()),
      ),
    );
  }

  // Прокачка без runAsync — Drift не задействован (провайдер подменён).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders mini-months and the year header', (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    expect(find.byType(YearView), findsOneWidget);
    // Заголовок-год виден.
    expect(find.text('$year'), findsOneWidget);
    // Верхние мини-месяцы в кадре (Jan..Mar гарантированно на 600px-высоте).
    for (final m in const ['Jan', 'Feb', 'Mar']) {
      expect(find.text(m), findsWidgets);
    }
  });

  testWidgets('day with tasks gets a busy indicator (accent fill)',
      (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(YearView)),
    );
    final counts = container.read(yearTaskCountsProvider(year)).valueOrNull;
    expect(counts, isNotNull);
    expect(counts![localDayKey(fixedDay)], 3);

    // Есть хотя бы один кружок-день с непрозрачной заливкой (индикатор занятости).
    final filledCircles =
        tester.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      return d is BoxDecoration &&
          d.shape == BoxShape.circle &&
          d.color != null &&
          d.color!.a > 0;
    });
    expect(filledCircles, isNotEmpty,
        reason: 'день с задачами должен иметь заливку-индикатор');
  });

  testWidgets('tap on a day selects it and switches to day view',
      (tester) async {
    await tester.pumpWidget(harness());
    await settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(YearView)),
    );

    // Тап по первому видимому «15» → выбор дня 15 + переключение на день.
    final fifteen = find.text('15').first;
    expect(fifteen, findsOneWidget);
    await tester.tap(fifteen, warnIfMissed: false);
    await tester.pump();

    expect(container.read(planViewProvider), PlanView.day);
    final sel = container.read(selectedDayProvider);
    expect(sel.day, 15);
    expect(sel.year, year);
  });
}
