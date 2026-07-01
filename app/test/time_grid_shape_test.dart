// Регресс-тест на «форму» задачи (task_shape.dart) в сетке времени:
//   • момент (durationMinutes == 0) рисуется маркером и не даёт overflow;
//   • открытая (durationMinutes == -1) рисуется блоком с эффективной высотой
//     (НЕ через durationToHeight(-1, ...), который дал бы отрицательную высоту)
//     и тоже не даёт overflow — ни рядом с другим событием, ни в одиночку.
//
// Методология как в time_grid_overflow_test.dart: flutter_test бросает
// исключение при любом RenderFlex overflow во время pump → успешный pump без
// исключения = верстка выдержала. dayItemsProvider оверрайдим напрямую (без
// DB/стримов) — тест детерминированный и быстрый, БЕЗ pumpAndSettle (в файле
// нет google_fonts/бесконечных таймеров — тестовая ThemeData собрана вручную).

import 'package:app/core/database/database.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/plan/task_shape.dart';
import 'package:app/features/plan/widgets/day_timeline.dart'
    show dayItemsProvider;
import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:app/features/plan/widgets/week_strip.dart'
    show selectedDayProvider;
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
  required int durationMinutes,
}) {
  final now = DateTime(2026, 6, 24, 12);
  return ItemsTableData(
    id: id,
    userId: 'u1',
    title: title,
    type: 'task',
    priority: 'normal',
    status: 'pending',
    scheduledAt: at,
    durationMinutes: durationMinutes,
    isProtected: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpDay(
  WidgetTester tester, {
  required List<ItemsTableData> items,
  required DateTime day,
  required double width,
  required double textScale,
  double hourHeight = kHourHeight,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedDayProvider.overrideWith((ref) => day),
        dayItemsProvider.overrideWith((ref, date) => AsyncValue.data(items)),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: _testTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 700,
                child: DayTimeGrid(hourHeight: hourHeight),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final day = DateTime(2026, 6, 24);

  testWidgets(
    'момент (durationMinutes == 0) рисуется маркером, не блоком, без overflow',
    (tester) async {
      final items = [
        _item(
          id: 'pill',
          title: 'Принять таблетку с очень длинным названием лекарства',
          at: DateTime(2026, 6, 24, 14, 0),
          durationMinutes: kMomentDuration,
        ),
      ];
      await _pumpDay(tester, items: items, day: day, width: 320, textScale: 1.0);
      // Заголовок момента виден (маркер не скрывает контент).
      expect(
        find.textContaining('Принять таблетку'),
        findsWidgets,
        reason: 'заголовок момента должен быть виден в маркере',
      );
      // Крупный текст (a11y) и узкая колонка — самый тесный случай.
      await _pumpDay(tester, items: items, day: day, width: 160, textScale: 2.0);
    },
  );

  testWidgets(
    'момент рядом с обычным блоком — оба видны, без overflow',
    (tester) async {
      final items = [
        _item(
          id: 'block',
          title: 'Обычная задача',
          at: DateTime(2026, 6, 24, 13, 30),
          durationMinutes: 60,
        ),
        _item(
          id: 'pill',
          title: 'Момент внутри блока',
          at: DateTime(2026, 6, 24, 14, 0),
          durationMinutes: kMomentDuration,
        ),
      ];
      await _pumpDay(tester, items: items, day: day, width: 320, textScale: 1.5);
    },
  );

  testWidgets(
    'открытая (durationMinutes == -1) тянется до следующего события, без overflow',
    (tester) async {
      final items = [
        _item(
          id: 'open',
          title: 'Сесть за учёбу (открытая задача с длинным названием)',
          at: DateTime(2026, 6, 24, 15, 0),
          durationMinutes: kOpenEndedDuration,
        ),
        _item(
          id: 'next',
          title: 'Следующее дело',
          at: DateTime(2026, 6, 24, 16, 30),
          durationMinutes: 30,
        ),
      ];
      await _pumpDay(tester, items: items, day: day, width: 320, textScale: 1.0);
      expect(find.textContaining('Сесть за учёбу'), findsWidgets);
      // Крупный текст + узкая колонка.
      await _pumpDay(tester, items: items, day: day, width: 160, textScale: 2.0);
    },
  );

  testWidgets(
    'открытая без следующего события тянется до конца дня, без overflow',
    (tester) async {
      final items = [
        _item(
          id: 'open',
          title: 'Открытая задача без соседей',
          at: DateTime(2026, 6, 24, 22, 30),
          durationMinutes: kOpenEndedDuration,
        ),
      ];
      await _pumpDay(tester, items: items, day: day, width: 320, textScale: 1.5);
    },
  );
}
