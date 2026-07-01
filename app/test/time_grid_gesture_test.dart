// Жесты блока сетки времени (time_grid.dart), проверенные на реальном
// in-memory Drift + настоящем DayTimeGrid:
//   • drag по ТЕЛУ блока стартует перенос С ПЕРВОГО касания (без tap/long-press)
//     и меняет scheduledAt;
//   • нижняя ручка (ЕДИНСТВЕННАЯ — верхняя убрана по решению владельца
//     продукта) меняет длительность (конец), включая на коротких блоках, и
//     срабатывает СРАЗУ и мышью, и пальцем, без предварительного выбора блока.
//
// Жесты драйвим через tester.startGesture + moveBy + up (точный pan по координате
// внутри тела/ручки). DAO-результат читаем через runAsync после settle, как в
// interaction_smoke_test.dart.

import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/plan/recurrence.dart'
    show RecurrenceRule, RecurFreq;
import 'package:app/features/plan/widgets/recurrence_providers.dart'
    show virtualDateKey;
import 'package:app/features/plan/widgets/task_detail_card.dart'
    show TaskDetailCard;
import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:app/features/plan/widgets/week_strip.dart'
    show selectedDayProvider;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Зеркалит _kBlockPickupDelay из time_grid.dart (та константа приватна).
// Если меняешь порог подхвата в виджете — обнови и здесь.
const _kBlockPickupDelay = Duration(milliseconds: 120);

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

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  // Высота часа фиксируем — расчёты пикселей детерминированы.
  const hourHeight = kHourHeight; // 56.0
  // День задач — фиксированная дата, чтобы selectedDay совпал.
  final day = DateTime(2026, 6, 24);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTask({
    required String id,
    required int hour,
    required int minute,
    required int durationMinutes,
  }) async {
    final at = DateTime(day.year, day.month, day.day, hour, minute);
    await db.into(db.itemsTable).insert(
          ItemsTableCompanion(
            id: Value(id),
            userId: const Value('local'),
            title: const Value('Тестовая задача'),
            type: const Value('task'),
            priority: const Value('medium'),
            status: const Value('pending'),
            scheduledAt: Value(at),
            durationMinutes: Value(durationMinutes),
            isProtected: const Value(false),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
  }

  Future<ItemsTableData> readTask(String id) async {
    return (db.select(db.itemsTable)..where((t) => t.id.equals(id))).getSingle();
  }

  // Вставляет якорь повторяющейся серии (recurrenceRule != null) на день [day]
  // в [hour]:[minute] — для тестов B4 (диалог выбора области при drag).
  Future<void> insertSeriesAnchor({
    required String id,
    required int hour,
    required int minute,
    required int durationMinutes,
    String rule = 'FREQ=DAILY',
  }) async {
    final at = DateTime(day.year, day.month, day.day, hour, minute);
    await db.into(db.itemsTable).insert(
          ItemsTableCompanion(
            id: Value(id),
            userId: const Value('local'),
            title: const Value('Recurring task'),
            type: const Value('task'),
            priority: const Value('medium'),
            status: const Value('pending'),
            scheduledAt: Value(at),
            durationMinutes: Value(durationMinutes),
            isProtected: const Value(false),
            recurrenceRule: Value(rule),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
  }

  Widget harness() => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          selectedDayProvider.overrideWith((ref) => day),
        ],
        child: MaterialApp(
          theme: _testTheme(),
          // Локаль фиксируем en — детерминированные строки диалога выбора
          // области (showRecurrenceScopeDialog) для B4-тестов ниже.
          locale: const Locale('en'),
          // disableAnimations: лифт-анимация блока (AnimatedScale 1.0↔1.03) через
          // effectiveDuration становится мгновенной (Duration.zero) — без неё в
          // тесте оставался pending Timer при dispose. Жесты (tap/long-press/
          // drag/resize) от этого не меняются, проверяется логика переноса.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 700,
              child: DayTimeGrid(hourHeight: hourHeight),
            ),
          ),
        ),
      );

  // Снимаем дерево и даём дренировать таймер закрытия Drift-стрима, который
  // riverpod создаёт при dispose StreamProvider (zero-duration Timer в
  // StreamQueryStore.markAsClosed). Без этого тест падает на инварианте
  // «A Timer is still pending even after the widget tree was disposed».
  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpGrid(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    // Даём стриму БД доставить задачи (как settle в interaction-тестах).
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'long-press по телу блока поднимает его и перенос в том же касании меняет '
    'scheduledAt; короткий tap НЕ двигает',
    (tester) async {
      // Задача 09:00–12:00 (180 мин) — высокий блок (168px), большое тело между
      // ручками, чтобы хват точно попал в зону переноса, а не в ручку resize.
      await insertTask(id: 'move', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final before = await readTask('move');
      expect(before.scheduledAt.hour, 9);

      // Берёмся за середину тела (далеко от верхней/нижней ручек по ключу блока).
      final blockBox = tester.getRect(find.byKey(const ValueKey('move')));
      final grabCenter = blockBox.center;

      // 1) Опускаем палец и ждём порог long-press подхвата (_kBlockPickupDelay
      //    на фейковом клоке) — блок «поднимается» (onLongPressStart). Затем
      //    В ТОМ ЖЕ касании ведём вниз на 1 час фиксированными шагами и
      //    отпускаем. Никакого pumpAndSettle с бесконечной анимацией лифта —
      //    только фикс-шаги.
      final gesture = await tester.startGesture(grabCenter);
      await tester.pump(_kBlockPickupDelay + const Duration(milliseconds: 50));
      // Перенос на +1 час несколькими шагами (onLongPressMoveUpdate).
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, hourHeight / 4));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      // Скролл НЕ должен был сдвинуться — long-press выиграл арену у скролла.
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
      expect(scrollable.controller?.offset, kHourHeight * 7,
          reason: 'страница не проскроллилась — long-press взял блок');

      final after = await readTask('move');
      // Перенос на +60 минут → 10:00 (снап к 15 мин не сдвигает ровный час).
      expect(after.scheduledAt.hour, 10, reason: 'блок переехал на час вниз');
      expect(after.scheduledAt.minute, 0);
      // Длительность не тронута переносом.
      expect(after.durationMinutes, 180);

      // Дренируем 800мс подстраховочный Future.delayed из _commitMove — иначе
      // «A Timer is still pending» на teardown (см. комментарий у него в
      // time_grid.dart).
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'короткий tap по телу блока НЕ переносит (открывает карточку), время не меняется',
    (tester) async {
      await insertTask(id: 'tap', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final blockBox = tester.getRect(find.byKey(const ValueKey('tap')));
      // Короткий тап по центру тела — без удержания и без движения.
      await tester.tapAt(blockBox.center);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('tap');
      // Тап только открывает карточку — время задачи не сдвинулось.
      expect(after.scheduledAt.hour, 9, reason: 'tap не переносит блок');
      expect(after.scheduledAt.minute, 0);
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'нижняя ручка мышью меняет длительность СРАЗУ, без предварительного '
    'выбора/клика по блоку',
    (tester) async {
      // Задача 09:00–11:00 (120 мин, 112px) — обычный блок. Тянем нижнюю ручку
      // ВНИЗ мышью В ПЕРВОМ касании (без предшествующего тапа/выбора) — длина
      // должна вырасти сразу.
      await insertTask(id: 'bottom-mouse', hour: 9, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      final before = await readTask('bottom-mouse');
      expect(before.durationMinutes, 120);

      final blockBox = tester.getRect(find.byKey(const ValueKey('bottom-mouse')));
      // Нижняя ручка занимает последние ~22px блока — целимся в её центр.
      final grabBottom = Offset(blockBox.center.dx, blockBox.bottom - 11);

      final gesture = await tester.startGesture(
        grabBottom,
        kind: PointerDeviceKind.mouse,
      );
      // Никакого предварительного тапа/паузы — сразу тянем вниз на час.
      await gesture.moveBy(const Offset(0, hourHeight));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('bottom-mouse');
      expect(after.durationMinutes, 180,
          reason:
              'мышиный ресайз нижней ручкой сработал с первого касания (+1ч)');
      // Начало НЕ изменилось — верхней ручки больше нет, тянет только низ.
      expect(after.scheduledAt.hour, 9);
      expect(after.scheduledAt.minute, 0);

      // Дренируем 800мс подстраховочный Future.delayed из _commitResize.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'верхней ручки больше нет: перенос за верхний край блока двигает блок '
    '(тело), а не меняет начало',
    (tester) async {
      // Раньше верхние ~22px были ручкой resize-начала. Теперь там тело блока —
      // долгое нажатие там должно ПЕРЕНОСИТЬ блок, а не резать длительность.
      await insertTask(id: 'no-top', hour: 9, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      final blockBox = tester.getRect(find.byKey(const ValueKey('no-top')));
      final grabTop = Offset(blockBox.center.dx, blockBox.top + 5);

      final gesture = await tester.startGesture(grabTop);
      await tester.pump(_kBlockPickupDelay + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, hourHeight));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('no-top');
      // Длительность НЕ изменилась (перенос, не ресайз), время сдвинулось.
      expect(after.durationMinutes, 120,
          reason: 'верхний край теперь тело — перенос, длительность цела');
      expect(after.scheduledAt.hour, 10, reason: 'блок переехал на час вниз');

      // Дренируем 800мс подстраховочный Future.delayed из _commitMove.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await unmountAndFlush(tester);
    },
  );

  // Считает зоны хвата ручек ресайза ВНУТРИ блока [id]. Каждая зона обёрнута в
  // MouseRegion с курсором resizeUpDown (курсор ресайза на вебе/десктопе) — по
  // этому маркеру их и находим, не завися от приватных типов распознавателей.
  int resizeHandleCount(WidgetTester tester, String id) {
    final handles = find.descendant(
      of: find.byKey(ValueKey(id)),
      matching: find.byWidgetPredicate(
        (w) => w is MouseRegion &&
            w.cursor == SystemMouseCursors.resizeUpDown,
      ),
    );
    return handles.evaluate().length;
  }

  testWidgets(
    'И маленький, и большой блок — РОВНО одна (нижняя) ручка ресайза; '
    'верхней больше нет ни у кого',
    (tester) async {
      // Маленький блок: 45 мин = 42px. Большой: 120 мин = 112px. Раньше у
      // большого было 2 ручки (верх+низ) — теперь верхняя убрана совсем, у
      // ОБОИХ ровно одна (нижняя), независимо от высоты.
      await insertTask(id: 'small', hour: 8, minute: 0, durationMinutes: 45);
      await insertTask(id: 'big', hour: 12, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      expect(resizeHandleCount(tester, 'small'), 1,
          reason: 'маленький блок: одна нижняя ручка');
      expect(resizeHandleCount(tester, 'big'), 1,
          reason: 'большой блок: тоже одна ручка — верхней больше нет');

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'мышиный drag по блоку двигает его СРАЗУ, без порога удержания, и меняет '
    'scheduledAt',
    (tester) async {
      // Мышь/трекпад/стилус подхватывают блок по PanGestureRecognizer СРАЗУ по
      // нажатию-и-протягиванию — без _kBlockPickupDelay (та задержка действует
      // только на тач-путь через LongPressGestureRecognizer).
      //
      // PanGestureRecognizer «съедает» стартовый slop (kPanSlop ≈ 36px) как
      // порог отличения клика от драга — это штатное поведение Flutter
      // (DragStartBehavior.start): первые ~36px движения не долетают до
      // onUpdate, зато 1:1-трекинг начинается СРАЗУ по их исчерпанию — этим и
      // достигается «мгновенный подхват» (без задержки по ВРЕМЕНИ). Поэтому
      // тянем заведомо больше одного часа и проверяем НАПРАВЛЕНИЕ/факт сдвига,
      // а не точную снэпнутую минуту (та зависит от точного slop, что делает
      // тест хрупким без выгоды).
      await insertTask(
          id: 'mouse-move', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final before = await readTask('mouse-move');
      final blockBox = tester.getRect(find.byKey(const ValueKey('mouse-move')));
      final grabCenter = blockBox.center;

      final gesture = await tester.startGesture(
        grabCenter,
        kind: PointerDeviceKind.mouse,
      );
      // Никакого ожидания порога подхвата — pan мыши забирает арену по первому
      // смещению (slop), а не по времени удержания. Тянем на 3 часа суммарно
      // (168px) несколькими шагами — с запасом покрывает съеденный slop.
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, hourHeight / 2));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('mouse-move');
      expect(
        after.scheduledAt.difference(before.scheduledAt).inMinutes,
        greaterThanOrEqualTo(60),
        reason:
            'мышиный drag без удержания сдвинул блок минимум на час вниз',
      );
      expect(after.durationMinutes, 180);

      // Дренируем 800мс подстраховочный Future.delayed из _commitMove.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'мышиный клик по блоку БЕЗ движения открывает карточку-деталь, '
    'scheduledAt не меняется',
    (tester) async {
      // Клик мышью без смещения не должен «украсть» арену у TapGestureRecognizer:
      // PanGestureRecognizer заявляет победу только по порогу движения (slop).
      await insertTask(
          id: 'mouse-click', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final blockBox =
          tester.getRect(find.byKey(const ValueKey('mouse-click')));

      final gesture = await tester.startGesture(
        blockBox.center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TaskDetailCard), findsOneWidget,
          reason: 'клик мышью без движения открывает карточку-деталь');

      final after = await readTask('mouse-click');
      expect(after.scheduledAt.hour, 9,
          reason: 'клик без движения не переносит блок');
      expect(after.scheduledAt.minute, 0);
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'тач-свайп по блоку БЕЗ удержания (быстрее _kBlockPickupDelay) НЕ двигает '
    'блок — уходит скроллу',
    (tester) async {
      // Движение начинается раньше, чем истекает порог удержания (120 мс) —
      // long-press не успевает выиграть арену у родительского скролла.
      await insertTask(
          id: 'fast-swipe', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final blockBox =
          tester.getRect(find.byKey(const ValueKey('fast-swipe')));
      final grabCenter = blockBox.center;

      final gesture = await tester.startGesture(grabCenter);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('fast-swipe');
      expect(after.scheduledAt.hour, 9,
          reason:
              'быстрый свайп без удержания не переносит блок (уходит скроллу)');
      expect(after.scheduledAt.minute, 0);
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'ОЧЕНЬ короткий блок (15 мин, 24px, реальный пол высоты) — ручка ЕСТЬ '
    'и её можно схватить',
    (tester) async {
      // 15 мин → durationToHeight зажимает до 24px — это реальный минимум
      // высоты блока в приложении. Правка владельца продукта: раньше ручек не
      // было совсем; теперь ручка показывается ВСЕГДА (bottomHandleHeight
      // адаптирует её размер, но не убирает).
      await insertTask(id: 'tiny', hour: 8, minute: 0, durationMinutes: 15);
      await pumpGrid(tester);

      expect(resizeHandleCount(tester, 'tiny'), 1,
          reason: 'даже самый короткий блок имеет ручку ресайза');

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'ОЧЕНЬ короткий блок — нижнюю ручку можно потянуть и увеличить длительность '
    '(тач-путь)',
    (tester) async {
      await insertTask(id: 'tiny-drag', hour: 8, minute: 0, durationMinutes: 15);
      await pumpGrid(tester);

      final before = await readTask('tiny-drag');
      expect(before.durationMinutes, 15);

      final blockBox = tester.getRect(find.byKey(const ValueKey('tiny-drag')));
      // Блок 24px высотой; ручка адаптивной высоты (16px) прижата к низу —
      // целимся в нижний край блока.
      final grabBottom = Offset(blockBox.center.dx, blockBox.bottom - 4);

      await tester.dragFrom(grabBottom, Offset(0, hourHeight));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('tiny-drag');
      expect(after.durationMinutes, greaterThan(15),
          reason: 'даже самый короткий блок реально ресайзится за нижний край');
      expect(after.scheduledAt.hour, 8, reason: 'начало не тронуто (нет верхней ручки)');
      expect(after.scheduledAt.minute, 0);

      // Дренируем 800мс подстраховочный Future.delayed из _commitResize.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'ОЧЕНЬ короткий блок — мышиный ресайз за нижний край стартует СРАЗУ, без '
    'предварительного выбора блока',
    (tester) async {
      // Ключевой сценарий фидбека владельца продукта: на коротких блоках
      // ресайз мышью "работал только после выбора блока", потому что ручки не
      // было совсем и палец/мышь попадали в тело (перенос). Теперь ручка есть
      // всегда — первое же нажатие-и-протягивание мышью по низу должно менять
      // длительность, БЕЗ какого-либо предшествующего тапа/клика по блоку.
      await insertTask(
          id: 'tiny-mouse', hour: 8, minute: 0, durationMinutes: 15);
      await pumpGrid(tester);

      final blockBox =
          tester.getRect(find.byKey(const ValueKey('tiny-mouse')));
      final grabBottom = Offset(blockBox.center.dx, blockBox.bottom - 4);

      // ПЕРВОЕ и единственное касание — сразу мышиный drag по ручке, без
      // предварительного tap/select.
      final gesture = await tester.startGesture(
        grabBottom,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, hourHeight));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('tiny-mouse');
      expect(after.durationMinutes, greaterThan(15),
          reason:
              'мышиный ресайз короткого блока сработал с первого касания, '
              'без предварительного выбора');

      // Дренируем 800мс подстраховочный Future.delayed из _commitResize.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await unmountAndFlush(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // B4 — drag виртуального повтора серии ВСЕГДА спрашивает область применения
  // (showRecurrenceScopeDialog), а не тихо материализует «только этот день».
  // ---------------------------------------------------------------------------

  // Тянет блок [id] вниз на один час тач-жестом (long-press-подхват + перенос,
  // как в первом тесте файла) и отдаёт управление тестеру ПОСЛЕ up(), давая
  // showRecurrenceScopeDialog (bottom sheet) успеть построиться.
  Future<void> dragBlockDownOneHour(WidgetTester tester, String blockId) async {
    final blockBox = tester.getRect(find.byKey(ValueKey(blockId)));
    final grabCenter = blockBox.center;
    final gesture = await tester.startGesture(grabCenter);
    await tester.pump(_kBlockPickupDelay + const Duration(milliseconds: 50));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, hourHeight / 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  // Дожидается завершения async-коммита DAO после выбора опции в листе.
  //
  // ВАЖНО: onlyThis/thisAndFuture/wholeSeries коммитят через DAO, после чего
  // _commitMove безусловно взводит 800мс подстраховочный Future.delayed (см.
  // комментарий у него в time_grid.dart) — для материализованных/расщеплённых
  // строк это НОВЫЙ id, поэтому didUpdateWidget старого блока никогда не
  // увидит совпадающее scheduledAt и не снимет ожидание раньше. Дожидаемся
  // (пампим) эти 800мс здесь же, иначе таймер остаётся pending на teardown
  // виджет-дерева («A Timer is still pending…») — это НЕ регрессия наших
  // изменений, а тот же паттерн, что и в обычных (нерекуррентных) тестах
  // переноса/ресайза выше по файлу.
  Future<void> settleAfterScopeChoice(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'drag виртуального повтора серии показывает диалог выбора области '
    '(only this / this+future / whole series)',
    (tester) async {
      await insertSeriesAnchor(
          id: 'series-a', hour: 9, minute: 0, durationMinutes: 60);
      await pumpGrid(tester);

      final virtualId = 'series-a@${virtualDateKey(day)}';
      await dragBlockDownOneHour(tester, virtualId);

      expect(find.text('Only this event'), findsOneWidget);
      expect(find.text('This and following events'), findsOneWidget);
      expect(find.text('All events'), findsOneWidget);

      // Закрываем лист отменой, чтобы не оставлять pending-состояние теста.
      await tester.tap(find.text('Cancel'));
      await settleAfterScopeChoice(tester);
      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'выбор «Only this event» материализует ТОЛЬКО этот день (anchor остаётся '
    'серией, дата уходит в EXDATE)',
    (tester) async {
      await insertSeriesAnchor(
          id: 'series-only', hour: 9, minute: 0, durationMinutes: 60);
      await pumpGrid(tester);

      final virtualId = 'series-only@${virtualDateKey(day)}';
      await dragBlockDownOneHour(tester, virtualId);

      await tester.tap(find.text('Only this event'));
      await settleAfterScopeChoice(tester);

      // Anchor остаётся серией (recurrenceRule не тронут кроме EXDATE).
      final anchor = await readTask('series-only');
      final rule = RecurrenceRule.parse(anchor.recurrenceRule)!;
      expect(rule.exDates.contains(DateTime(day.year, day.month, day.day)),
          isTrue,
          reason: 'день материализации уходит в EXDATE якоря');
      expect(anchor.scheduledAt.hour, 9,
          reason: 'время якоря (шаблона серии) не меняется при onlyThis');

      // Новая concrete-строка на [day] с перенесённым временем (10:00).
      final dao = ItemsDao(db);
      final rows = await dao.itemsInRange(
        day,
        day.add(const Duration(days: 1)),
      );
      final concrete =
          rows.where((r) => r.recurrenceRule == null).toList();
      expect(concrete, hasLength(1));
      expect(concrete.single.scheduledAt.hour, 10,
          reason: 'onlyThis переносит время НОВОЙ concrete-строки');

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'выбор «This and following events» расщепляет серию: старый anchor '
    'получает UNTIL, новый anchor несёт перенесённое время',
    (tester) async {
      await insertSeriesAnchor(
          id: 'series-future', hour: 9, minute: 0, durationMinutes: 60);
      await pumpGrid(tester);

      final virtualId = 'series-future@${virtualDateKey(day)}';
      await dragBlockDownOneHour(tester, virtualId);

      await tester.tap(find.text('This and following events'));
      await settleAfterScopeChoice(tester);

      // Старый якорь: UNTIL = day − 1 (серия остановлена ДО дня переноса).
      final oldAnchor = await readTask('series-future');
      final oldRule = RecurrenceRule.parse(oldAnchor.recurrenceRule)!;
      expect(oldRule.until, DateTime(day.year, day.month, day.day - 1));

      // Новый якорь (другой id, тоже recurrenceRule != null) — время суток
      // перенесено на 10:00, дата совпадает с днём разреза.
      final allAnchors = await (db.select(db.itemsTable)
            ..where((t) => t.recurrenceRule.isNotNull()))
          .get();
      final newAnchors =
          allAnchors.where((a) => a.id != 'series-future').toList();
      expect(newAnchors, hasLength(1));
      expect(newAnchors.single.scheduledAt.hour, 10);
      expect(newAnchors.single.scheduledAt.day, day.day);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'выбор «All events» переносит время СУТОК всей серии (тот же anchor id)',
    (tester) async {
      await insertSeriesAnchor(
          id: 'series-whole', hour: 9, minute: 0, durationMinutes: 60);
      await pumpGrid(tester);

      final virtualId = 'series-whole@${virtualDateKey(day)}';
      await dragBlockDownOneHour(tester, virtualId);

      await tester.tap(find.text('All events'));
      await settleAfterScopeChoice(tester);

      // Тот же anchor id — только время суток поменялось.
      final anchor = await readTask('series-whole');
      expect(anchor.scheduledAt.hour, 10);
      expect(anchor.scheduledAt.minute, 0);
      final rule = RecurrenceRule.parse(anchor.recurrenceRule)!;
      expect(rule.freq, RecurFreq.daily);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'Cancel в диалоге НЕ сохраняет перенос — anchor и БД не тронуты',
    (tester) async {
      await insertSeriesAnchor(
          id: 'series-cancel', hour: 9, minute: 0, durationMinutes: 60);
      await pumpGrid(tester);

      final virtualId = 'series-cancel@${virtualDateKey(day)}';
      await dragBlockDownOneHour(tester, virtualId);

      await tester.tap(find.text('Cancel'));
      await settleAfterScopeChoice(tester);

      // Anchor полностью не тронут: то же время, нет EXDATE, нет UNTIL.
      final anchor = await readTask('series-cancel');
      expect(anchor.scheduledAt.hour, 9);
      expect(anchor.scheduledAt.minute, 0);
      final rule = RecurrenceRule.parse(anchor.recurrenceRule)!;
      expect(rule.exDates, isEmpty);
      expect(rule.until, isNull);

      // Никакая concrete-строка/новый anchor не созданы.
      final dao = ItemsDao(db);
      final rows = await dao.itemsInRange(
        day,
        day.add(const Duration(days: 1)),
      );
      expect(rows.where((r) => r.recurrenceRule == null), isEmpty);
      final allAnchors = await (db.select(db.itemsTable)
            ..where((t) => t.recurrenceRule.isNotNull()))
          .get();
      expect(allAnchors, hasLength(1),
          reason: 'отмена не создаёт новый якорь (this+future)');

      await unmountAndFlush(tester);
    },
  );
}
