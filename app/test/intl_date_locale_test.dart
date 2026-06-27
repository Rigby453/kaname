// Верификационный тест: applyIntlLocale() корректно инициализирует intl
// и все вызовы DateFormat без явной локали начинают использовать язык пользователя.
//
// Без applyIntlLocale (или без initializeDateFormatting) intl использует 'en_US'
// как запасной вариант — месяцы/дни показываются по-английски даже если
// Intl.defaultLocale = 'ru'.
//
// Тест является ЮНИТ-тестом: нет виджетов, нет pump, нет риска deadlock.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:app/core/l10n/locale_provider.dart';

void main() {
  // Сбрасываем defaultLocale после каждого теста, чтобы не загрязнять
  // глобальное состояние intl для следующего теста.
  tearDown(() {
    Intl.defaultLocale = null;
  });

  test(
    'applyIntlLocale(ru) — DateFormat.MMMM() возвращает русское название месяца',
    () async {
      // Июнь 2026 — произвольная дата для детерминированной проверки.
      final june = DateTime(2026, 6, 1);

      await applyIntlLocale('ru');

      final month = DateFormat.MMMM().format(june);
      // Русский вариант «июнь» — проверяем кириллическое начало.
      expect(
        month.toLowerCase(),
        contains('июн'),
        reason: 'Ожидалось русское название месяца июня, получено: "$month"',
      );
    },
  );

  test(
    'applyIntlLocale(de) — DateFormat.MMMM() возвращает немецкое название',
    () async {
      final june = DateTime(2026, 6, 1);

      await applyIntlLocale('de');

      final month = DateFormat.MMMM().format(june);
      // Немецкий вариант «Juni».
      expect(
        month.toLowerCase(),
        contains('juni'),
        reason: 'Ожидалось немецкое название месяца июня, получено: "$month"',
      );
    },
  );

  test(
    'applyIntlLocale(en) — DateFormat.yMMMMEEEEd() возвращает английское форматирование',
    () async {
      final june = DateTime(2026, 6, 1);

      await applyIntlLocale('en');

      final formatted = DateFormat.yMMMMEEEEd().format(june);
      // Должен содержать «June» (английское)
      expect(
        formatted,
        contains('June'),
        reason: 'Ожидался английский формат, получено: "$formatted"',
      );
    },
  );

  test(
    'смена локали: переключение ru → de → ru корректно обновляет Intl.defaultLocale',
    () async {
      final june = DateTime(2026, 6, 1);

      await applyIntlLocale('ru');
      expect(Intl.defaultLocale, 'ru');
      expect(DateFormat.MMMM().format(june).toLowerCase(), contains('июн'));

      await applyIntlLocale('de');
      expect(Intl.defaultLocale, 'de');
      expect(DateFormat.MMMM().format(june).toLowerCase(), contains('juni'));

      await applyIntlLocale('ru');
      expect(Intl.defaultLocale, 'ru');
      expect(DateFormat.MMMM().format(june).toLowerCase(), contains('июн'));
    },
  );
}
