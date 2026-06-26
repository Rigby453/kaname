// Виджет-тест DateNavigator.
//
// Проверяет:
// 1. Кнопка «›» (chevron_right) disabled, когда date == сегодня.
// 2. Тап «‹» (chevron_left) вызывает onChanged с предыдущим днём.
//
// flutter_test_config.dart вызывает initializeDateFormatting() перед тестами,
// поэтому DateFormat.yMMMMd() работает без явной локали.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/date_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Оборачивает DateNavigator в минимальное MaterialApp с темой Focus.
Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.focusTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('DateNavigator', () {
    testWidgets(
      'кнопка › disabled когда date == сегодня',
      (tester) async {
        final today = DateTime.now();
        DateTime? received;

        await tester.pumpWidget(
          _wrap(
            DateNavigator(
              date: today,
              onChanged: (d) => received = d,
            ),
          ),
        );

        // chevron_right присутствует в дереве
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);

        // onPressed должен быть null (кнопка disabled при date == сегодня)
        final btn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right),
        );
        expect(btn.onPressed, isNull,
            reason: 'кнопка › не должна быть активна для сегодняшней даты');

        // onChanged ни разу не вызван
        expect(received, isNull);
      },
    );

    testWidgets(
      'кнопка › активна когда date < сегодня',
      (tester) async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        DateTime? received;

        await tester.pumpWidget(
          _wrap(
            DateNavigator(
              date: yesterday,
              onChanged: (d) => received = d,
            ),
          ),
        );

        final btn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right),
        );
        expect(btn.onPressed, isNotNull,
            reason: 'кнопка › должна быть активна для вчерашней даты');

        await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
        await tester.pump();

        // onChanged вызван с today
        expect(received, isNotNull);
        final today = DateTime.now();
        expect(received!.year, today.year);
        expect(received!.month, today.month);
        expect(received!.day, today.day);
      },
    );

    testWidgets(
      'тап ‹ вызывает onChanged с предыдущим днём',
      (tester) async {
        final today = DateTime.now();
        final expected = today.subtract(const Duration(days: 1));
        DateTime? received;

        await tester.pumpWidget(
          _wrap(
            DateNavigator(
              date: today,
              onChanged: (d) => received = d,
            ),
          ),
        );

        // chevron_left всегда активна (нет нижней блокировки в UI)
        await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
        await tester.pump();

        expect(received, isNotNull);
        expect(received!.year, expected.year);
        expect(received!.month, expected.month);
        expect(received!.day, expected.day);
      },
    );
  });
}
