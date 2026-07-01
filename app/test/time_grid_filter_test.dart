// Регресс-тест: фильтр Плана (текстовый planSearchQueryProvider + панель
// приоритет/статус/тип planFiltersProvider) должен работать в БЛОЧНОМ
// (сеточном) виде — не только в списке (day_timeline.dart). До фикса
// DayTimeGrid/_NDayTimeGrid (WeekTimeGrid/ThreeDayTimeGrid) применяли только
// текстовый фильтр (planSearchMatches) и игнорировали панель приоритет/
// статус/тип (planFilterMatches) — см. time_grid.dart.
//
// dayItemsProvider/rangeItemsProvider оверрайдим напрямую (без DB/стримов),
// как в остальных тестах time_grid_*_test.dart — детерминированно и быстро.

import 'package:app/core/database/database.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/plan/widgets/day_timeline.dart' show dayItemsProvider;
import 'package:app/features/plan/widgets/plan_providers.dart';
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

ItemsTableData _item({
  required String id,
  required String title,
  required DateTime at,
  String priority = 'medium',
  int durationMinutes = 60,
}) {
  final now = DateTime(2026, 6, 24, 12);
  return ItemsTableData(
    id: id,
    userId: 'u1',
    title: title,
    type: 'task',
    priority: priority,
    status: 'pending',
    scheduledAt: at,
    durationMinutes: durationMinutes,
    isProtected: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpDayGrid(
  WidgetTester tester, {
  required List<ItemsTableData> items,
  required DateTime day,
  String searchQuery = '',
  PlanFilters filters = const PlanFilters(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedDayProvider.overrideWith((ref) => day),
        dayItemsProvider.overrideWith(
          (ref, date) => AsyncValue.data(items),
        ),
        planSearchQueryProvider.overrideWith((ref) => searchQuery),
        planFiltersProvider.overrideWith((ref) => filters),
      ],
      child: MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 700,
            child: DayTimeGrid(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // День начала задач — фиксируем, чтобы scheduledAt попал в выбранный день.
  final day = DateTime(2026, 6, 24);

  // Два непересекающихся блока (разные часы) — каждый получает полную ширину
  // колонки (laneCount 1), поэтому заголовок рендерится целиком.
  List<ItemsTableData> twoTasks() => [
        _item(
          id: 'a',
          title: 'Купить молоко',
          at: DateTime(2026, 6, 24, 9, 0),
        ),
        _item(
          id: 'b',
          title: 'Позвонить врачу',
          at: DateTime(2026, 6, 24, 14, 0),
        ),
      ];

  testWidgets(
    'без фильтра в блочном виде видны оба блока',
    (tester) async {
      await _pumpDayGrid(tester, items: twoTasks(), day: day);

      expect(find.text('Купить молоко'), findsOneWidget);
      expect(find.text('Позвонить врачу'), findsOneWidget);
    },
  );

  testWidgets(
    'текстовый фильтр (planSearchQueryProvider) в блочном виде оставляет '
    'только совпавший блок',
    (tester) async {
      await _pumpDayGrid(
        tester,
        items: twoTasks(),
        day: day,
        searchQuery: 'молоко',
      );

      expect(find.text('Купить молоко'), findsOneWidget,
          reason: 'совпавшая по тексту задача остаётся в сетке');
      expect(find.text('Позвонить врачу'), findsNothing,
          reason: 'несовпавшая задача скрыта фильтром в сеточном виде');
    },
  );

  testWidgets(
    'фильтр-панель приоритета (planFiltersProvider) в блочном виде оставляет '
    'только совпавший блок (регресс: раньше применялась только в списке)',
    (tester) async {
      final items = [
        _item(
          id: 'main',
          title: 'Главная задача дня',
          at: DateTime(2026, 6, 24, 9, 0),
          priority: 'main',
        ),
        _item(
          id: 'low',
          title: 'Мелкая задача',
          at: DateTime(2026, 6, 24, 14, 0),
          priority: 'low',
        ),
      ];

      await _pumpDayGrid(
        tester,
        items: items,
        day: day,
        filters: const PlanFilters(priorities: {'main'}),
      );

      expect(find.text('Главная задача дня'), findsOneWidget,
          reason: 'задача с priority=main проходит активный фильтр');
      expect(find.text('Мелкая задача'), findsNothing,
          reason: 'задача с priority=low отфильтрована панелью в сетке');
    },
  );
}
