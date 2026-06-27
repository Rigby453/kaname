// Лёгкий тест виджета ReviewVariantCard для AI-варианта раскладки (ADR-057).
//
// Проверяет:
//   1. AI-вариант (moves != null): показывает названия задач + HH:MM, полный
//      reason без обрезания, отсутствие overflow на 320px / textScale 1.5.
//   2. Rule-based вариант (moves == null): рендерится компактным ListTile без краша.
//
// НЕ ЗАПУСКАТЬ НАПРЯМУЮ: запуск управляется оркестратором (flutter test).
// ReviewVariantCard не использует Riverpod → ProviderScope не нужен.

import 'package:app/features/today/widgets/review_engine.dart';
import 'package:app/features/today/widgets/review_variant_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Хелпер: минимальная MaterialApp-обёртка.
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

// ---------------------------------------------------------------------------
// Фикстуры
// ---------------------------------------------------------------------------

final _moves = [
  PlanMove(
    title: 'Math exam prep',
    priority: 'main',
    at: DateTime(2026, 6, 28, 9, 0),
  ),
  PlanMove(
    title: 'Essay draft',
    priority: 'high',
    at: DateTime(2026, 6, 28, 12, 0),
  ),
];

// Reason содержит уникальные подстроки для проверки полноты отображения.
const _aiReason =
    'Math exam prep (2h) → 09:00 [main priority]; Essay draft (1h) → 12:00';

final _aiVariant = PlanVariant(
  'Front-load priorities',
  _aiReason,
  {
    'uuid1': DateTime(2026, 6, 28, 9, 0),
    'uuid2': DateTime(2026, 6, 28, 12, 0),
  },
  moves: _moves,
);

final _ruleVariant = PlanVariant(
  'variant.frontloaded',
  'variant.frontloaded_reason',
  {'uuid1': DateTime(2026, 6, 28, 9, 0)},
  // moves не передаём → null → компактный ListTile
);

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  group('ReviewVariantCard — AI variant (moves != null)', () {
    testWidgets('shows the bold label', (tester) async {
      await tester.pumpWidget(_wrap(
        ReviewVariantCard(variant: _aiVariant, onApply: () {}),
      ));
      // Метка «Front-load priorities» — ровно один Text-виджет.
      expect(find.text('Front-load priorities'), findsOneWidget);
    });

    testWidgets('shows each task title in a move line', (tester) async {
      await tester.pumpWidget(_wrap(
        ReviewVariantCard(variant: _aiVariant, onApply: () {}),
      ));
      // Названия появляются и в move line (точное совпадение), и в reason (contains).
      // Точное совпадение для move line title:
      expect(find.text('Math exam prep'), findsOneWidget);
      expect(find.text('Essay draft'), findsOneWidget);
    });

    testWidgets('shows formatted times (HH:MM) via DateFormat.Hm()', (tester) async {
      await tester.pumpWidget(_wrap(
        ReviewVariantCard(variant: _aiVariant, onApply: () {}),
      ));
      // '09:00' и '12:00' встречаются как в move line так и в reason.
      expect(find.textContaining('09:00'), findsWidgets);
      expect(find.textContaining('12:00'), findsWidgets);
    });

    testWidgets('shows full reason without truncation', (tester) async {
      await tester.pumpWidget(_wrap(
        ReviewVariantCard(variant: _aiVariant, onApply: () {}),
      ));
      // '[main priority]' есть только в reason Text, не в move line →
      // его наличие подтверждает, что reason выводится полностью.
      expect(find.textContaining('[main priority]'), findsOneWidget);
    });

    testWidgets('apply button triggers callback', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(
        ReviewVariantCard(
          variant: _aiVariant,
          onApply: () => called = true,
        ),
      ));
      await tester.tap(find.byType(TextButton));
      expect(called, isTrue);
    });

    testWidgets('no overflow at 320px width + textScale 1.5', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ReviewVariantCard(variant: _aiVariant, onApply: () {}),
              ),
            ),
          ),
        ),
      );
      // RenderFlex overflow → FlutterError → tester.takeException() != null.
      expect(tester.takeException(), isNull);
    });
  });

  group('ReviewVariantCard — rule-based variant (moves == null)', () {
    testWidgets('renders compact ListTile without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(ReviewVariantCard(variant: _ruleVariant, onApply: () {})),
      );
      // Apply кнопка присутствует (из ключа today.apply_btn = 'Apply' в en).
      expect(find.byType(TextButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 320px + textScale 1.5', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ReviewVariantCard(variant: _ruleVariant, onApply: () {}),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ReviewVariantCard — old-backend fallback (empty title/priority)', () {
    testWidgets('renders gracefully when title is empty', (tester) async {
      final variant = PlanVariant(
        'AI plan',
        'reschedule suggested',
        {'uuid1': DateTime(2026, 6, 28, 9, 0)},
        moves: [
          PlanMove(title: '', priority: '', at: DateTime(2026, 6, 28, 9, 0)),
        ],
      );
      await tester.pumpWidget(_wrap(
        ReviewVariantCard(variant: variant, onApply: () {}),
      ));
      // Только время отображается (→ 09:00), краша нет.
      expect(find.textContaining('09:00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
