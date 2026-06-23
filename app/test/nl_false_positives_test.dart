// Адверсариальные тесты NL-парсера: «ловушки» на ЛОЖНЫЕ СРАБАТЫВАНИЯ.
//
// Цель — убедиться, что парсер КОНСЕРВАТИВЕН: числа-количества, версии, счёт,
// а также слова, содержащие триггерные ПОДСТРОКИ модуля/типа, НЕ должны
// ошибочно толковаться как время/дата/модуль/тип. При неоднозначности парсер
// обязан НЕ извлекать, а не портить задачу.
//
// Все тесты используют фиксированный [now] (как в nl_datetime_test.dart):
//   now = Среда 2026-06-17 14:30 (weekday=3)

import 'package:app/core/utils/nl_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 17, 14, 30);

  // -------------------------------------------------------------------------
  // A. Числа-количества (НЕ время, when=null). За числом идёт слово-существи-
  //    тельное (листов, км, страниц…) или число — это просто количество.
  // -------------------------------------------------------------------------
  group('A. Числа-количества → when=null', () {
    final cases = <String>[
      '700 листов наклеить',
      'купить 5 яблок',
      'прочитать 300 страниц',
      'пробежать 10 км',
      'написать 200 строк кода',
      '100 отжиманий',
      'съесть 2 банана',
      'полить 3 цветка',
      '5 задач по математике',
      '1000 шагов',
    ];
    for (final t in cases) {
      test('"$t" → when=null, title unchanged', () {
        final r = parseNaturalDateTime(t, now);
        expect(r.when, isNull, reason: t);
        expect(r.cleanedTitle, t, reason: t);
      });
    }
  });

  // -------------------------------------------------------------------------
  // B. Числа в названии (счёт/версии/часть, НЕ время).
  // -------------------------------------------------------------------------
  group('B. Числа-счёт/версии → when=null', () {
    final cases = <String>[
      'Посмотреть фильм принцесса и 7 гномов',
      'глава 7 учебника',
      'айфон 15 настроить',
      '12 стульев прочитать',
      'отчёт за 2024',
      'топ 10 книг',
    ];
    for (final t in cases) {
      test('"$t" → when=null', () {
        final r = parseNaturalDateTime(t, now);
        expect(r.when, isNull, reason: t);
      });
    }
  });

  // -------------------------------------------------------------------------
  // C. Триггерные ПОДСТРОКИ модуля/типа — не должны включать модуль/тип.
  // -------------------------------------------------------------------------
  group('C. Триггерные подстроки модуля → moduleLink=null', () {
    test('"соната Бетховена" (содержит "сон") → не sleep', () {
      final r = parseNaturalDateTime('соната Бетховена', now);
      expect(r.moduleLink, isNull);
    });

    test('"персональный план" (содержит "сон"/"перс") → не sleep', () {
      final r = parseNaturalDateTime('персональный план', now);
      expect(r.moduleLink, isNull);
    });

    test('"трендовый ролик" (содержит "трен") → не workout', () {
      final r = parseNaturalDateTime('трендовый ролик', now);
      expect(r.moduleLink, isNull);
    });

    test('"тренд 2024" (содержит "трен") → не workout', () {
      final r = parseNaturalDateTime('тренд 2024', now);
      expect(r.moduleLink, isNull);
    });

    test('"вокзал встретить" (содержит "зал") → не workout', () {
      final r = parseNaturalDateTime('вокзал встретить', now);
      expect(r.moduleLink, isNull);
    });

    test('"обедать вредно" — слово "обед" внутри "обедать" → meal:lunch ок', () {
      // "обед" как стем еды — приемлемо. Контроль: НЕ ломаем при "пообедать".
      final r = parseNaturalDateTime('пообедать с другом', now);
      expect(r.moduleLink, 'meal:lunch');
    });
  });

  group('C. Триггерные подстроки типа → type=null/корректный', () {
    test('"пародия на клип" (содержит "пара") → не event', () {
      final r = parseNaturalDateTime('пародия на клип', now);
      expect(r.type, isNull);
    });

    test('"парад победы" (содержит "пара") → не event', () {
      final r = parseNaturalDateTime('парад победы', now);
      expect(r.type, isNull);
    });

    test('"позвонить напарнику" (содержит "пара") → не event', () {
      final r = parseNaturalDateTime('позвонить напарнику', now);
      expect(r.type, isNull);
    });

    test('"сделать презентацию" (содержит ли "сдать"?) → не deadline', () {
      final r = parseNaturalDateTime('сделать презентацию', now);
      expect(r.type, isNull);
    });

    test('"срочное письмо" (содержит "сроч"~"срок"?) → не deadline', () {
      final r = parseNaturalDateTime('срочное письмо', now);
      expect(r.type, isNull);
    });

    test('"лекарство купить" (содержит "лек"~"лекци"?) → не event', () {
      final r = parseNaturalDateTime('лекарство купить', now);
      expect(r.type, isNull);
    });

    test('"задачник по экономике" (содержит "зач"?) → не exam', () {
      final r = parseNaturalDateTime('задачник по экономике', now);
      expect(r.type, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // D. Легитимные кейсы (регрессия — ДОЛЖНЫ работать).
  // -------------------------------------------------------------------------
  group('D. Легитимные временные конструкции', () {
    test('"встреча в 700" → 7:00', () {
      final r = parseNaturalDateTime('встреча в 700', now);
      expect(r.when, isNotNull);
      expect(r.when!.hour, 7);
      expect(r.when!.minute, 0);
    });

    test('"позвонить в 7" → 7:00', () {
      final r = parseNaturalDateTime('позвонить в 7', now);
      expect(r.when, isNotNull);
      expect(r.when!.hour, 7);
      expect(r.when!.minute, 0);
    });

    test('"зарядка с 7 до 9" → 7:00 + duration 120', () {
      final r = parseNaturalDateTime('зарядка с 7 до 9', now);
      expect(r.when, DateTime(2026, 6, 17, 7, 0));
      expect(r.durationMinutes, 120);
    });

    test('"7:00 созвон" → 7:00', () {
      final r = parseNaturalDateTime('7:00 созвон', now);
      expect(r.when, isNotNull);
      expect(r.when!.hour, 7);
      expect(r.when!.minute, 0);
    });

    test('"тренировка завтра в 5" → завтра 5:00', () {
      final r = parseNaturalDateTime('тренировка завтра в 5', now);
      expect(r.when, DateTime(2026, 6, 18, 5, 0));
    });

    test('"экзамен 18 июня" → дата 18 июня', () {
      final r = parseNaturalDateTime('экзамен 18 июня', now);
      expect(r.when, DateTime(2026, 6, 18, 9, 0));
    });

    test('"тренировка в 700 до 900" → workout, 7:00, duration 120', () {
      final r = parseNaturalDateTime('тренировка в 700 до 900', now);
      expect(r.moduleLink, 'workout');
      expect(r.when!.hour, 7);
      expect(r.when!.minute, 0);
      expect(r.durationMinutes, 120);
    });

    test('"обед" → meal:lunch', () {
      final r = parseNaturalDateTime('обед', now);
      expect(r.moduleLink, 'meal:lunch');
    });

    test('"лекция в 9:00" → type event, 9:00', () {
      final r = parseNaturalDateTime('лекция в 9:00', now);
      expect(r.type, 'event');
      expect(r.when!.hour, 9);
      expect(r.when!.minute, 0);
    });

    test('"сдать курсовую" → type deadline', () {
      final r = parseNaturalDateTime('сдать курсовую', now);
      expect(r.type, 'deadline');
    });

    test('"Утренний трен" → workout (короткая форма как слово)', () {
      final r = parseNaturalDateTime('Утренний трен', now);
      expect(r.moduleLink, 'workout');
    });

    test('"пара по физике" → event (слово "пара")', () {
      final r = parseNaturalDateTime('пара по физике', now);
      expect(r.type, 'event');
    });
  });
}
