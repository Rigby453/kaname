// Виджет-тесты диалога «Своё количество» воды (showCustomWaterDialog).
//
// Регресс (красный экран, «line 6268 pos 12», подозревался как краш при вводе
// произвольного объёма воды) — оказался ДВУМЯ независимыми багами:
//  1. int.parse без tryParse на пользовательском вводе → FormatException.
//  2. Диалог был самодельным AlertDialog с TextEditingController, который
//     диспозился сразу после `await showDialog(...)` — на кадре закрывающей
//     анимации Flutter обращался к уже уничтоженному контроллеру
//     ("A TextEditingController was used after being disposed"), даже при
//     ВАЛИДНОМ вводе (см. комментарий в number_input_dialog.dart — этот же
//     баг уже однажды чинился там).
//
// Фикс: showCustomWaterDialog теперь делегирует на NumberInputDialog —
// общий, уже застрахованный от обоих багов виджет (tryParse + корректный
// жизненный цикл контроллера через State.dispose). Эти тесты — регрессионная
// страховка (в стиле meditation_mood_log_test.dart): пустой/мусорный/
// избыточный ввод не бросает исключение и не сохраняет невалидное значение.
//
// context.s резолвится в en по умолчанию (локаль теста = en) — отдельные
// l10n-делегаты не нужны, S — собственная система переводов приложения.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/health_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Фейковый DAO — фиксирует последний добавленный объём (или null, если
/// addWater ни разу не вызван).
class _FakeWaterDao {
  int? lastAdded;

  Future<void> addWater(int amountMl) async {
    lastAdded = amountMl;
  }
}

Future<void> _pumpDialog(WidgetTester tester, _FakeWaterDao dao) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.focusTheme(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () => showCustomWaterDialog(ctx, dao),
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

void main() {
  testWidgets('пустой ввод + OK → не бросает, не сохраняет (rejected)',
      (tester) async {
    final dao = _FakeWaterDao();
    await _pumpDialog(tester, dao);

    // Поле пустое по умолчанию — сразу жмём OK.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dao.lastAdded, isNull);
  });

  testWidgets(
      'мусорный текстовый ввод ("abc") → отфильтрован digitsOnly, не бросает, не сохраняет',
      (tester) async {
    final dao = _FakeWaterDao();
    await _pumpDialog(tester, dao);

    // digitsOnly input formatter не даёт буквам попасть в поле — итог: пусто.
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dao.lastAdded, isNull);
  });

  testWidgets(
      'ввод со знаками ("--12..3") + onSubmitted (Enter) → знаки отфильтрованы, не бросает',
      (tester) async {
    final dao = _FakeWaterDao();
    await _pumpDialog(tester, dao);

    // digitsOnly оставляет только цифры → "123" (валидное значение).
    await tester.enterText(find.byType(TextField), '--12..3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dao.lastAdded, 123);
  });

  testWidgets(
      'ввод с минусом ("-500") → минус отфильтрован digitsOnly, сохраняется 500',
      (tester) async {
    final dao = _FakeWaterDao();
    await _pumpDialog(tester, dao);

    await tester.enterText(find.byType(TextField), '-500');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dao.lastAdded, 500);
  });

  testWidgets(
      'число выше верхней границы (99999, урезано до 4 цифр) + OK → отвергается',
      (tester) async {
    final dao = _FakeWaterDao();
    await _pumpDialog(tester, dao);

    // maxDigits: 4 обрезает ввод до "9999" (> maxValue 5000) → rejected.
    await tester.enterText(find.byType(TextField), '99999');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dao.lastAdded, isNull);
  });

  testWidgets('валидный ввод (350) + OK → сохраняется без исключений',
      (tester) async {
    final dao = _FakeWaterDao();
    await _pumpDialog(tester, dao);

    await tester.enterText(find.byType(TextField), '350');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(dao.lastAdded, 350);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
