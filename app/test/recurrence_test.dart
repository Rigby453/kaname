// Юнит-тесты библиотеки повторов (lib/features/plan/recurrence.dart) и чистых
// функций раскрытия (mergeOccurrencesForDay/Range из recurrence_providers.dart).
// Чистый Dart + минимально Drift (для ItemsTableData как value-object).

import 'package:app/core/database/database.dart';
import 'package:app/features/plan/recurrence.dart';
import 'package:app/features/plan/widgets/recurrence_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Фабрика тестового item (concrete или anchor).
ItemsTableData item({
  required String id,
  required DateTime scheduledAt,
  String? recurrenceRule,
  String status = 'pending',
  String priority = 'medium',
  String title = 'T',
}) {
  return ItemsTableData(
    id: id,
    userId: 'local',
    title: title,
    type: 'task',
    priority: priority,
    status: status,
    scheduledAt: scheduledAt,
    durationMinutes: 30,
    isProtected: false,
    recurrenceRule: recurrenceRule,
    moduleLink: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('RecurrenceRule.parse / toRuleString round-trip', () {
    test('FREQ=DAILY only', () {
      final r = RecurrenceRule.parse('FREQ=DAILY');
      expect(r, isNotNull);
      expect(r!.freq, RecurFreq.daily);
      expect(r.until, isNull);
      expect(r.exDates, isEmpty);
      expect(r.toRuleString(), 'FREQ=DAILY');
    });

    test('with UNTIL', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;UNTIL=2026-07-01');
      expect(r!.until, DateTime(2026, 7, 1));
      expect(r.toRuleString(), 'FREQ=DAILY;UNTIL=2026-07-01');
    });

    test('with EXDATE (sorted on serialize)', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;EXDATE=20260625,20260623');
      expect(r!.exDates.length, 2);
      // EXDATE сериализуются отсортированными по возрастанию.
      expect(r.toRuleString(), 'FREQ=DAILY;EXDATE=20260623,20260625');
    });

    test('with UNTIL and EXDATE — full round-trip', () {
      const raw = 'FREQ=DAILY;UNTIL=2026-08-15;EXDATE=20260623,20260624';
      final r = RecurrenceRule.parse(raw);
      expect(r!.toRuleString(), raw);
    });

    test('null / empty / non-series → null', () {
      expect(RecurrenceRule.parse(null), isNull);
      expect(RecurrenceRule.parse(''), isNull);
      expect(RecurrenceRule.parse('   '), isNull);
      // Без распознанной FREQ — не серия (например, неподдерживаемый формат).
      expect(RecurrenceRule.parse('FREQ=YEARLY'), isNull);
      expect(RecurrenceRule.parse('UNTIL=2026-07-01'), isNull);
    });

    test('exDates compared by Y/M/D only (time stripped)', () {
      final r = RecurrenceRule(
        exDates: {DateTime(2026, 6, 23, 14, 30)},
      );
      expect(r.exDates.contains(DateTime(2026, 6, 23)), isTrue);
      expect(r.toRuleString(), 'FREQ=DAILY;EXDATE=20260623');
    });
  });

  group('occursOn boundaries', () {
    final anchor = DateTime(2026, 6, 22, 9, 0);

    test('before anchor start → false', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 21)), isFalse);
    });

    test('on anchor start day → true', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 22, 23, 59)), isTrue);
    });

    test('after start, open-ended → true', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      expect(occursOn(r, anchor, DateTime(2026, 12, 31)), isTrue);
    });

    test('UNTIL is inclusive', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;UNTIL=2026-06-25')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 25)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 6, 26)), isFalse);
    });

    test('EXDATE excludes that day only', () {
      final r = RecurrenceRule.parse('FREQ=DAILY;EXDATE=20260624')!;
      expect(occursOn(r, anchor, DateTime(2026, 6, 23)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 6, 24)), isFalse);
      expect(occursOn(r, anchor, DateTime(2026, 6, 25)), isTrue);
    });
  });

  group('occurrenceDatesInRange', () {
    final anchor = DateTime(2026, 6, 22, 9, 0);

    test('generates each day in window', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 25),
      );
      expect(dates, [
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 23),
        DateTime(2026, 6, 24),
        DateTime(2026, 6, 25),
      ]);
    });

    test('respects UNTIL and EXDATE within range', () {
      final r =
          RecurrenceRule.parse('FREQ=DAILY;UNTIL=2026-06-25;EXDATE=20260623')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 21),
        DateTime(2026, 6, 30),
      );
      expect(dates, [
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 24),
        DateTime(2026, 6, 25),
      ]);
    });

    test('empty when range before anchor', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 10),
      );
      expect(dates, isEmpty);
    });

    test('inverted range → empty', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 25),
        DateTime(2026, 6, 22),
      );
      expect(dates, isEmpty);
    });
  });

  group('addExDateToRule / setUntilOnRule helpers', () {
    test('addExDateToRule adds and is idempotent', () {
      var raw = 'FREQ=DAILY';
      raw = addExDateToRule(raw, DateTime(2026, 6, 24))!;
      expect(raw, 'FREQ=DAILY;EXDATE=20260624');
      // Повтор той же даты не дублирует.
      raw = addExDateToRule(raw, DateTime(2026, 6, 24, 10, 0))!;
      expect(raw, 'FREQ=DAILY;EXDATE=20260624');
      raw = addExDateToRule(raw, DateTime(2026, 6, 23))!;
      expect(raw, 'FREQ=DAILY;EXDATE=20260623,20260624');
    });

    test('addExDateToRule on non-series returns input unchanged', () {
      expect(addExDateToRule(null, DateTime(2026, 6, 24)), isNull);
      // Неподдерживаемая частота (не серия) — строка возвращается как есть.
      expect(addExDateToRule('FREQ=YEARLY', DateTime(2026, 6, 24)),
          'FREQ=YEARLY');
    });

    test('setUntilOnRule sets/replaces UNTIL', () {
      var raw = 'FREQ=DAILY';
      raw = setUntilOnRule(raw, DateTime(2026, 6, 21))!;
      expect(raw, 'FREQ=DAILY;UNTIL=2026-06-21');
      // Замена существующего UNTIL.
      raw = setUntilOnRule(raw, DateTime(2026, 6, 30))!;
      expect(raw, 'FREQ=DAILY;UNTIL=2026-06-30');
    });

    test('setUntilOnRule preserves EXDATE', () {
      const raw = 'FREQ=DAILY;EXDATE=20260623';
      final out = setUntilOnRule(raw, DateTime(2026, 6, 30))!;
      expect(out, 'FREQ=DAILY;UNTIL=2026-06-30;EXDATE=20260623');
    });
  });

  group('virtual id helpers', () {
    test('isVirtualOccurrenceId', () {
      expect(isVirtualOccurrenceId('abc@20260622'), isTrue);
      expect(isVirtualOccurrenceId('abc'), isFalse);
    });

    test('anchorIdFromVirtual / dateFromVirtual', () {
      expect(anchorIdFromVirtual('abc@20260622'), 'abc');
      expect(anchorIdFromVirtual('plain'), 'plain');
      expect(dateFromVirtual('abc@20260622'), DateTime(2026, 6, 22));
      expect(dateFromVirtual('plain'), isNull);
    });

    test('round-trip via buildVirtualOccurrence', () {
      final anchor = item(
        id: 'anchor1',
        scheduledAt: DateTime(2026, 6, 22, 9, 30),
        recurrenceRule: 'FREQ=DAILY',
      );
      final v = buildVirtualOccurrence(anchor, DateTime(2026, 6, 25));
      expect(v.id, 'anchor1@20260625');
      expect(v.scheduledAt, DateTime(2026, 6, 25, 9, 30));
      expect(v.recurrenceRule, isNull);
      expect(v.status, 'pending');
      expect(anchorIdFromVirtual(v.id), 'anchor1');
      expect(dateFromVirtual(v.id), DateTime(2026, 6, 25));
    });
  });

  group('mergeOccurrencesForDay (pure)', () {
    final anchor = item(
      id: 'a1',
      scheduledAt: DateTime(2026, 6, 22, 8, 0),
      recurrenceRule: 'FREQ=DAILY',
    );

    test('adds virtual occurrence on a matching day, sorted', () {
      final concrete = [
        item(id: 'c1', scheduledAt: DateTime(2026, 6, 23, 12, 0)),
      ];
      final merged =
          mergeOccurrencesForDay(concrete, [anchor], DateTime(2026, 6, 23));
      expect(merged.length, 2);
      // Виртуал в 08:00 идёт раньше concrete в 12:00.
      expect(merged[0].id, 'a1@20260623');
      expect(merged[1].id, 'c1');
    });

    test('no virtual before anchor start', () {
      final merged =
          mergeOccurrencesForDay([], [anchor], DateTime(2026, 6, 21));
      expect(merged, isEmpty);
    });

    test('EXDATE day yields no virtual (materialized day)', () {
      final exAnchor = item(
        id: 'a1',
        scheduledAt: DateTime(2026, 6, 22, 8, 0),
        recurrenceRule: 'FREQ=DAILY;EXDATE=20260623',
      );
      final concrete = [
        item(id: 'c1', scheduledAt: DateTime(2026, 6, 23, 8, 0)),
      ];
      final merged =
          mergeOccurrencesForDay(concrete, [exAnchor], DateTime(2026, 6, 23));
      // Только concrete; виртуал на 23-е исключён EXDATE.
      expect(merged.length, 1);
      expect(merged[0].id, 'c1');
    });

    test('past UNTIL yields no virtual', () {
      final untilAnchor = item(
        id: 'a1',
        scheduledAt: DateTime(2026, 6, 22, 8, 0),
        recurrenceRule: 'FREQ=DAILY;UNTIL=2026-06-25',
      );
      final merged =
          mergeOccurrencesForDay([], [untilAnchor], DateTime(2026, 6, 26));
      expect(merged, isEmpty);
    });

    test('non-series anchor ignored', () {
      final notSeries =
          item(id: 'x', scheduledAt: DateTime(2026, 6, 22, 8, 0));
      final merged =
          mergeOccurrencesForDay([], [notSeries], DateTime(2026, 6, 23));
      expect(merged, isEmpty);
    });
  });

  group('WEEKLY parse / serialize / occursOn', () {
    test('parse BYDAY round-trip, sorted by weekday', () {
      // На входе перемешанные дни — на выходе отсортированы Пн..Вс.
      final r = RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=FR,MO,WE');
      expect(r, isNotNull);
      expect(r!.freq, RecurFreq.weekly);
      expect(r.byDays,
          {RecurWeekday.mo, RecurWeekday.we, RecurWeekday.fr});
      expect(r.toRuleString(), 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
    });

    test('FREQ=WEEKLY without BYDAY parses (uses anchor weekday)', () {
      final r = RecurrenceRule.parse('FREQ=WEEKLY')!;
      expect(r.byDays, isEmpty);
      // 2026-06-22 — понедельник → effectiveByDays = {MO}.
      final anchor = DateTime(2026, 6, 22, 9, 0);
      expect(r.effectiveByDays(anchor), {RecurWeekday.mo});
      expect(r.toRuleString(), 'FREQ=WEEKLY');
    });

    test('occursOn matches только указанные дни недели', () {
      // BYDAY = MO,WE,FR. Anchor = понедельник 2026-06-22.
      final r = RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=MO,WE,FR')!;
      final anchor = DateTime(2026, 6, 22, 9, 0); // Mon
      expect(occursOn(r, anchor, DateTime(2026, 6, 22)), isTrue); // Mon
      expect(occursOn(r, anchor, DateTime(2026, 6, 23)), isFalse); // Tue
      expect(occursOn(r, anchor, DateTime(2026, 6, 24)), isTrue); // Wed
      expect(occursOn(r, anchor, DateTime(2026, 6, 25)), isFalse); // Thu
      expect(occursOn(r, anchor, DateTime(2026, 6, 26)), isTrue); // Fri
      expect(occursOn(r, anchor, DateTime(2026, 6, 27)), isFalse); // Sat
    });

    test('weekly respects anchor start (before start → false)', () {
      final r = RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=MO,FR')!;
      final anchor = DateTime(2026, 6, 22, 9, 0); // Mon
      // Пятница ДО якоря (2026-06-19) не должна сработать.
      expect(occursOn(r, anchor, DateTime(2026, 6, 19)), isFalse);
    });

    test('weekly UNTIL boundary inclusive', () {
      final r = RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=MO;UNTIL=2026-07-06')!;
      final anchor = DateTime(2026, 6, 22, 9, 0);
      expect(occursOn(r, anchor, DateTime(2026, 7, 6)), isTrue); // Mon, = UNTIL
      expect(occursOn(r, anchor, DateTime(2026, 7, 13)), isFalse); // после UNTIL
    });

    test('weekly EXDATE excludes specific day', () {
      final r =
          RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=MO;EXDATE=20260629')!;
      final anchor = DateTime(2026, 6, 22, 9, 0);
      expect(occursOn(r, anchor, DateTime(2026, 6, 29)), isFalse);
      expect(occursOn(r, anchor, DateTime(2026, 7, 6)), isTrue);
    });

    test('occurrenceDatesInRange weekly multi-day, sorted', () {
      final r = RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=MO,WE,FR')!;
      final anchor = DateTime(2026, 6, 22, 9, 0); // Mon
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 30),
      );
      expect(dates, [
        DateTime(2026, 6, 22), // Mon
        DateTime(2026, 6, 24), // Wed
        DateTime(2026, 6, 26), // Fri
        DateTime(2026, 6, 29), // Mon
      ]);
    });

    test('weeklyRule helper builds expected string', () {
      final r = weeklyRule({RecurWeekday.tu, RecurWeekday.th});
      expect(r.toRuleString(), 'FREQ=WEEKLY;BYDAY=TU,TH');
    });
  });

  group('MONTHLY parse / serialize / occursOn', () {
    test('parse BYMONTHDAY round-trip', () {
      final r = RecurrenceRule.parse('FREQ=MONTHLY;BYMONTHDAY=15');
      expect(r!.freq, RecurFreq.monthly);
      expect(r.byMonthDay, 15);
      expect(r.toRuleString(), 'FREQ=MONTHLY;BYMONTHDAY=15');
    });

    test('FREQ=MONTHLY without BYMONTHDAY uses anchor day', () {
      final r = RecurrenceRule.parse('FREQ=MONTHLY')!;
      expect(r.byMonthDay, isNull);
      final anchor = DateTime(2026, 6, 9, 9, 0);
      expect(r.effectiveMonthDay(anchor), 9);
      expect(r.toRuleString(), 'FREQ=MONTHLY');
    });

    test('occursOn matches only the target day-of-month', () {
      final r = RecurrenceRule.parse('FREQ=MONTHLY;BYMONTHDAY=15')!;
      final anchor = DateTime(2026, 6, 15, 9, 0);
      expect(occursOn(r, anchor, DateTime(2026, 6, 15)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 7, 15)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 7, 16)), isFalse);
    });

    test('BYMONTHDAY=31 пропускает месяцы без 31-го числа (без клампа)', () {
      final r = RecurrenceRule.parse('FREQ=MONTHLY;BYMONTHDAY=31')!;
      final anchor = DateTime(2026, 1, 31, 9, 0);
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 1, 1),
        DateTime(2026, 5, 31),
      );
      // Январь(31), Март(31), Май(31) есть; Февраль/Апрель пропущены.
      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 3, 31),
        DateTime(2026, 5, 31),
      ]);
    });

    test('monthly UNTIL + EXDATE within range', () {
      final r = RecurrenceRule.parse(
          'FREQ=MONTHLY;BYMONTHDAY=15;UNTIL=2026-09-15;EXDATE=20260715')!;
      final anchor = DateTime(2026, 6, 15, 9, 0);
      final dates = occurrenceDatesInRange(
        anchor,
        r,
        DateTime(2026, 6, 1),
        DateTime(2026, 12, 31),
      );
      // Июнь(15), [Июль исключён EXDATE], Август(15), Сентябрь(15 = UNTIL).
      expect(dates, [
        DateTime(2026, 6, 15),
        DateTime(2026, 8, 15),
        DateTime(2026, 9, 15),
      ]);
    });

    test('monthlyRule helper builds expected string', () {
      expect(monthlyRule(monthDay: 1).toRuleString(),
          'FREQ=MONTHLY;BYMONTHDAY=1');
    });
  });

  group('DAILY backward compatibility', () {
    test('legacy FREQ=DAILY still parses and behaves as before', () {
      final r = RecurrenceRule.parse('FREQ=DAILY')!;
      expect(r.freq, RecurFreq.daily);
      final anchor = DateTime(2026, 6, 22, 9, 0);
      expect(occursOn(r, anchor, DateTime(2026, 6, 22)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 6, 23)), isTrue);
      expect(occursOn(r, anchor, DateTime(2026, 6, 21)), isFalse);
      expect(r.toRuleString(), 'FREQ=DAILY');
    });

    test('dailyRule helper', () {
      expect(dailyRule().toRuleString(), 'FREQ=DAILY');
      expect(dailyRule(until: DateTime(2026, 7, 1)).toRuleString(),
          'FREQ=DAILY;UNTIL=2026-07-01');
    });
  });

  group('mergeOccurrencesForRange (pure)', () {
    final anchor = item(
      id: 'a1',
      scheduledAt: DateTime(2026, 6, 22, 8, 0),
      recurrenceRule: 'FREQ=DAILY',
    );

    test('expands across the week, merged with concrete', () {
      final concrete = [
        item(id: 'c1', scheduledAt: DateTime(2026, 6, 23, 12, 0)),
      ];
      final merged = mergeOccurrencesForRange(
        concrete,
        [anchor],
        DateTime(2026, 6, 22),
        DateTime(2026, 6, 24),
      );
      // 3 виртуала (22,23,24) + 1 concrete = 4.
      expect(merged.length, 4);
      final ids = merged.map((e) => e.id).toList();
      expect(ids.contains('a1@20260622'), isTrue);
      expect(ids.contains('a1@20260623'), isTrue);
      expect(ids.contains('a1@20260624'), isTrue);
      expect(ids.contains('c1'), isTrue);
    });
  });
}
