// Регрессия для bug #23: речевая плашка Kai уходила за край экрана.
//
// Корень (см. kai_mascot.dart): плавающий пузырь лежит в
// Positioned(left:0, right:0) над footprint-боксом Kai — это даёт ТУГУЮ
// ширину = ширине бокса (обычно 22-96px), поэтому без OverflowBox текст
// сжимался в узкую колонку и улетал вертикально далеко за экран. Плюс,
// когда Kai стоит у самого края экрана, центрирование пузыря над маленьким
// боксом толкает его половину за физический край — чинится сдвигом внутрь
// экрана (_updateBubbleShift).
//
// Тесты ниже пампят виджеты на ширине 320px и с textScaleFactor 2.0 —
// gate из app/CLAUDE.md §B.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/mascot/kai_mascot.dart';
import 'package:app/features/mascot/kai_speech_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

const _kLongMessage =
    'This is a deliberately very long Kai speech bubble message used to '
    'stress-test wrapping and overflow behaviour on a narrow 320px screen '
    'with a doubled text scale factor.';

/// Пампит [KaiMascot] на экране шириной [screenWidth], тапает по нему (чтобы
/// показать внутренний речевой пузырь с репликой), с маскотом, выровненным
/// по [mascotAlign] (у края экрана), и с заданным textScaleFactor.
Future<void> _pumpAndTapMascot(
  WidgetTester tester, {
  required Alignment mascotAlign,
  double textScale = 2.0,
  double screenWidth = 320,
  double mascotSize = 48,
}) async {
  await tester.binding.setSurfaceSize(Size(screenWidth, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Widget child = Align(
    alignment: mascotAlign,
    child: KaiMascot(size: mascotSize),
  );
  child = MediaQuery(
    data: MediaQueryData(
      size: Size(screenWidth, 640),
      textScaler: TextScaler.linear(textScale),
    ),
    child: child,
  );
  await tester.pumpWidget(
    MaterialApp(theme: _testTheme(), home: Scaffold(body: child)),
  );
  await tester.pump();

  await tester.tap(find.byType(KaiMascot));
  await tester.pump();
  // Второй кадр — после postFrameCallback пересчёта горизонтального сдвига.
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('KaiSpeechBubble — overflow safety (bug #23)', () {
    testWidgets(
        'long message at 320px width + textScale 2.0 does not overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final child = MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2.0),
        ),
        child: Center(
          child: KaiSpeechBubble(message: _kLongMessage, maxWidth: 240),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(theme: _testTheme(), home: Scaffold(body: child)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(KaiSpeechBubble), findsOneWidget);

      // Примечание: widget.maxWidth ограничивает ширину ТЕКСТА внутри
      // Padding(12 слева + 12 справа) — итоговая ширина пузыря = maxWidth +
      // 24 (см. kai_speech_bubble.dart). Проверяем именно контракт "не шире
      // экрана", а не точное совпадение с maxWidth.
      final size = tester.getSize(find.byType(KaiSpeechBubble));
      expect(size.width, lessThanOrEqualTo(240.0 + 24.0 + 0.5));
      expect(size.width, lessThanOrEqualTo(320.0));
    });
  });

  group('KaiMascot floating bubble — stays on screen (bug #23)', () {
    testWidgets(
        'mascot pinned to the RIGHT edge, 320px + scale 2.0: bubble stays '
        'within screen bounds, no exception',
        (tester) async {
      await _pumpAndTapMascot(tester, mascotAlign: Alignment.topRight);

      expect(tester.takeException(), isNull);

      final bubbleFinder = find.byType(KaiSpeechBubble);
      expect(bubbleFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(bubbleFinder);
      final topRight = tester.getTopRight(bubbleFinder);
      // Небольшой допуск на субпиксельные округления layout.
      expect(topLeft.dx, greaterThanOrEqualTo(-0.5));
      expect(topRight.dx, lessThanOrEqualTo(320.5));

      // Сливаем таймеры (авто-скрытие пузыря + tap-neutral hold), чтобы тест
      // не оставлял pending timers после dispose дерева.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
        'mascot pinned to the LEFT edge, 320px + scale 2.0: bubble stays '
        'within screen bounds, no exception',
        (tester) async {
      await _pumpAndTapMascot(tester, mascotAlign: Alignment.topLeft);

      expect(tester.takeException(), isNull);

      final bubbleFinder = find.byType(KaiSpeechBubble);
      expect(bubbleFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(bubbleFinder);
      final topRight = tester.getTopRight(bubbleFinder);
      expect(topLeft.dx, greaterThanOrEqualTo(-0.5));
      expect(topRight.dx, lessThanOrEqualTo(320.5));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
        'small mascot (22dp, as in Today review row) at screen edge does '
        'not overflow at 320px + scale 2.0',
        (tester) async {
      await _pumpAndTapMascot(
        tester,
        mascotAlign: Alignment.topRight,
        mascotSize: 22,
      );

      expect(tester.takeException(), isNull);

      final bubbleFinder = find.byType(KaiSpeechBubble);
      expect(bubbleFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(bubbleFinder);
      final topRight = tester.getTopRight(bubbleFinder);
      expect(topLeft.dx, greaterThanOrEqualTo(-0.5));
      expect(topRight.dx, lessThanOrEqualTo(320.5));

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
