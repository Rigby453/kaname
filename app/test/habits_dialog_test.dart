// Виджет-тест диалога добавления привычки (ADR-053, slice 2).
// Проверяет: переключение режимов частоты (daily/weekly_days/weekly_count),
// появление 7 чипов дней недели, степперы target — и главное, что диалог
// (чипы режима + 7 чипов дней) НЕ переполняется на 320px при textScale 1.5.
//
// Методология как в *_overflow_test: flutter_test бросает исключение при любом
// RenderFlex overflow во время pump → отсутствие исключения = нет overflow.
// Диалог открываем через showDialog (корректный layout + скролл AlertDialog),
// он отдаётся публичным тест-хелпером addHabitDialogForTest() — приватный
// _AddHabitDialog не трогаем (инкапсуляция сохранена), БД/провайдеры не нужны.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/habits_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.focusTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => addHabitDialogForTest(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('диалог: смена режимов + дни + степперы без overflow (320px, 1.5x)',
      (tester) async {
    await _openDialog(tester, width: 320, textScale: 1.5);

    // Имя привычки.
    await tester.enterText(find.byType(TextField), 'Спорт');
    await tester.pumpAndSettle();

    // Режим «По дням недели» → появляются 7 чипов дней.
    await _tapText(tester, 'Days of week');
    expect(find.byType(FilterChip), findsNWidgets(7));

    // Тогглим пару дней (включая снятие — минимум один день должен остаться).
    await _tapText(tester, 'Mon');
    await _tapText(tester, 'Tue');

    // Режим «Раз в неделю» → степпер weeklyTarget (+ степпер targetPerDay).
    await _tapText(tester, 'Times a week');
    expect(find.byIcon(Icons.add_circle_outline), findsWidgets);

    // Жмём «+» и «-» у первого степпера.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();

    // Возврат на «Каждый день».
    await _tapText(tester, 'Every day');

    // Главная проверка: ни один pump не выбросил RenderFlex overflow.
    expect(tester.takeException(), isNull);
  });

  testWidgets('диалог на обычной ширине (textScale 1.0) рендерится без ошибок',
      (tester) async {
    await _openDialog(tester, width: 360, textScale: 1.0);
    // Дефолт — режим «Каждый день» выбран и виден.
    expect(find.text('Every day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
