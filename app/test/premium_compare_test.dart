// Тест виджета таблицы сравнения Free vs Premium.
//
// Проверяет:
//   1. ComparePlansTable рендерится без overflow / исключений (320×800 dp)
//   2. ComparePlansTable рендерится без overflow / исключений (400×800 dp)
//   3. Для AI-строк (premium-only) в Free-колонке присутствуют иконки lock — ровно 6
//   4. Для free-строк в обоих колонках присутствуют иконки check — 22 free + 6 premium = 28
//   5. ComparePlansSheet рендерится с заголовком «Compare plans» (en-локаль)
//   6. PremiumLockBadge рендерится без ошибок и содержит иконку lock

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/premium_lock_badge.dart';
import 'package:app/features/paywall/compare_plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — системный шрифт + FocusThemeExtension
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Вспомогательная функция пампа ComparePlansTable
// ---------------------------------------------------------------------------

Future<void> _pumpTable(
  WidgetTester tester, {
  double width = 400,
  double height = 800,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: _testTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ComparePlansTable(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  // 1. Рендер на нормальной ширине
  testWidgets('ComparePlansTable renders without errors at 400×800 dp',
      (tester) async {
    await _pumpTable(tester);
    expect(tester.takeException(), isNull);
  });

  // 2. Рендер на узком экране (ширина 320 px — антирегрессия overflow)
  testWidgets('ComparePlansTable renders without overflow at 320×800 dp',
      (tester) async {
    await _pumpTable(tester, width: 320);
    // Проверяем отсутствие ошибки рендера — RenderFlex overflow выбросит
    // FlutterError, который tester подхватит
    expect(tester.takeException(), isNull);
  });

  // 3. Lock-иконки у AI (premium-only) строк
  testWidgets('ComparePlansTable shows lock icons for 6 premium-only AI rows',
      (tester) async {
    await _pumpTable(tester);

    // Ищем иконки lock(fill) — по одной на каждую из 6 AI-строк (Free-колонка)
    final lockIcon = PhosphorIcons.lock(PhosphorIconsStyle.fill);
    final lockFinder = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == lockIcon,
    );
    expect(lockFinder, findsNWidgets(6));
  });

  // 4. Check-иконки у free-строк
  testWidgets(
      'ComparePlansTable shows check icons for free rows (both cols) + premium col',
      (tester) async {
    await _pumpTable(tester);

    // • 6 Productivity строки × 2 (Free + Premium col) = 12
    // • 5 Wellbeing строки × 2 (Free + Premium col)   = 10
    // • 6 AI строки × 1 (только Premium col)           =  6
    // Итого check(fill): 28
    final checkIcon = PhosphorIcons.check(PhosphorIconsStyle.fill);
    final checkFinder = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == checkIcon,
    );
    expect(checkFinder, findsNWidgets(28));
  });

  // 5. ComparePlansSheet содержит заголовок
  testWidgets('ComparePlansSheet renders with title and close button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: Scaffold(body: const ComparePlansSheet()),
      ),
    );
    await tester.pump();

    // Заголовок «Compare plans» (en-локаль)
    expect(find.text('Compare plans'), findsOneWidget);
    // Кнопка закрытия ✕
    final closeIcon = PhosphorIcons.x();
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == closeIcon),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // 6. PremiumLockBadge рендерится с иконкой lock
  testWidgets('PremiumLockBadge renders lock icon and label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: const Scaffold(
          body: Center(child: PremiumLockBadge()),
        ),
      ),
    );
    await tester.pump();

    final lockIcon = PhosphorIcons.lock(PhosphorIconsStyle.fill);
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == lockIcon),
      findsOneWidget,
    );
    // Текст «Premium» (из l10n)
    expect(find.text('Premium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 7. PremiumLockBadge без метки — только иконка
  testWidgets('PremiumLockBadge(showLabel: false) renders only lock icon',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        home: const Scaffold(
          body: Center(child: PremiumLockBadge(showLabel: false)),
        ),
      ),
    );
    await tester.pump();

    final lockIcon = PhosphorIcons.lock(PhosphorIconsStyle.fill);
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == lockIcon),
      findsOneWidget,
    );
    expect(find.text('Premium'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
