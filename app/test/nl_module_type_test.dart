// Юнит-тесты распознавания МОДУЛЯ (moduleLink) и ТИПА (type) парсером
// естественного языка. Эти поля определяются по ключевым словам названия и,
// в отличие от времени/длительности, НЕ вырезаются из cleanedTitle —
// это смысловые слова заголовка.
//
// Все тесты используют фиксированный [now] — DateTime.now() не вызывается.
//   now = Среда 2026-06-17 14:30 (weekday=3)

import 'package:app/core/utils/module_inference.dart';
import 'package:app/core/utils/nl_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Фиксированная «сейчас»: среда 2026-06-17 14:30
  final now = DateTime(2026, 6, 17, 14, 30);

  group('moduleLink — модуль по ключевым словам', () {
    test('"тренировка в 700 до 900" → workout, время 7:00', () {
      final r = parseNaturalDateTime('тренировка в 700 до 900', now);
      expect(r.moduleLink, 'workout');
      // Компактное ЧЧММ "700" → 7:00 (сегодня уже прошло в 14:30 → завтра).
      expect(r.when, isNotNull);
      expect(r.when!.hour, 7);
      expect(r.when!.minute, 0);
      // Ключевое слово «тренировка» НЕ вырезается из заголовка.
      expect(r.cleanedTitle.toLowerCase(), contains('тренировка'));
      // Тип здесь не указан явными словами → null (вызывающий код → 'task').
      expect(r.type, isNull);
    });

    test('"трен" (короткая форма) → workout', () {
      final r = parseNaturalDateTime('Утренний трен', now);
      expect(r.moduleLink, 'workout');
    });

    test('"workout" (EN) → workout', () {
      final r = parseNaturalDateTime('Morning workout', now);
      expect(r.moduleLink, 'workout');
    });

    test('"обед" → meal:lunch', () {
      final r = parseNaturalDateTime('обед', now);
      expect(r.moduleLink, 'meal:lunch');
      expect(r.cleanedTitle, 'обед');
    });

    test('"завтрак" → meal:breakfast', () {
      final r = parseNaturalDateTime('завтрак', now);
      expect(r.moduleLink, 'meal:breakfast');
    });

    test('"ужин с другом" → meal:dinner', () {
      final r = parseNaturalDateTime('ужин с другом', now);
      expect(r.moduleLink, 'meal:dinner');
    });

    test('"поспать днём" → sleep', () {
      final r = parseNaturalDateTime('поспать днём', now);
      expect(r.moduleLink, 'sleep');
    });

    test('обычное название без модуля → moduleLink=null', () {
      final r = parseNaturalDateTime('Купить молоко', now);
      expect(r.moduleLink, isNull);
    });

    // Новые модули — парсер использует тот же словарь что и inferModuleLink.
    test('"фокус-сессия 25 мин" → focus', () {
      final r = parseNaturalDateTime('фокус-сессия 25 мин', now);
      expect(r.moduleLink, 'focus');
    });

    test('"разминка утром" → warmup', () {
      final r = parseNaturalDateTime('разминка утром', now);
      expect(r.moduleLink, 'warmup');
    });

    test('"подышать перед сном" → breathing (не sleep)', () {
      final r = parseNaturalDateTime('подышать перед сном', now);
      expect(r.moduleLink, 'breathing');
    });

    test('"медитация 10 минут" → meditation', () {
      final r = parseNaturalDateTime('медитация 10 минут', now);
      expect(r.moduleLink, 'meditation');
    });
  });

  // ---------------------------------------------------------------------------
  // Кросс-проверка: inferModuleLink и parseNaturalDateTime дают одинаковый
  // moduleLink на одном наборе фраз. Защищает от расхождения словарей.
  // ---------------------------------------------------------------------------
  group('cross-check: inferModuleLink == parseNaturalDateTime.moduleLink', () {
    final phrases = [
      'тренировка ног',
      'завтрак',
      'пообедать с другом',
      'ужин',
      'фокус-сессия',
      'зарядка',
      'дыхание',
      'медитация',
      'лечь спать',
      'Купить молоко',
    ];

    for (final phrase in phrases) {
      test('"$phrase" — inferModuleLink == parseNaturalDateTime.moduleLink', () {
        final expected = inferModuleLink(phrase);
        final r = parseNaturalDateTime(phrase, now);
        expect(
          r.moduleLink,
          expected,
          reason: '"$phrase": inferModuleLink=$expected, парсер=${r.moduleLink}',
        );
      });
    }
  });

  group('type — тип задачи по ключевым словам', () {
    test('"лекция по физике 9:00" → type=event, время 9:00', () {
      final r = parseNaturalDateTime('лекция по физике 9:00', now);
      expect(r.type, 'event');
      expect(r.when, isNotNull);
      expect(r.when!.hour, 9);
      expect(r.when!.minute, 0);
      // Ключевое слово «лекция» НЕ вырезается из заголовка.
      expect(r.cleanedTitle.toLowerCase(), contains('лекция'));
    });

    test('"семинар" → type=event', () {
      final r = parseNaturalDateTime('семинар', now);
      expect(r.type, 'event');
    });

    test('"сдать курсовую 18 июня" → type=deadline', () {
      final r = parseNaturalDateTime('сдать курсовую 18 июня', now);
      expect(r.type, 'deadline');
      // Ключевое слово «сдать» остаётся в заголовке.
      expect(r.cleanedTitle.toLowerCase(), contains('сдать'));
    });

    test('"дедлайн по проекту" → type=deadline', () {
      final r = parseNaturalDateTime('дедлайн по проекту', now);
      expect(r.type, 'deadline');
    });

    test('"экзамен по матану" → type=exam', () {
      final r = parseNaturalDateTime('экзамен по матану', now);
      expect(r.type, 'exam');
    });

    test('"зачёт" → type=exam', () {
      final r = parseNaturalDateTime('зачёт', now);
      expect(r.type, 'exam');
    });

    test('обычное название без типа → type=null', () {
      final r = parseNaturalDateTime('Позвонить маме', now);
      expect(r.type, isNull);
    });
  });

  group('module + type вместе и независимость от других полей', () {
    test('NL-поля (время/приоритет) не ломают module/type', () {
      final r = parseNaturalDateTime('тренировка p1 1ч завтра 7:00', now);
      expect(r.moduleLink, 'workout');
      expect(r.when, DateTime(2026, 6, 18, 7, 0));
      expect(r.durationMinutes, 60);
      expect(r.priority, 'main');
    });
  });
}
