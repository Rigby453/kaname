// Юнит-тесты парсера естественного языка дат/времени.
// Все тесты используют фиксированный [now] — DateTime.now() не вызывается.
//
// Структура фиксации:
//   now = Среда 2026-06-17 14:30 (weekday=3)
//   Фикс: "завтра" → четверг 2026-06-18
//         "пятница" → следующая пятница = 2026-06-19
//         голое "17:00" в 14:30 → сегодня (ещё не прошло)
//         голое "9:00" в 14:30 → завтра (уже прошло)

import 'package:app/core/utils/nl_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Фиксированная «сейчас»: среда 2026-06-17 14:30
  final now = DateTime(2026, 6, 17, 14, 30);

  group('parseNaturalDateTime — no match', () {
    test('empty string → when=null, cleanedTitle empty', () {
      final r = parseNaturalDateTime('', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, '');
    });

    test('plain title without time → no match', () {
      final r = parseNaturalDateTime('Сдать лабу', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'Сдать лабу');
    });

    test('EN plain title → no match', () {
      final r = parseNaturalDateTime('Buy groceries', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'Buy groceries');
    });
  });

  group('RU — завтра + время', () {
    test('"Сдать лабу завтра 17:00" → tomorrow 17:00, title "Сдать лабу"', () {
      final r = parseNaturalDateTime('Сдать лабу завтра 17:00', now);
      final expected = DateTime(2026, 6, 18, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Сдать лабу');
    });

    test('"завтра в 5" → tomorrow 05:00', () {
      final r = parseNaturalDateTime('тренировка завтра в 5', now);
      final expected = DateTime(2026, 6, 18, 5, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"завтра" alone → tomorrow 09:00', () {
      final r = parseNaturalDateTime('Встреча завтра', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Встреча');
    });
  });

  group('RU — сегодня + время', () {
    test('"сегодня в 9" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('позвонить сегодня в 9', now);
      // 09:00 уже прошло (now=14:30) → завтра
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'позвонить');
    });

    test('"сегодня 17:00" — future → today 17:00', () {
      final r = parseNaturalDateTime('зарядка сегодня 17:00', now);
      final expected = DateTime(2026, 6, 17, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'зарядка');
    });
  });

  group('EN — tomorrow + time', () {
    test('"tomorrow 5pm" → tomorrow 17:00', () {
      final r = parseNaturalDateTime('call mom tomorrow 5pm', now);
      final expected = DateTime(2026, 6, 18, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'call mom');
    });

    test('"today at 9" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('submit report today at 9', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'submit report');
    });
  });

  group('DE — morgen + Uhr', () {
    test('"morgen 17 uhr" → tomorrow 17:00', () {
      final r = parseNaturalDateTime('Hausaufgaben morgen 17 uhr', now);
      final expected = DateTime(2026, 6, 18, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Hausaufgaben');
    });

    test('"heute um 9" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('Anruf heute um 9', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Anruf');
    });
  });

  group('Relative — "через N часов" / "in N hours"', () {
    test('"через 2 часа" → now + 2h', () {
      final r = parseNaturalDateTime('почитать через 2 часа', now);
      final expected = now.add(const Duration(hours: 2));
      expect(r.when, expected);
      expect(r.cleanedTitle, 'почитать');
    });

    test('"in 2 hours" → now + 2h', () {
      final r = parseNaturalDateTime('workout in 2 hours', now);
      final expected = now.add(const Duration(hours: 2));
      expect(r.when, expected);
      expect(r.cleanedTitle, 'workout');
    });

    test('"in 2 stunden" → now + 2h', () {
      final r = parseNaturalDateTime('Training in 2 stunden', now);
      final expected = now.add(const Duration(hours: 2));
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Training');
    });
  });

  group('Weekday names', () {
    // now = среда (weekday=3). Пятница = +2 дня = 2026-06-19.
    test('RU "в пятницу" → next friday 09:00', () {
      final r = parseNaturalDateTime('занятие в пятницу', now);
      final expected = DateTime(2026, 6, 19, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'занятие');
    });

    test('EN "on friday" → next friday 09:00', () {
      final r = parseNaturalDateTime('gym on friday', now);
      final expected = DateTime(2026, 6, 19, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'gym');
    });

    test('DE "am Freitag" → next friday 09:00', () {
      final r = parseNaturalDateTime('Sport am Freitag', now);
      final expected = DateTime(2026, 6, 19, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'Sport');
    });

    test('weekday + time: "пятница 18:00" → next friday 18:00', () {
      final r = parseNaturalDateTime('тренировка пятница 18:00', now);
      final expected = DateTime(2026, 6, 19, 18, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'тренировка');
    });

    // Среда (today, weekday=3) → следующая среда +7 дней.
    test('same weekday → next week', () {
      final r = parseNaturalDateTime('лекция среда', now);
      final expected = DateTime(2026, 6, 24, 9, 0); // +7 дней
      expect(r.when, expected);
      expect(r.cleanedTitle, 'лекция');
    });
  });

  group('Bare time (no date keyword)', () {
    test('"17:00" — future → today 17:00', () {
      final r = parseNaturalDateTime('встреча 17:00', now);
      final expected = DateTime(2026, 6, 17, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"9:00" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('звонок 9:00', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'звонок');
    });

    test('"5pm" → today 17:00 (future)', () {
      final r = parseNaturalDateTime('meeting 5pm', now);
      final expected = DateTime(2026, 6, 17, 17, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'meeting');
    });

    test('"9am" — already past → tomorrow 09:00', () {
      final r = parseNaturalDateTime('standup 9am', now);
      final expected = DateTime(2026, 6, 18, 9, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'standup');
    });
  });

  group('Compact HHMM digits (Todoist-style)', () {
    test('"лекция 700" → today 07:00 already past → tomorrow, title "лекция"', () {
      final r = parseNaturalDateTime('лекция 700', now);
      // 07:00 уже прошло (now=14:30) → завтра
      final expected = DateTime(2026, 6, 18, 7, 0);
      expect(r.when, expected);
      expect(r.cleanedTitle, 'лекция');
    });

    test('"700" → 07:00 (минуты 00)', () {
      final r = parseNaturalDateTime('подъём 700', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 0)); // прошло → завтра
      expect(r.cleanedTitle, 'подъём');
    });

    test('"730" → 07:30', () {
      final r = parseNaturalDateTime('зарядка 730', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 30)); // прошло → завтра
      expect(r.cleanedTitle, 'зарядка');
    });

    test('"1830" → 18:30 (future today)', () {
      final r = parseNaturalDateTime('пара 1830', now);
      expect(r.when, DateTime(2026, 6, 17, 18, 30));
      expect(r.cleanedTitle, 'пара');
    });

    test('"900" → 09:00', () {
      final r = parseNaturalDateTime('встреча 900', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0)); // прошло → завтра
      expect(r.cleanedTitle, 'встреча');
    });

    test('"2359" → 23:59 (future today)', () {
      final r = parseNaturalDateTime('дедлайн 2359', now);
      expect(r.when, DateTime(2026, 6, 17, 23, 59));
      expect(r.cleanedTitle, 'дедлайн');
    });

    test('invalid minutes ">59" → not recognized ("760")', () {
      final r = parseNaturalDateTime('глава 760', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'глава 760');
    });

    test('invalid hours ">23" → not recognized ("2460")', () {
      final r = parseNaturalDateTime('код 2460', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'код 2460');
    });
  });

  group('Compact digits — negatives (do not over-match)', () {
    test('single short number "глава 12" → not time, unchanged', () {
      final r = parseNaturalDateTime('глава 12', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'глава 12');
    });

    test('"задача 5" → not time, unchanged', () {
      final r = parseNaturalDateTime('задача 5', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'задача 5');
    });

    test('5-digit number is not HHMM ("12345")', () {
      final r = parseNaturalDateTime('счёт 12345', now);
      expect(r.when, isNull);
      expect(r.cleanedTitle, 'счёт 12345');
    });

    test('HH:MM still wins over compact ("встреча 17:00")', () {
      final r = parseNaturalDateTime('встреча 17:00', now);
      expect(r.when, DateTime(2026, 6, 17, 17, 0));
      expect(r.cleanedTitle, 'встреча');
    });
  });

  group('Edge cases', () {
    test('already-past time "in 0 hours" stays near now', () {
      final r = parseNaturalDateTime('задача через 0 часов', now);
      // 0 часов → now + 0 = now (не сдвигается)
      expect(r.when, isNotNull);
      expect(r.cleanedTitle, 'задача');
    });

    test('voice-style: "тренировка завтра в шесть" — "шесть" не число → only tomorrow', () {
      // "шесть" — прописное слово, не парсится как число → только "завтра" распознаётся.
      final r = parseNaturalDateTime('тренировка завтра в шесть', now);
      // Завтра без времени → 09:00
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
      // "в шесть" останется в заголовке т.к. не распознано как время
      expect(r.cleanedTitle, isNotNull);
    });
  });

  // =========================================================================
  // РАСШИРЕНИЕ: длительность / приоритет / повтор.
  // =========================================================================

  group('Duration → durationMinutes', () {
    test('"лекция 1.5ч" → 90 min, title "лекция"', () {
      final r = parseNaturalDateTime('лекция 1.5ч', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'лекция');
    });

    test('"созвон 1.5 часа" → 90 min', () {
      final r = parseNaturalDateTime('созвон 1.5 часа', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'созвон');
    });

    test('"встреча 2 часа" → 120 min', () {
      final r = parseNaturalDateTime('встреча 2 часа', now);
      expect(r.durationMinutes, 120);
      expect(r.cleanedTitle, 'встреча');
    });

    test('"разминка 30 мин" → 30 min', () {
      final r = parseNaturalDateTime('разминка 30 мин', now);
      expect(r.durationMinutes, 30);
      expect(r.cleanedTitle, 'разминка');
    });

    test('"перерыв 45м" → 45 min', () {
      final r = parseNaturalDateTime('перерыв 45м', now);
      expect(r.durationMinutes, 45);
      expect(r.cleanedTitle, 'перерыв');
    });

    test('"чтение 90 минут" → 90 min', () {
      final r = parseNaturalDateTime('чтение 90 минут', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'чтение');
    });

    test('EN "call 1.5h" → 90 min', () {
      final r = parseNaturalDateTime('call 1.5h', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'call');
    });

    test('EN "break 30 min" → 30 min', () {
      final r = parseNaturalDateTime('break 30 min', now);
      expect(r.durationMinutes, 30);
      expect(r.cleanedTitle, 'break');
    });

    test('RU comma decimal "1,5ч" → 90 min', () {
      final r = parseNaturalDateTime('йога 1,5ч', now);
      expect(r.durationMinutes, 90);
      expect(r.cleanedTitle, 'йога');
    });

    test('negative: plain number "глава 12" → no duration', () {
      final r = parseNaturalDateTime('глава 12', now);
      expect(r.durationMinutes, isNull);
    });

    test('negative: "5 home" не даёт 5h (h — часть слова)', () {
      final r = parseNaturalDateTime('go 5 home', now);
      expect(r.durationMinutes, isNull);
    });
  });

  group('Priority → priority', () {
    test('"купить молоко p2" → medium, title "купить молоко"', () {
      final r = parseNaturalDateTime('купить молоко p2', now);
      expect(r.priority, 'medium');
      expect(r.cleanedTitle, 'купить молоко');
    });

    test('"задача p1" → main', () {
      final r = parseNaturalDateTime('задача p1', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'задача');
    });

    test('"уборка p3" → low', () {
      final r = parseNaturalDateTime('уборка p3', now);
      expect(r.priority, 'low');
      expect(r.cleanedTitle, 'уборка');
    });

    test('"отчёт !важно" → main, title "отчёт"', () {
      final r = parseNaturalDateTime('отчёт !важно', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'отчёт');
    });

    test('"дедлайн !!!" → main', () {
      final r = parseNaturalDateTime('дедлайн !!!', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'дедлайн');
    });

    test('"важно позвонить" → main', () {
      final r = parseNaturalDateTime('важно позвонить', now);
      expect(r.priority, 'main');
    });

    test('EN "fix bug important" → main', () {
      final r = parseNaturalDateTime('fix bug important', now);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'fix bug');
    });

    test('"задача средний" → medium', () {
      final r = parseNaturalDateTime('задача средний', now);
      expect(r.priority, 'medium');
    });

    test('"задача низкий" → low', () {
      final r = parseNaturalDateTime('задача низкий', now);
      expect(r.priority, 'low');
    });

    test('negative: single bang "ура!" → no priority', () {
      final r = parseNaturalDateTime('сделал ура!', now);
      expect(r.priority, isNull);
    });

    test('negative: plain text "купить молоко" → no priority', () {
      final r = parseNaturalDateTime('купить молоко', now);
      expect(r.priority, isNull);
    });

    test('negative: "помыть пол" (содержит "по") → no false recurrence/priority', () {
      final r = parseNaturalDateTime('помыть пол', now);
      expect(r.priority, isNull);
      expect(r.recurrenceRule, isNull);
    });
  });

  group('Recurrence → recurrenceRule', () {
    test('"зарядка каждый день" → DAILY, title "зарядка"', () {
      final r = parseNaturalDateTime('зарядка каждый день', now);
      expect(r.recurrenceRule, 'FREQ=DAILY');
      expect(r.cleanedTitle, 'зарядка');
    });

    test('"витамины ежедневно" → DAILY', () {
      final r = parseNaturalDateTime('витамины ежедневно', now);
      expect(r.recurrenceRule, 'FREQ=DAILY');
      expect(r.cleanedTitle, 'витамины');
    });

    test('EN "water daily" → DAILY', () {
      final r = parseNaturalDateTime('water daily', now);
      expect(r.recurrenceRule, 'FREQ=DAILY');
      expect(r.cleanedTitle, 'water');
    });

    test('"пара по пн,ср,пт" → WEEKLY MO,WE,FR', () {
      final r = parseNaturalDateTime('пара по пн,ср,пт', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(r.cleanedTitle, 'пара');
    });

    test('"тренировка по будням" → WEEKLY MO..FR', () {
      final r = parseNaturalDateTime('тренировка по будням', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"урок каждый понедельник" → WEEKLY MO', () {
      final r = parseNaturalDateTime('урок каждый понедельник', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO');
      expect(r.cleanedTitle, 'урок');
    });

    test('EN "gym every monday" → WEEKLY MO', () {
      final r = parseNaturalDateTime('gym every monday', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO');
      expect(r.cleanedTitle, 'gym');
    });

    test('"оплата 15 числа" → MONTHLY day15, title "оплата"', () {
      final r = parseNaturalDateTime('оплата 15 числа', now);
      expect(r.recurrenceRule, 'FREQ=MONTHLY;BYMONTHDAY=15');
      expect(r.cleanedTitle, 'оплата');
    });

    test('"взнос каждый месяц" → MONTHLY (без дня)', () {
      final r = parseNaturalDateTime('взнос каждый месяц', now);
      expect(r.recurrenceRule, 'FREQ=MONTHLY');
      expect(r.cleanedTitle, 'взнос');
    });

    test('"отчёт еженедельно" → WEEKLY (без дней)', () {
      final r = parseNaturalDateTime('отчёт еженедельно', now);
      expect(r.recurrenceRule, 'FREQ=WEEKLY');
      expect(r.cleanedTitle, 'отчёт');
    });

    test('negative: plain "позвонить в понедельник" → одноразовая дата, не серия', () {
      // "в понедельник" без маркера повтора → разовая дата (when), не recurrence.
      final r = parseNaturalDateTime('позвонить в понедельник', now);
      expect(r.recurrenceRule, isNull);
      expect(r.when, isNotNull);
    });

    test('negative: plain text "купить хлеб" → no recurrence', () {
      final r = parseNaturalDateTime('купить хлеб', now);
      expect(r.recurrenceRule, isNull);
    });
  });

  group('Combo — date + time + duration + priority', () {
    test('"тренировка завтра 18:00 1ч важно" → all fields, title "тренировка"', () {
      final r = parseNaturalDateTime('тренировка завтра 18:00 1ч важно', now);
      expect(r.when, DateTime(2026, 6, 18, 18, 0));
      expect(r.durationMinutes, 60);
      expect(r.priority, 'main');
      expect(r.cleanedTitle, 'тренировка');
    });

    test('"созвон завтра 15:00 30 мин p2"', () {
      final r = parseNaturalDateTime('созвон завтра 15:00 30 мин p2', now);
      expect(r.when, DateTime(2026, 6, 18, 15, 0));
      expect(r.durationMinutes, 30);
      expect(r.priority, 'medium');
      expect(r.cleanedTitle, 'созвон');
    });
  });

  group('Backward-compat — new fields null when only time present', () {
    test('"Сдать лабу завтра 17:00" → duration/priority/recurrence null', () {
      final r = parseNaturalDateTime('Сдать лабу завтра 17:00', now);
      expect(r.when, DateTime(2026, 6, 18, 17, 0));
      expect(r.durationMinutes, isNull);
      expect(r.priority, isNull);
      expect(r.recurrenceRule, isNull);
      expect(r.cleanedTitle, 'Сдать лабу');
    });

    test('"лекция 700" compact time still works, no extra fields', () {
      final r = parseNaturalDateTime('лекция 700', now);
      expect(r.when, DateTime(2026, 6, 18, 7, 0));
      expect(r.durationMinutes, isNull);
      expect(r.priority, isNull);
      expect(r.recurrenceRule, isNull);
      expect(r.cleanedTitle, 'лекция');
    });
  });
}
