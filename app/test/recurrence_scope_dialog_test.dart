// Виджет-тест диалога выбора области редактирования повторяющейся задачи (B4).
//
// Проверяет:
//   1. Лист рендерит ровно 3 опции без RenderFlex overflow на 320px + textScale 2.0.
//   2. Тап на каждую опцию возвращает правильный RecurrenceEditScope.
//   3. Кнопка «Cancel» возвращает null (не сохранять).
//
// context.s резолвится в en по умолчанию (локаль MaterialApp = en).
// Отдельные l10n-делегаты не нужны — S — собственная система переводов.
//
// Паттерн: открываем лист через showRecurrenceScopeDialog из кнопки Builder;
// результат фиксируем в замыкании. После tap + pumpAndSettle читаем captured.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/plan/widgets/recurrence_scope_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

/// Строит MaterialApp с [width] и [textScale], монтирует кнопку «open».
/// После tap кнопки showRecurrenceScopeDialog открывается и фиксирует результат.
Future<_Holder> _openDialog(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final holder = _Holder();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.focusTheme(),
      // Устанавливаем en вручную — гарантирует резолвинг en-строк в context.s.
      locale: const Locale('en'),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () async {
                holder.result = await showRecurrenceScopeDialog(ctx);
                holder.didComplete = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return holder;
}

/// Контейнер результата (замыкание для фиксации значения после pop).
class _Holder {
  RecurrenceEditScope? result;
  bool didComplete = false;
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'диалог рендерит 3 опции без overflow на 320px + textScale 2.0',
    (tester) async {
      await _openDialog(tester, width: 320, textScale: 2.0);

      // Нет RenderFlex overflow (flutter_test бросает исключение при overflow).
      expect(tester.takeException(), isNull);

      // Все три опции в английском тексте видны (en-строки из today.dart).
      expect(find.text('Only this event'), findsOneWidget);
      expect(find.text('This and following events'), findsOneWidget);
      expect(find.text('All events'), findsOneWidget);
    },
  );

  testWidgets(
    'тап «Only this event» → RecurrenceEditScope.onlyThis',
    (tester) async {
      final holder = await _openDialog(tester, width: 375, textScale: 1.0);

      await tester.tap(find.text('Only this event'));
      await tester.pumpAndSettle();

      expect(holder.didComplete, isTrue);
      expect(holder.result, RecurrenceEditScope.onlyThis);
    },
  );

  testWidgets(
    'тап «This and following events» → RecurrenceEditScope.thisAndFuture',
    (tester) async {
      final holder = await _openDialog(tester, width: 375, textScale: 1.0);

      await tester.tap(find.text('This and following events'));
      await tester.pumpAndSettle();

      expect(holder.didComplete, isTrue);
      expect(holder.result, RecurrenceEditScope.thisAndFuture);
    },
  );

  testWidgets(
    'тап «All events» → RecurrenceEditScope.wholeSeries',
    (tester) async {
      final holder = await _openDialog(tester, width: 375, textScale: 1.0);

      await tester.tap(find.text('All events'));
      await tester.pumpAndSettle();

      expect(holder.didComplete, isTrue);
      expect(holder.result, RecurrenceEditScope.wholeSeries);
    },
  );

  testWidgets(
    'кнопка Cancel → null (не сохранять)',
    (tester) async {
      final holder = await _openDialog(tester, width: 375, textScale: 1.0);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(holder.didComplete, isTrue);
      expect(holder.result, isNull);
    },
  );

  testWidgets(
    'свайп вниз (dismiss) → lист закрывается',
    (tester) async {
      await _openDialog(tester, width: 375, textScale: 1.0);

      // Закрываем лист нажатием на барьер (escape). В тестовой среде нельзя
      // делать жест свайп по Modal — используем Navigator.maybePop.
      await tester.tapAt(const Offset(187, 50)); // область вне листа
      await tester.pumpAndSettle();

      // Лист закрыт — ни одна из опций больше не видна.
      expect(find.text('Only this event'), findsNothing);
    },
  );
}
