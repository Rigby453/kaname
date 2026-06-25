// Юнит-тесты парсера ICS (lib/features/import/ics_parser.dart).
// Чистый Dart, без Drift и без виджетов.
//
// Время: UTC-события сравниваем с DateTime.utc(...).toLocal(), чтобы тесты не
// зависели от часового пояса машины. Floating/all-day строятся локально.

import 'package:app/features/import/ics_parser.dart';
import 'package:app/features/plan/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

String _wrap(String body) => 'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    '$body\r\n'
    'END:VCALENDAR\r\n';

String _vevent(String lines) => 'BEGIN:VEVENT\r\n$lines\r\nEND:VEVENT';

void main() {
  group('IcsParser — базовый разбор', () {
    test('одно валидное событие (floating local time)', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Math lecture\r\n'
        'DTSTART:20240617T090000\r\n'
        'DTEND:20240617T103000',
      ));
      final events = IcsParser.parse(ics);
      expect(events, hasLength(1));
      final e = events.single;
      expect(e.summary, 'Math lecture');
      expect(e.dtStart, DateTime(2024, 6, 17, 9, 0));
      expect(e.durationMinutes, 90);
      expect(e.isAllDay, isFalse);
      expect(e.recurrenceRule, isNull);
    });

    test('несколько событий', () {
      final ics = _wrap(
        '${_vevent('SUMMARY:A\r\nDTSTART:20240617T090000')}\r\n'
        '${_vevent('SUMMARY:B\r\nDTSTART:20240617T110000')}',
      );
      final events = IcsParser.parse(ics);
      expect(events.map((e) => e.summary), ['A', 'B']);
    });

    test('событие без SUMMARY пропускается', () {
      final ics = _wrap(_vevent('DTSTART:20240617T090000'));
      expect(IcsParser.parse(ics), isEmpty);
    });

    test('пустой файл → пустой список', () {
      expect(IcsParser.parse(''), isEmpty);
    });

    test('мусор без VEVENT → пустой список', () {
      expect(IcsParser.parse('hello world\nnot a calendar'), isEmpty);
    });

    test('событие без DTSTART → dtStart == null, но событие создаётся', () {
      final ics = _wrap(_vevent('SUMMARY:No date'));
      final events = IcsParser.parse(ics);
      expect(events, hasLength(1));
      expect(events.single.dtStart, isNull);
    });

    test('битая дата → dtStart == null', () {
      final ics = _wrap(_vevent('SUMMARY:Bad\r\nDTSTART:notadate'));
      expect(IcsParser.parse(ics).single.dtStart, isNull);
    });

    test('DURATION задаёт длительность при отсутствии DTEND', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Gym\r\nDTSTART:20240617T090000\r\nDURATION:PT45M',
      ));
      expect(IcsParser.parse(ics).single.durationMinutes, 45);
    });

    test('длительность по умолчанию = 60 для обычного события без DTEND/DURATION',
        () {
      final ics = _wrap(_vevent('SUMMARY:X\r\nDTSTART:20240617T090000'));
      expect(IcsParser.parse(ics).single.durationMinutes, 60);
    });
  });

  group('IcsParser — таймзоны', () {
    test('UTC (суффикс Z) конвертируется в локальное', () {
      final ics = _wrap(_vevent('SUMMARY:UTC\r\nDTSTART:20240617T090000Z'));
      final e = IcsParser.parse(ics).single;
      expect(e.dtStart, DateTime.utc(2024, 6, 17, 9, 0).toLocal());
    });

    test('TZID трактуется как локальное wall-clock', () {
      final ics = _wrap(_vevent(
        'SUMMARY:NY\r\nDTSTART;TZID=America/New_York:20240617T090000',
      ));
      final e = IcsParser.parse(ics).single;
      // Без базы TZ — берём стенное время как локальное.
      expect(e.dtStart, DateTime(2024, 6, 17, 9, 0));
      expect(e.isAllDay, isFalse);
    });
  });

  group('IcsParser — all-day', () {
    test('8-значная дата → all-day, полночь, сутки длительности', () {
      final ics = _wrap(_vevent('SUMMARY:Holiday\r\nDTSTART:20240617'));
      final e = IcsParser.parse(ics).single;
      expect(e.isAllDay, isTrue);
      expect(e.dtStart, DateTime(2024, 6, 17, 0, 0));
      expect(e.durationMinutes, 1440);
    });

    test('VALUE=DATE параметр → all-day', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Holiday\r\nDTSTART;VALUE=DATE:20240617',
      ));
      final e = IcsParser.parse(ics).single;
      expect(e.isAllDay, isTrue);
      expect(e.dtStart, DateTime(2024, 6, 17));
    });

    test('all-day с DTEND следующего дня → 1440 минут', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Holiday\r\nDTSTART:20240617\r\nDTEND:20240618',
      ));
      expect(IcsParser.parse(ics).single.durationMinutes, 1440);
    });
  });

  group('IcsParser — escape (RFC 5545)', () {
    test('экранированные запятая, точка с запятой, обратный слэш, перевод строки',
        () {
      final ics = _wrap(_vevent(
        r'SUMMARY:Lunch\, then study\; bring \\notes\nsecond line'
        '\r\nDTSTART:20240617T090000',
      ));
      final e = IcsParser.parse(ics).single;
      expect(e.summary, 'Lunch, then study; bring \\notes\nsecond line');
    });

    test('\\N (заглавная) тоже даёт перевод строки', () {
      final ics = _wrap(_vevent(
        'SUMMARY:line1\\Nline2\r\nDTSTART:20240617T090000',
      ));
      expect(IcsParser.parse(ics).single.summary, 'line1\nline2');
    });
  });

  group('IcsParser — line folding', () {
    test('сложенная строка (пробел-продолжение) склеивается', () {
      // RFC 5545: длинная строка разрезается вставкой CRLF+пробел внутри слова;
      // при раскрытии CRLF+пробел удаляются (склеивая разрезанное слово).
      final ics = _wrap(_vevent(
        'SUMMARY:Very long title that was fol\r\n ded across lines'
        '\r\nDTSTART:20240617T090000',
      ));
      expect(
        IcsParser.parse(ics).single.summary,
        'Very long title that was folded across lines',
      );
    });

    test('сложенная строка с табом склеивается', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Tab\r\n\tfolded\r\nDTSTART:20240617T090000',
      ));
      expect(IcsParser.parse(ics).single.summary, 'Tabfolded');
    });
  });

  group('IcsParser — RRULE → recurrenceRule', () {
    test('DAILY', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Daily\r\nDTSTART:20240617T090000\r\nRRULE:FREQ=DAILY',
      ));
      final rule = IcsParser.parse(ics).single.recurrenceRule;
      expect(rule, 'FREQ=DAILY');
      // Должно быть представимо моделью приложения:
      expect(RecurrenceRule.parse(rule), isNotNull);
    });

    test('WEEKLY с BYDAY', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Class\r\nDTSTART:20240617T090000\r\n'
        'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR',
      ));
      final rule = IcsParser.parse(ics).single.recurrenceRule;
      expect(rule, 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
      final parsed = RecurrenceRule.parse(rule);
      expect(parsed, isNotNull);
      expect(parsed!.freq, RecurFreq.weekly);
      expect(parsed.byDays,
          {RecurWeekday.mo, RecurWeekday.we, RecurWeekday.fr});
    });

    test('MONTHLY с BYMONTHDAY', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Rent\r\nDTSTART:20240601T090000\r\n'
        'RRULE:FREQ=MONTHLY;BYMONTHDAY=15',
      ));
      final rule = IcsParser.parse(ics).single.recurrenceRule;
      expect(rule, 'FREQ=MONTHLY;BYMONTHDAY=15');
      expect(RecurrenceRule.parse(rule)!.byMonthDay, 15);
    });

    test('UNTIL конвертируется YYYYMMDD..Z → YYYY-MM-DD', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Bounded\r\nDTSTART:20240617T090000\r\n'
        'RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20241231T235959Z',
      ));
      final rule = IcsParser.parse(ics).single.recurrenceRule;
      expect(rule, 'FREQ=WEEKLY;BYDAY=MO;UNTIL=2024-12-31');
      expect(RecurrenceRule.parse(rule)!.until, DateTime(2024, 12, 31));
    });

    test('INTERVAL=1 допустим', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Daily\r\nDTSTART:20240617T090000\r\n'
        'RRULE:FREQ=DAILY;INTERVAL=1',
      ));
      expect(IcsParser.parse(ics).single.recurrenceRule, 'FREQ=DAILY');
    });

    group('непредставимые правила → recurrenceRule == null, событие остаётся',
        () {
      void expectNullRule(String rrule) {
        final ics = _wrap(_vevent(
          'SUMMARY:E\r\nDTSTART:20240617T090000\r\nRRULE:$rrule',
        ));
        final events = IcsParser.parse(ics);
        expect(events, hasLength(1), reason: 'базовое событие не теряется');
        expect(events.single.recurrenceRule, isNull, reason: rrule);
      }

      test('FREQ=YEARLY', () => expectNullRule('FREQ=YEARLY'));
      test('FREQ=HOURLY', () => expectNullRule('FREQ=HOURLY'));
      test('INTERVAL=2', () => expectNullRule('FREQ=WEEKLY;INTERVAL=2'));
      test('COUNT=5', () => expectNullRule('FREQ=DAILY;COUNT=5'));
      test('позиционный BYDAY 2MO',
          () => expectNullRule('FREQ=MONTHLY;BYDAY=2MO'));
      test('множественный BYMONTHDAY',
          () => expectNullRule('FREQ=MONTHLY;BYMONTHDAY=1,15'));
      test('битый UNTIL не превращает серию в бесконечную',
          () => expectNullRule('FREQ=DAILY;UNTIL=garbage'));
    });
  });
}
