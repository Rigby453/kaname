// Виджет-тест экрана-превью позы (показывается ПЕРЕД плеером для встроенных
// сессий). Открываем превью тапом по встроенной карточке и проверяем:
//   1) экран позы появляется с названием/описанием позы и кнопкой «Начать»;
//   2) на 320px + textScaleFactor 2.0 нет overflow (takeException == null);
//   3) кнопка «Начать» запускает плеер.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/meditation_custom_providers.dart';
import 'package:app/features/health/meditation_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Без пользовательских сессий — нужны только встроенные.
        customMeditationsProvider
            .overrideWith((ref) => Stream.value(const <CustomMeditation>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MeditationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('тап по встроенной сессии открывает превью позы', (tester) async {
    await _pumpScreen(tester, width: 360, textScale: 1.0);

    await tester.tap(find.text('Body Scan'));
    await tester.pumpAndSettle();

    // Экран позы: название позы + описание + кнопка «Начать».
    expect(find.text('Resting pose'), findsOneWidget);
    expect(find.text('Take this pose'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('кнопка «Начать» запускает плеер', (tester) async {
    await _pumpScreen(tester, width: 360, textScale: 1.0);

    await tester.tap(find.text('Body Scan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pump(); // строим маршрут плеера
    await tester.pump(const Duration(milliseconds: 50));

    // Плеер показывает кнопку завершения сессии (см. meditation_screen.dart).
    expect(find.text('End session'), findsOneWidget);

    // Закрываем плеер через «End session», чтобы dispose отменил таймер/анимацию
    // (иначе остаётся pending Timer.periodic).
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('превью позы без overflow на 320px при textScale 2.0',
      (tester) async {
    await _pumpScreen(tester, width: 320, textScale: 2.0);

    await tester.tap(find.text('Body Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Resting pose'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
