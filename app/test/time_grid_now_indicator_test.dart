// B1 — линия текущего времени («now» indicator) в сетке Day-вида.
// Проверяем ТОЛЬКО начальный рендер (без ожидания минутного Timer.periodic):
//   • в колонке СЕГОДНЯШНЕГО дня индикатор рендерится;
//   • в колонке ДРУГОГО дня (не сегодня) — НЕ рендерится;
//   • размонтирование не оставляет pending-таймера (минутный таймер отменяется
//     в dispose; снимаем дерево через pump(SizedBox)).
//
// dayItemsProvider оверрайдим напрямую (без DB/стримов) — детерминированно и
// быстро. _NowIndicator приватен, поэтому ищем его по имени runtimeType.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/plan/widgets/day_timeline.dart' show dayItemsProvider;
import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:app/features/plan/widgets/week_strip.dart' show selectedDayProvider;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

// Находит приватный _NowIndicator по имени типа (тип не экспортируется).
final _nowIndicator =
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_NowIndicator');

Future<void> _pumpDay(
  WidgetTester tester, {
  required DateTime day,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedDayProvider.overrideWith((ref) => day),
        // Пустой список задач — индикатор не зависит от блоков.
        dayItemsProvider.overrideWith((ref, date) => const AsyncValue.data([])),
      ],
      child: MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: DayTimeGrid(hourHeight: kHourHeight),
          ),
        ),
      ),
    ),
  );
  // Один кадр — лэйаут + авто-скролл-контроллер. Минутный таймер НЕ ждём.
  await tester.pump();
}

// Снимаем дерево, чтобы _NowIndicator.dispose отменил минутный таймер, и
// дренируем нулевой Timer закрытия riverpod-стрима. Без этого тест падает на
// инварианте «A Timer is still pending even after the widget tree was disposed».
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets(
    'now-индикатор рендерится в колонке СЕГОДНЯШНЕГО дня',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await _pumpDay(tester, day: today);

      expect(_nowIndicator, findsOneWidget,
          reason: 'линия текущего времени видна в колонке today');

      await _unmount(tester);
    },
  );

  testWidgets(
    'now-индикатор НЕ рендерится в колонке другого (не сегодня) дня',
    (tester) async {
      final now = DateTime.now();
      // Заведомо не сегодня (вчера).
      final other = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));

      await _pumpDay(tester, day: other);

      expect(_nowIndicator, findsNothing,
          reason: 'линия текущего времени не показывается в чужой день');

      await _unmount(tester);
    },
  );

  testWidgets(
    'размонтирование now-индикатора не оставляет pending-таймера',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await _pumpDay(tester, day: today);
      expect(_nowIndicator, findsOneWidget);

      // Снимаем дерево: если минутный Timer не отменён в dispose — тест упадёт
      // на инварианте pending-Timer при завершении.
      await _unmount(tester);
    },
  );
}
