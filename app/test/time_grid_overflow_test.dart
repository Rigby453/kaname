// Регресс-тест на РЕАЛЬНЫЙ overflow, пойманный на устройстве: короткий блок
// (задача на 10–15 минут, высота ~16px) средней ширины в ДЕНЬ-виде с lane-
// раскладкой пересекающихся блоков переполнял Column на 1px по вертикали
// (RenderFlex overflowed by 1.00 pixels on the bottom, time_grid.dart Column).
//
// Методология как в overflow_audit_*: flutter_test бросает исключение при любом
// RenderFlex overflow во время pump → успешный pump = отсутствие overflow.
// dayItemsProvider оверрайдим напрямую (без DB/стримов), чтобы тест был
// детерминированным и быстрым.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/plan/widgets/day_timeline.dart' show dayItemsProvider;
import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:app/features/plan/widgets/week_strip.dart' show selectedDayProvider;
import 'package:app/core/database/database.dart';

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
        dayItemsProvider.overrideWith(
          (ref, date) => AsyncValue.data(items),
        ),
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
  // Без pumpAndSettle (есть бесконечные/повторяющиеся анимации лифта нет, но
  // авто-скролл-контроллер требует кадра): один pump достаточно для лэйаута.
  await tester.pump();
}

void main() {
  // День начала задач — фиксируем, чтобы scheduledAt попал в выбранный день.
  final day = DateTime(2026, 6, 24);

  testWidgets(
    'короткие пересекающиеся блоки в ДЕНЬ-виде (узкие колонки) не переполняются',
    (tester) async {
      // Два пересекающихся блока по 15 минут → две дорожки → каждая колонка
      // вдвое уже; высота блока мала. Это та геометрия (короткий + средне-узкий
      // блок), что переполняла Column на 1px.
      final items = [
        _item(
          id: 'a',
          title: 'Короткая задача с длинным названием для проверки',
          at: DateTime(2026, 6, 24, 9, 0),
          durationMinutes: 15,
        ),
        _item(
          id: 'b',
          title: 'Вторая пересекающаяся задача тоже с длинным именем',
          at: DateTime(2026, 6, 24, 9, 5),
          durationMinutes: 15,
        ),
      ];

      // Узкая ширина → две дорожки делают блоки совсем тонкими.
      await _pumpDay(tester, items: items, day: day, width: 160, textScale: 1.0);
      // Тот же кейс при крупном тексте (a11y scale 1.5) — самый тесный по высоте.
      await _pumpDay(tester, items: items, day: day, width: 160, textScale: 1.5);
      // Успешный pump = overflow не возник (flutter_test бросил бы иначе).
    },
  );

  testWidgets(
    'очень короткий одиночный блок (15 мин) при крупном тексте не переполняется',
    (tester) async {
      final items = [
        _item(
          id: 'solo',
          title: 'Десятиминутка',
          at: DateTime(2026, 6, 24, 10, 0),
          durationMinutes: 15,
        ),
      ];
      // Маленький hourHeight делает 15-минутный блок предельно низким.
      await _pumpDay(
        tester,
        items: items,
        day: day,
        width: 320,
        textScale: 1.5,
        hourHeight: 40,
      );
    },
  );

  // РЕГРЕСС НА ЖИВОЙ РЕСАЙЗ: на устройстве при перетаскивании ручки блок проходит
  // через переходные высоты, и на отдельных кадрах Column/текст переполнялся
  // (RenderFlex overflowed by 8..0 px) ДО того, как срабатывала деградация
  // контента. Эмулируем серию высот блока от большой к крошечной: для 60-мин
  // задачи durationToHeight(60, hourHeight) == hourHeight, поэтому достаточно
  // прогнать hourHeight по списку — блок принимает ровно эти высоты. На КАЖДОЙ
  // высоте делаем pump; любой overflow на любом кадре уронил бы тест.
  testWidgets(
    'серия высот живого ресайза (60→10px) не даёт overflow ни на одном кадре',
    (tester) async {
      // Длинное название — чтобы заголовок реально претендовал на место и
      // проверял деградацию (titleAndTime → titleOnly → colorOnly).
      final items = [
        _item(
          id: 'resize',
          title: 'Очень длинное название задачи для проверки переполнения',
          at: DateTime(2026, 6, 24, 11, 0),
          durationMinutes: 60,
        ),
      ];

      // Переходные высоты блока, как при живом перетаскивании ручки вниз.
      const heights = <double>[60, 48, 40, 28, 22, 18, 14, 10];
      for (final h in heights) {
        // hourHeight == h ⇒ высота 60-мин блока == h (durationToHeight без клипа,
        // т.к. raw == h; ниже minHeight 24 durationToHeight держит 24, но Positioned
        // в _EventBlock рисует ровно heightPx, а здесь высота берётся из baseHeight
        // = durationToHeight — для h<24 блок остаётся 24px-минимумом по высоте, что
        // тоже валидная переходная геометрия). Узкая ширина усиливает тесноту.
        await _pumpDay(
          tester,
          items: items,
          day: day,
          width: 200,
          textScale: 1.0,
          hourHeight: h,
        );
        // И при крупном системном тексте (a11y 1.5) — самый тесный по высоте.
        await _pumpDay(
          tester,
          items: items,
          day: day,
          width: 200,
          textScale: 1.5,
          hourHeight: h,
        );
      }
      // Дошли сюда без исключения — overflow не возник ни на одной высоте.
    },
  );
}
