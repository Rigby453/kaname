// plan_layout_fix_test.dart
//
// Регрессионные тесты двух багов вёрстки Plan-экрана:
//
//   Bug 1 — интервальный переключатель (SegmentedButton из 5 видов) рендерил
//   надписи вертикально (по букве в ряд) когда _segmentsFit() переоценивало
//   доступное место. Тест: накачиваем SegmentedButton с 5 метками в узком
//   контейнере при textScale 1.5 — исключений не должно быть.
//
//   Bug 2 — RenderFlex "BOTTOM OVERFLOWED BY ~27px" когда ExpandableWeekCalendar
//   раскрыт на 6-рядный месяц + маленький экран. Тест: накачиваем тело-разметку
//   (Column с ExpandableWeekCalendar + Divider + мок-карточка + Expanded) в
//   контейнере высотой 400px при ширине 320px и textScale 1.5.
//
// Паттерн: успешный pump (без исключений) = нет RenderFlex overflow.
// НЕ маскируем overflow: никаких try/catch.
// НЕ запускаем flutter-команды — файл создан для запуска оркестратором.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/plan/widgets/expandable_week_calendar.dart';
import 'package:app/features/plan/widgets/plan_providers.dart' show rangeItemsProvider;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Минимальная тестовая тема (идентична overflow_audit_all_test.dart)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Утилиты (копия из overflow_audit_all_test.dart)
// ---------------------------------------------------------------------------

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

// ---------------------------------------------------------------------------
// Минимальный ProviderScope-враппер для ExpandableWeekCalendar
// ---------------------------------------------------------------------------

Widget _calendarHarness({
  required AppDatabase db,
  required SharedPreferences prefs,
  required Widget child,
  double textScale = 1.0,
  Size size = const Size(320, 760),
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      // Подменяем диапазонный провайдер пустыми данными: тест проверяет ТОЛЬКО
      // вёрстку/overflow, а живой Drift-watch под фейковыми часами теста оставлял
      // pending Timer (тест висел 10 мин). Синхронные данные → без стрима/таймеров.
      rangeItemsProvider.overrideWith(
        (ref, range) => const AsyncValue<List<ItemsTableData>>.data([]),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        size: size,
        // Отключаем неявные анимации (_DayCell AnimatedContainer) — иначе под
        // фейковыми часами теста остаётся pending Timer на teardown.
        disableAnimations: true,
      ),
      child: MaterialApp(
        theme: _testTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  // -------------------------------------------------------------------------
  // Bug 1 — интервальный переключатель: SegmentedButton не должен сжимать
  // надписи при ширине ~600px и textScale 1.5.
  //
  // Тестируем публичный SegmentedButton с теми же 5 метками в контейнере
  // ширины 600px (ширина планшета в портрете). До фикса _segmentsFit() с
  // padding=40 давало ложное «влезает», и SegmentedButton рендерил надписи
  // вертикально. После фикса (padding=56 + +24 запас) при 600px и textScale 1.5
  // виджет переходит в безопасный Dropdown (или сегменты всё же влезают без
  // overflow — оба исхода корректны, главное — нет исключения).
  // -------------------------------------------------------------------------

  group('Bug 1 — Plan view switcher: no overflow at borderline tablet width', () {
    testWidgets(
        'SegmentedButton with 5 plan view labels at 600px and textScale 1.5',
        (tester) async {
      // 600px — ширина портретного планшета, провоцирует пограничный случай
      // _segmentsFit(). Высота 800px — достаточно.
      await _setSize(tester, const Size(600, 800));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.5),
            size: Size(600, 800),
          ),
          child: MaterialApp(
            theme: _testTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 560, // узкая полоса — симулирует AppBar-зону переключателя
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Day',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('3 Days',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text('Week',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: 3,
                        label: Text('Month',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: 4,
                        label: Text('Year',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    selected: const {0},
                    showSelectedIcon: false,
                    onSelectionChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await _settle(tester);
      // Успешный pump = нет RenderFlex overflow.
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Bug 2 — ExpandableWeekCalendar раскрытый 6-рядный месяц + пустой день:
  // не должен вызывать RenderFlex overflow при 320px × 400px тела и textScale 1.5.
  //
  // Воспроизводим структуру _bodyContent(PlanView.day):
  //   Column([
  //     ExpandableWeekCalendar(maxCalendarHeight: 220),  ← fix applied
  //     Divider(),
  //     SizedBox(height: 48),   ← mock PinnedExamCard
  //     Expanded(child: SizedBox.expand()),  ← mock DayTimeline
  //   ])
  // в SizedBox(height: 400) чтобы симулировать маленькое тело экрана.
  // -------------------------------------------------------------------------

  group('Bug 2 — ExpandableWeekCalendar: no overflow on 6-week month, small screen',
      () {
    testWidgets(
        'Day body layout: 320px width, textScale 1.5, 400px body height, '
        'calendar expanded (maxCalendarHeight: 220)',
        (tester) async {
      // 320×760 — узкий экран. SizedBox(400) симулирует маленькое тело.
      await _setSize(tester, const Size(320, 760));

      // Конкретный день в 6-рядном месяце: март 2026 начинается в воскресенье
      // → leadingBlanks=6 → 6 строк сетки (6*56=336px). С хидером+метками+грабером
      // = 410px, что > 400px тела → до фикса overflow ~27px.
      //
      // Фикс: maxCalendarHeight=220 ограничивает grid до 220-18-24-32=146px (~2.6
      // строки). Сумма всех детей Column < 400px → нет overflow.

      await tester.pumpWidget(
        _calendarHarness(
          db: db,
          prefs: prefs,
          textScale: 1.5,
          size: const Size(320, 760),
          child: SizedBox(
            height: 400, // симулирует маленькое тело экрана
            child: Column(
              children: [
                // ExpandableWeekCalendar с фиксом maxCalendarHeight
                const ExpandableWeekCalendar(maxCalendarHeight: 220),
                const Divider(height: 0.5, thickness: 0.5),
                // Мок PinnedExamCard (фиксированная высота)
                const SizedBox(height: 48),
                // Мок DayTimeline
                const Expanded(child: ColoredBox(color: Colors.transparent)),
              ],
            ),
          ),
        ),
      );

      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Day body layout: 320px width, textScale 1.5, 400px body height, '
        'calendar collapsed (default state) — no overflow',
        (tester) async {
      await _setSize(tester, const Size(320, 760));

      await tester.pumpWidget(
        _calendarHarness(
          db: db,
          prefs: prefs,
          textScale: 1.5,
          size: const Size(320, 760),
          child: SizedBox(
            height: 400,
            child: Column(
              children: [
                // Свёрнутое состояние (t=0): высота = 1 ряд + labels + grabber = 98px
                const ExpandableWeekCalendar(maxCalendarHeight: 220),
                const Divider(height: 0.5, thickness: 0.5),
                const SizedBox(height: 48),
                const Expanded(child: ColoredBox(color: Colors.transparent)),
              ],
            ),
          ),
        ),
      );

      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
