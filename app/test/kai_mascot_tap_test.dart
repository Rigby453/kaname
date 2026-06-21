// Виджет-тесты поведения тапа по KaiMascot.
//
// Контракт (kai_mascot.dart):
//   • тап по Kai успокаивает его к neutral на короткое время, затем
//     возвращает к исходной эмоции (внутренний override поверх widget.emotion);
//   • внешний onTap при этом всё равно вызывается;
//   • при reduce-motion (MediaQuery.disableAnimations) тап только зовёт onTap,
//     без морфинга/джиттера.
//
// Внутреннее состояние эмоции приватно, поэтому проверяем наблюдаемый контракт:
// onTap вызывается, виджет не падает при морфинге neutral→исходная.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/mascot/kai_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Лёгкая тестовая тема: системный шрифт + FocusThemeExtension (без GoogleFonts).
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

Future<void> _pumpKai(
  WidgetTester tester, {
  required KaiEmotion emotion,
  VoidCallback? onTap,
  bool disableAnimations = false,
}) async {
  Widget child = Scaffold(
    body: Center(
      child: KaiMascot(size: 96, emotion: emotion, onTap: onTap),
    ),
  );
  child = MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: child,
  );
  await tester.pumpWidget(MaterialApp(theme: _testTheme(), home: child));
  await tester.pump();
}

void main() {
  group('KaiMascot tap → neutral', () {
    testWidgets('tap still calls external onTap', (tester) async {
      var tapped = 0;
      await _pumpKai(
        tester,
        emotion: KaiEmotion.success,
        onTap: () => tapped++,
      );

      await tester.tap(find.byType(KaiMascot));
      await tester.pump();

      expect(tapped, 1);

      // Сливаем отложенный сброс tap-override (Future.delayed ~1200мс),
      // чтобы он не остался «pending» после dispose дерева.
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('tap on non-neutral emotion settles to neutral without error',
        (tester) async {
      await _pumpKai(tester, emotion: KaiEmotion.success);

      // Тап запускает морфинг к neutral.
      await tester.tap(find.byType(KaiMascot));
      // Проигрываем морфинг (kDurationNormal = 280мс) до конца.
      await tester.pump(const Duration(milliseconds: 300));
      // Проигрываем удержание neutral + возврат к исходной эмоции.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 300));

      // Виджет жив и без исключений в морфинге.
      expect(find.byType(KaiMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce-motion: tap calls onTap and does not throw',
        (tester) async {
      var tapped = 0;
      await _pumpKai(
        tester,
        emotion: KaiEmotion.thinking,
        onTap: () => tapped++,
        disableAnimations: true,
      );

      await tester.tap(find.byType(KaiMascot));
      await tester.pump();

      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
