// B4 Stage 1 — unit-тесты трёх методов переноса повторяющихся задач
// (rescheduleSingleOccurrence / rescheduleThisAndFuture / rescheduleWholeSeries)
// и чистых помощников recurrence.dart (timeOfDayDelta, splitHeadRule, splitTailRule).
// In-memory Drift, прямой async — без pumpAndSettle и тестовых часов.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/features/plan/recurrence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ItemsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ItemsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Вспомогательная функция: вставить якорь серии в БД.
  Future<String> insertAnchor({
    required DateTime scheduledAt,
    required String rule,
    String title = 'Morning standup',
    String priority = 'medium',
    int duration = 30,
  }) async {
    final id = 'anchor-${scheduledAt.millisecondsSinceEpoch}';
    final now = DateTime.now();
    await dao.insertItem(ItemsTableCompanion(
      id: Value(id),
      userId: const Value('local'),
      title: Value(title),
      type: const Value('task'),
      priority: Value(priority),
      status: const Value('pending'),
      scheduledAt: Value(scheduledAt),
      durationMinutes: Value(duration),
      isProtected: const Value(false),
      recurrenceRule: Value(rule),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return id;
  }

  // ---------------------------------------------------------------------------
  // Чистые помощники recurrence.dart
  // ---------------------------------------------------------------------------

  group('timeOfDayDelta', () {
    test('прямая дельта: +2 ч 30 мин', () {
      final d = timeOfDayDelta(
        DateTime(2026, 6, 1, 9, 0),
        DateTime(2026, 6, 1, 11, 30),
      );
      expect(d, const Duration(hours: 2, minutes: 30));
    });

    test('отрицательная дельта: новое время раньше', () {
      final d = timeOfDayDelta(
        DateTime(2026, 6, 1, 11, 0),
        DateTime(2026, 6, 1, 9, 0),
      );
      expect(d, const Duration(hours: -2));
    });

    test('нулевая дельта: одно и то же время суток, разные дни', () {
      final d = timeOfDayDelta(
        DateTime(2026, 6, 1, 9, 0),
        DateTime(2026, 6, 5, 9, 0),
      );
      expect(d, Duration.zero);
    });

    test('дельта по минутам без часов', () {
      final d = timeOfDayDelta(
        DateTime(2026, 6, 1, 9, 15),
        DateTime(2026, 6, 1, 9, 45),
      );
      expect(d, const Duration(minutes: 30));
    });
  });

  group('splitHeadRule', () {
    test('UNTIL = splitDate − 1 день', () {
      final rule = RecurrenceRule(freq: RecurFreq.daily);
      final head = splitHeadRule(rule, DateTime(2026, 7, 1));
      expect(head.until, DateTime(2026, 6, 30));
    });

    test('EXDATE — только даты строго до splitDate', () {
      final rule = RecurrenceRule(
        freq: RecurFreq.daily,
        exDates: {
          DateTime(2026, 6, 25), // до — остаётся
          DateTime(2026, 7, 1),  // == splitDate — убирается
          DateTime(2026, 7, 5),  // после — убирается
        },
      );
      final head = splitHeadRule(rule, DateTime(2026, 7, 1));
      expect(head.exDates, {DateTime(2026, 6, 25)});
    });

    test('FREQ и BYDAY сохраняются', () {
      final rule = RecurrenceRule(
        freq: RecurFreq.weekly,
        byDays: {RecurWeekday.mo, RecurWeekday.fr},
      );
      final head = splitHeadRule(rule, DateTime(2026, 8, 1));
      expect(head.freq, RecurFreq.weekly);
      expect(head.byDays, {RecurWeekday.mo, RecurWeekday.fr});
    });
  });

  group('splitTailRule', () {
    test('нет UNTIL, когда у оригинала не было UNTIL', () {
      final rule = RecurrenceRule(freq: RecurFreq.daily);
      final tail = splitTailRule(rule, DateTime(2026, 7, 1));
      expect(tail.until, isNull);
    });

    test('наследует UNTIL, если он позже splitDate', () {
      final rule = RecurrenceRule(
        freq: RecurFreq.daily,
        until: DateTime(2026, 12, 31),
      );
      final tail = splitTailRule(rule, DateTime(2026, 7, 1));
      expect(tail.until, DateTime(2026, 12, 31));
    });

    test('не наследует UNTIL, если он до splitDate', () {
      final rule = RecurrenceRule(
        freq: RecurFreq.daily,
        until: DateTime(2026, 6, 30), // до splitDate 2026-07-01
      );
      final tail = splitTailRule(rule, DateTime(2026, 7, 1));
      expect(tail.until, isNull);
    });

    test('EXDATE — только даты >= splitDate', () {
      final rule = RecurrenceRule(
        freq: RecurFreq.daily,
        exDates: {
          DateTime(2026, 6, 25), // до — убирается
          DateTime(2026, 7, 1),  // == splitDate — остаётся
          DateTime(2026, 7, 5),  // после — остаётся
        },
      );
      final tail = splitTailRule(rule, DateTime(2026, 7, 1));
      expect(tail.exDates,
          containsAll([DateTime(2026, 7, 1), DateTime(2026, 7, 5)]));
      expect(tail.exDates.contains(DateTime(2026, 6, 25)), isFalse);
    });

    test('FREQ и BYDAY копируются', () {
      final rule = RecurrenceRule(
        freq: RecurFreq.weekly,
        byDays: {RecurWeekday.tu, RecurWeekday.th},
      );
      final tail = splitTailRule(rule, DateTime(2026, 7, 1));
      expect(tail.freq, RecurFreq.weekly);
      expect(tail.byDays, {RecurWeekday.tu, RecurWeekday.th});
    });

    test('BYMONTHDAY копируется для MONTHLY', () {
      final rule =
          RecurrenceRule(freq: RecurFreq.monthly, byMonthDay: 15);
      final tail = splitTailRule(rule, DateTime(2026, 8, 1));
      expect(tail.freq, RecurFreq.monthly);
      expect(tail.byMonthDay, 15);
    });
  });

  // ---------------------------------------------------------------------------
  // rescheduleSingleOccurrence — «ТОЛЬКО ЭТА»
  // ---------------------------------------------------------------------------

  group('rescheduleSingleOccurrence', () {
    test('создаёт concrete-строку с newScheduledAt; дата добавляется в EXDATE',
        () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      final date = DateTime(2026, 6, 25);
      final newAt = DateTime(2026, 6, 25, 14, 30);

      final concreteId =
          await dao.rescheduleSingleOccurrence(anchorId, date, newAt);
      expect(concreteId, isNotNull);

      // Concrete-строка: новое время, не серия.
      final concrete = await dao.getItemById(concreteId!);
      expect(concrete!.scheduledAt, newAt);
      expect(concrete.recurrenceRule, isNull);

      // Якорь: без UNTIL (серия не остановлена), дата в EXDATE.
      final anchor = await dao.getItemById(anchorId);
      final rule = RecurrenceRule.parse(anchor!.recurrenceRule)!;
      expect(rule.until, isNull);
      expect(rule.exDates.contains(DateTime(2026, 6, 25)), isTrue);
    });

    test('повторный вызов обновляет scheduledAt существующей строки', () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      final date = DateTime(2026, 6, 25);

      await dao.rescheduleSingleOccurrence(
          anchorId, date, DateTime(2026, 6, 25, 10, 0));
      final secondId = await dao.rescheduleSingleOccurrence(
          anchorId, date, DateTime(2026, 6, 25, 15, 0));

      final concrete = await dao.getItemById(secondId!);
      expect(concrete!.scheduledAt, DateTime(2026, 6, 25, 15, 0));

      // Ровно одна concrete-строка (без дублей).
      final rows = await dao.itemsInRange(
          DateTime(2026, 6, 25), DateTime(2026, 6, 26));
      expect(rows, hasLength(1));
    });

    test('не меняет FREQ / BYDAY якоря', () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 23, 9, 0), // понедельник
        rule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
      );
      await dao.rescheduleSingleOccurrence(
        anchorId,
        DateTime(2026, 6, 23),
        DateTime(2026, 6, 23, 11, 0),
      );
      final anchor = await dao.getItemById(anchorId);
      final rule = RecurrenceRule.parse(anchor!.recurrenceRule)!;
      expect(rule.freq, RecurFreq.weekly);
      expect(rule.byDays,
          containsAll([RecurWeekday.mo, RecurWeekday.we, RecurWeekday.fr]));
      expect(rule.until, isNull); // серия не прервана
    });
  });

  // ---------------------------------------------------------------------------
  // rescheduleThisAndFuture — «ЭТА И БУДУЩИЕ»
  // ---------------------------------------------------------------------------

  group('rescheduleThisAndFuture', () {
    test('старый якорь получает UNTIL = splitDate − 1', () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      await dao.rescheduleThisAndFuture(
        anchorId,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 1, 11, 0),
      );
      final old = await dao.getItemById(anchorId);
      final rule = RecurrenceRule.parse(old!.recurrenceRule)!;
      expect(rule.until, DateTime(2026, 6, 30));
    });

    test('новый якорь: тот же FREQ, без UNTIL, scheduledAt = newScheduledAt',
        () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      final newAnchorId = await dao.rescheduleThisAndFuture(
        anchorId,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 1, 11, 0),
      );
      expect(newAnchorId, isNotNull);
      final newAnchor = await dao.getItemById(newAnchorId!);
      expect(newAnchor!.scheduledAt, DateTime(2026, 7, 1, 11, 0));
      final newRule = RecurrenceRule.parse(newAnchor.recurrenceRule)!;
      expect(newRule.freq, RecurFreq.daily);
      expect(newRule.until, isNull);
    });

    test('BYDAY / BYMONTHDAY переносятся в новый якорь', () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
        title: 'English class',
      );
      final newAnchorId = await dao.rescheduleThisAndFuture(
        anchorId,
        DateTime(2026, 7, 6), // понедельник
        DateTime(2026, 7, 6, 15, 0),
      );
      final newAnchor = await dao.getItemById(newAnchorId!);
      expect(newAnchor!.title, 'English class');
      final newRule = RecurrenceRule.parse(newAnchor.recurrenceRule)!;
      expect(newRule.freq, RecurFreq.weekly);
      expect(newRule.byDays,
          {RecurWeekday.mo, RecurWeekday.we, RecurWeekday.fr});
    });

    test('прошлые материализованные экземпляры (< splitDate) не трогаются',
        () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      // Прошлое: материализуем как done.
      await dao.materializeOccurrence(anchorId, DateTime(2026, 6, 25),
          status: 'done');

      await dao.rescheduleThisAndFuture(
        anchorId,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 1, 11, 0),
      );

      final past =
          await dao.itemsInRange(DateTime(2026, 6, 25), DateTime(2026, 6, 26));
      expect(past.single.status, 'done');
      expect(past.single.scheduledAt,
          DateTime(2026, 6, 25, 9, 0)); // не сдвинулся
    });

    test('будущие материализованные экземпляры сдвигаются на дельту времени',
        () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      // Будущая материализация (после splitDate 2026-07-01).
      await dao.materializeOccurrence(anchorId, DateTime(2026, 7, 5));

      await dao.rescheduleThisAndFuture(
        anchorId,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 1, 11, 0), // delta = +2 h
      );

      // Конкретная строка 5 июля: 9:00 + 2ч = 11:00.
      final rows =
          await dao.itemsInRange(DateTime(2026, 7, 5), DateTime(2026, 7, 6));
      expect(rows, hasLength(1));
      expect(rows.single.scheduledAt, DateTime(2026, 7, 5, 11, 0));
    });

    test('поля нового якоря скопированы с якоря (title/priority/duration)',
        () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
        title: 'Gym session',
        priority: 'main',
        duration: 60,
      );
      final newAnchorId = await dao.rescheduleThisAndFuture(
        anchorId,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 1, 7, 0),
      );
      final newAnchor = await dao.getItemById(newAnchorId!);
      expect(newAnchor!.title, 'Gym session');
      expect(newAnchor.priority, 'main');
      expect(newAnchor.durationMinutes, 60);
    });

    test('возвращает null для не-серии', () async {
      final now = DateTime.now();
      await dao.insertItem(ItemsTableCompanion(
        id: const Value('plain'),
        userId: const Value('local'),
        title: const Value('x'),
        type: const Value('task'),
        priority: const Value('medium'),
        status: const Value('pending'),
        scheduledAt: Value(now),
        durationMinutes: const Value(30),
        isProtected: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
      final res = await dao.rescheduleThisAndFuture(
          'plain', now, now.add(const Duration(hours: 1)));
      expect(res, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // rescheduleWholeSeries — «ВСЯ СЕРИЯ»
  // ---------------------------------------------------------------------------

  group('rescheduleWholeSeries', () {
    test('scheduledAt якоря = newScheduledAt', () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      await dao.rescheduleWholeSeries(
          anchorId, DateTime(2026, 6, 22, 11, 0));

      final anchor = await dao.getItemById(anchorId);
      expect(anchor!.scheduledAt, DateTime(2026, 6, 22, 11, 0));
    });

    test('все материализованные экземпляры сдвигаются на дельту', () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      await dao.materializeOccurrence(anchorId, DateTime(2026, 6, 23));
      await dao.materializeOccurrence(anchorId, DateTime(2026, 6, 24));

      await dao.rescheduleWholeSeries(
          anchorId, DateTime(2026, 6, 22, 11, 0)); // delta = +2h

      final d23 =
          await dao.itemsInRange(DateTime(2026, 6, 23), DateTime(2026, 6, 24));
      final d24 =
          await dao.itemsInRange(DateTime(2026, 6, 24), DateTime(2026, 6, 25));
      expect(d23.single.scheduledAt, DateTime(2026, 6, 23, 11, 0));
      expect(d24.single.scheduledAt, DateTime(2026, 6, 24, 11, 0));
    });

    test('fromDate: только строки >= fromDate сдвигаются', () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=DAILY',
      );
      await dao.materializeOccurrence(anchorId, DateTime(2026, 6, 23));
      await dao.materializeOccurrence(anchorId, DateTime(2026, 6, 25));

      await dao.rescheduleWholeSeries(
        anchorId,
        DateTime(2026, 6, 22, 11, 0), // delta = +2h
        fromDate: DateTime(2026, 6, 25), // только 25-е и позже
      );

      // 23-е: не тронуто (до fromDate).
      final d23 =
          await dao.itemsInRange(DateTime(2026, 6, 23), DateTime(2026, 6, 24));
      expect(d23.single.scheduledAt, DateTime(2026, 6, 23, 9, 0));

      // 25-е: сдвинуто.
      final d25 =
          await dao.itemsInRange(DateTime(2026, 6, 25), DateTime(2026, 6, 26));
      expect(d25.single.scheduledAt, DateTime(2026, 6, 25, 11, 0));
    });

    test('нет материализованных — только якорь обновляется, ошибок нет',
        () async {
      final anchorId = await insertAnchor(
        scheduledAt: DateTime(2026, 6, 22, 9, 0),
        rule: 'FREQ=WEEKLY;BYDAY=MO',
      );
      await expectLater(
        dao.rescheduleWholeSeries(anchorId, DateTime(2026, 6, 22, 10, 0)),
        completes,
      );
      final anchor = await dao.getItemById(anchorId);
      expect(anchor!.scheduledAt, DateTime(2026, 6, 22, 10, 0));
    });

    test('updatedAt якоря обновляется', () async {
      final before = DateTime(2026, 6, 22, 8, 0);
      final now = DateTime.now();
      await dao.insertItem(ItemsTableCompanion(
        id: const Value('a1'),
        userId: const Value('local'),
        title: const Value('t'),
        type: const Value('task'),
        priority: const Value('medium'),
        status: const Value('pending'),
        scheduledAt: Value(DateTime(2026, 6, 22, 9, 0)),
        durationMinutes: const Value(30),
        isProtected: const Value(false),
        recurrenceRule: const Value('FREQ=DAILY'),
        createdAt: Value(before),
        updatedAt: Value(before),
      ));

      await dao.rescheduleWholeSeries('a1', DateTime(2026, 6, 22, 11, 0));

      final anchor = await dao.getItemById('a1');
      expect(anchor!.updatedAt.isAfter(before), isTrue);
      expect(anchor.updatedAt.isBefore(now.add(const Duration(seconds: 5))),
          isTrue);
    });
  });
}
