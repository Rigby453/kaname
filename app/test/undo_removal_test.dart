// undo_removal_test.dart
//
// Регресс-тест для удаления Undo (2026-07, см. docs/decisions.md):
//   1. "removed"-тост (showAppToast(..., variant: AppToastVariant.removed))
//      больше не содержит кнопку Undo.
//   2. SwipeToDelete.confirmMessage показывает блокирующий confirm-диалог
//      ПЕРЕД удалением «дорогого» контента: Cancel отменяет свайп (onDelete
//      не вызывается), Delete подтверждает (onDelete вызывается ровно один
//      раз).
//
// Тема — обычный ThemeData (не AppTheme.build), чтобы избежать асинхронного
// throw google_fonts в headless-тесте (см. premium_upsell_l10n_test.dart).
// Делегаты локализации + supportedLocales нужны, чтобы context.s(...)
// (через Localizations.localeOf(context)) резолвился детерминированно на en,
// а не падал с "locale ... is not supported by all of its localization
// delegates".
//
// НЕ ЗАПУСКАТЬ НАПРЯМУЮ: запуск управляется оркестратором (flutter test).

import 'package:app/core/animations/app_toast.dart';
import 'package:app/core/widgets/swipe_to_delete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Общая обёртка MaterialApp с локализацией (без AppTheme.build).
// ---------------------------------------------------------------------------

Widget _wrap(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    // Без supportedLocales/делегатов MaterialApp может молча откатиться на
    // системную локаль или бросить FlutterError "locale ... is not
    // supported" — см. тот же паттерн в premium_upsell_l10n_test.dart.
    supportedLocales: const [Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: home,
  );
}

// ---------------------------------------------------------------------------
// Хост для теста SwipeToDelete: реалистично убирает элемент из дерева ПОСЛЕ
// onDelete (как это делают реальные экраны — Dismissible требует, чтобы
// dismissed-виджет реально исчез из списка, иначе бросает
// "A dismissed Dismissible widget is still part of the tree").
// ---------------------------------------------------------------------------

class _SwipeHost extends StatefulWidget {
  const _SwipeHost({required this.onDeleted});

  final VoidCallback onDeleted;

  @override
  State<_SwipeHost> createState() => _SwipeHostState();
}

class _SwipeHostState extends State<_SwipeHost> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          if (_visible)
            SwipeToDelete(
              key: const ValueKey('x'),
              confirmMessage: 'Delete this?',
              onDelete: () {
                widget.onDeleted();
                setState(() => _visible = false);
              },
              child: const SizedBox(
                height: 56,
                child: Center(child: Text('row')),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('removed toast shows no Undo button', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showAppToast(
                  context,
                  variant: AppToastVariant.removed,
                  message: 'x',
                ),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump(); // старт entrance-анимации тоста
    await tester.pump(const Duration(milliseconds: 300)); // entrance done (280мс)

    // Тост показывает своё сообщение, но БЕЗ кнопки Undo (убрана 2026-07).
    expect(find.text('Undo'), findsNothing);
    expect(find.textContaining('x'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Прокачиваем таймер автоскрытия тоста (3.5с) + exit-анимацию (220мс),
    // чтобы не оставить pending Timer в конце теста (см. app_toast.dart —
    // _autoTimer, и тот же паттерн двойного pump в interaction_smoke_test.dart
    // для того же _AppToastOverlay).
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'SwipeToDelete confirmMessage: cancel aborts, confirm deletes once',
      (tester) async {
    var deleteCount = 0;

    await tester.pumpWidget(
      _wrap(_SwipeHost(onDeleted: () => deleteCount++)),
    );
    await tester.pump();

    expect(find.text('row'), findsOneWidget);

    // ---- Свайп 1: Cancel → onDelete НЕ вызывается, строка остаётся -------
    await tester.drag(find.text('row'), const Offset(-500, 0));
    await tester.pump(); // DragEnd → confirmDismiss → showDialog
    await tester.pump(const Duration(milliseconds: 300)); // диалог открылся

    expect(find.byType(AlertDialog), findsOneWidget);
    final cancelButton = find.widgetWithText(TextButton, 'Cancel');
    expect(cancelButton, findsOneWidget);

    await tester.tap(cancelButton);
    await tester.pump(); // Navigator.pop
    await tester.pump(const Duration(milliseconds: 300)); // диалог закрылся
    await tester.pump(const Duration(milliseconds: 300)); // Dismissible снапнулся назад

    expect(deleteCount, 0);
    expect(find.text('row'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // ---- Свайп 2: Delete → onDelete вызывается ровно один раз -----------
    await tester.drag(find.text('row'), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    final deleteButton = find.widgetWithText(FilledButton, 'Delete');
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pump(); // Navigator.pop(true) → confirmDismiss resolves
    await tester.pump(const Duration(milliseconds: 300)); // dismiss-анимация
    await tester.pump(const Duration(milliseconds: 300)); // onDismissed → onDelete → setState

    expect(deleteCount, 1);
    expect(find.text('row'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
