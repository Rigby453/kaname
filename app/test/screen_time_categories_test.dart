// Юнит-тесты чистой категоризации экранного времени (categorizeUsageMinutes).
// Без I/O и плагина — проверяем только агрегацию пакетов в 6 категорий.

import 'package:app/features/health/screen_time_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categorizeUsageMinutes', () {
    test('пустой ввод → все категории по 0 (включая other)', () {
      final r = categorizeUsageMinutes(const {});
      expect(r, {
        'social': 0,
        'video': 0,
        'games': 0,
        'browsing': 0,
        'messaging': 0,
        'other': 0,
      });
    });

    test('известные пакеты суммируются по своим категориям', () {
      final r = categorizeUsageMinutes(const {
        'com.instagram.android': 30, // social
        'com.vkontakte.android': 15, // social
        'com.google.android.youtube': 40, // video
        'org.telegram.messenger': 25, // messaging
      });
      expect(r['social'], 45);
      expect(r['video'], 40);
      expect(r['messaging'], 25);
      expect(r['games'], 0);
      expect(r['browsing'], 0);
      expect(r['other'], 0);
    });

    test('неизвестный пакет без override → попадает в other', () {
      final r = categorizeUsageMinutes(const {
        'com.unknown.app': 999,
        'com.android.chrome': 20, // browsing
      });
      expect(r['browsing'], 20);
      // Раньше 999 терялись; теперь идут в other.
      expect(r['other'], 999);
      // Сумма всех значений == исходная сумма минут.
      expect(r.values.fold<int>(0, (a, b) => a + b), 1019);
    });

    test('неизвестный пакет с androidCategoryOverride → попадает в нужную категорию', () {
      final r = categorizeUsageMinutes(
        const {'com.some.game': 120, 'com.some.social': 45},
        androidCategoryOverrides: const {
          'com.some.game': 'games',
          'com.some.social': 'social',
        },
      );
      expect(r['games'], 120);
      expect(r['social'], 45);
      expect(r['other'], 0);
    });

    test('whitelist приоритетнее androidCategoryOverride', () {
      // instagram — в whitelist как social; override пытается сделать games.
      final r = categorizeUsageMinutes(
        const {'com.instagram.android': 60},
        androidCategoryOverrides: const {'com.instagram.android': 'games'},
      );
      // whitelist должен победить
      expect(r['social'], 60);
      expect(r['games'], 0);
    });

    test('нулевые/отрицательные минуты не учитываются', () {
      final r = categorizeUsageMinutes(const {
        'com.whatsapp': 0,
        'com.viber.voip': -5,
        'com.discord': 10, // messaging
      });
      expect(r['messaging'], 10);
      expect(r['other'], 0);
    });

    test('каждый известный пакет маппится в одну из 6 валидных категорий', () {
      const valid = {'social', 'video', 'games', 'browsing', 'messaging', 'other'};
      for (final category in kPackageToCategory.values) {
        expect(valid.contains(category), isTrue,
            reason: 'неизвестная категория: $category');
      }
    });

    test('пакет с override null → попадает в other', () {
      // androidCategoryOverride без записи для пакета → other.
      final r = categorizeUsageMinutes(
        const {'com.unknown.news': 30},
        androidCategoryOverrides: const {}, // нет записи для этого пакета
      );
      expect(r['other'], 30);
    });
  });

  group('sub-minute ceiling contract (provider prepares 1 min for <60 s sessions)', () {
    // Проверяем, что 1-минутная запись (результат ceiling в провайдере)
    // корректно доходит до нужной категории.
    // Конкретно: ночная игровая сессия 30 с → провайдер округляет до 1 мин →
    // categorizeUsageMinutes получает {package: 1} → попадает в 'games'.
    test('1-минутная запись не отфильтровывается (нет floor-до-нуля)', () {
      final r = categorizeUsageMinutes(const {'com.king.candycrushsaga': 1});
      expect(r['games'], 1,
          reason: 'Короткая игровая сессия (1 мин после ceiling) должна попасть в games');
    });

    test('1-минутная запись неизвестного игрового пакета попадает в games через override', () {
      final r = categorizeUsageMinutes(
        const {'com.some.nightgame': 1},
        androidCategoryOverrides: const {'com.some.nightgame': 'games'},
      );
      expect(r['games'], 1);
      expect(r['other'], 0);
    });

    test('нулевые минуты всё равно отбрасываются (ms=0 → не передаём)', () {
      // categorizeUsageMinutes само по себе отбрасывает <= 0 внутри, но
      // провайдер не должен передавать нулей — тест документирует ожидание.
      final r = categorizeUsageMinutes(const {'com.some.game': 0});
      expect(r['games'], 0);
      expect(r['other'], 0);
    });
  });

  group('filterTrackedPackages (#8 — неверное «Всего сегодня»)', () {
    test('убирает лаунчер и systemui, реальные приложения остаются', () {
      final filtered = filterTrackedPackages(const {
        'com.miui.home': 480, // лаунчер «в фокусе» весь день — не реальное использование
        'com.android.systemui': 60,
        'android': 45,
        'com.instagram.android': 35,
        'com.google.android.youtube': 50,
      });
      expect(filtered.containsKey('com.miui.home'), isFalse);
      expect(filtered.containsKey('com.android.systemui'), isFalse);
      expect(filtered.containsKey('android'), isFalse);
      expect(filtered['com.instagram.android'], 35);
      expect(filtered['com.google.android.youtube'], 50);
      expect(filtered.length, 2);
    });

    test('пустой ввод → пустой результат', () {
      expect(filterTrackedPackages(const {}), isEmpty);
    });

    test('без системных пакетов карта не меняется', () {
      final filtered = filterTrackedPackages(const {
        'com.instagram.android': 35,
        'org.telegram.messenger': 10,
      });
      expect(filtered, {
        'com.instagram.android': 35,
        'org.telegram.messenger': 10,
      });
    });

    test(
        'итог после фильтрации + категоризации не включает время лаунчера '
        '(репро бага «11ч 22м при ~2ч реального использования»)', () {
      final filtered = filterTrackedPackages(const {
        'com.miui.home': 480, // 8ч — артефакт Android, не использование
        'com.android.systemui': 162, // ещё ~2.7ч
        'com.instagram.android': 35,
        'com.google.android.youtube': 95,
      });
      final categorized = categorizeUsageMinutes(filtered);
      final total = categorized.values.fold<int>(0, (a, b) => a + b);
      // 35 + 95 = 130 мин (2ч10м), НЕ 772 мин (12ч52м), если бы лаунчер
      // и systemui остались в подсчёте.
      expect(total, 130);
    });
  });

  group('androidCategoryToOurCategory', () {
    test('CATEGORY_GAME (0) → games', () {
      expect(androidCategoryToOurCategory(0), 'games');
    });

    test('CATEGORY_AUDIO (1) → video', () {
      expect(androidCategoryToOurCategory(1), 'video');
    });

    test('CATEGORY_VIDEO (2) → video', () {
      expect(androidCategoryToOurCategory(2), 'video');
    });

    test('CATEGORY_SOCIAL (4) → social', () {
      expect(androidCategoryToOurCategory(4), 'social');
    });

    test('CATEGORY_NEWS (5) → browsing', () {
      expect(androidCategoryToOurCategory(5), 'browsing');
    });

    test('CATEGORY_IMAGE (3) → null (→ other)', () {
      expect(androidCategoryToOurCategory(3), isNull);
    });

    test('CATEGORY_MAPS (6) → null (→ other)', () {
      expect(androidCategoryToOurCategory(6), isNull);
    });

    test('CATEGORY_PRODUCTIVITY (7) → null (→ other)', () {
      expect(androidCategoryToOurCategory(7), isNull);
    });

    test('CATEGORY_UNDEFINED (-1) → null (→ other)', () {
      expect(androidCategoryToOurCategory(-1), isNull);
    });

    test('неизвестный int → null (→ other)', () {
      expect(androidCategoryToOurCategory(99), isNull);
    });
  });

  group(
      'computeForegroundMinutesFromEvents (fix «~8ч сразу после полуночи»)',
      () {
    test('пустой список событий → пустая карта', () {
      final start = DateTime(2026, 7, 2, 0, 0);
      final end = DateTime(2026, 7, 2, 12, 0);
      expect(computeForegroundMinutesFromEvents([], start, end), isEmpty);
    });

    test('(a) foreground 09:00–09:30 внутри дня → 30 мин', () {
      final start = DateTime(2026, 7, 2, 0, 0);
      final end = DateTime(2026, 7, 2, 23, 0);
      final events = [
        UsageEventRecord(
          package: 'com.instagram.android',
          type: kEventTypeForeground,
          timestampMs: DateTime(2026, 7, 2, 9, 0).millisecondsSinceEpoch,
        ),
        UsageEventRecord(
          package: 'com.instagram.android',
          type: kEventTypeBackground,
          timestampMs: DateTime(2026, 7, 2, 9, 30).millisecondsSinceEpoch,
        ),
      ];
      final result = computeForegroundMinutesFromEvents(events, start, end);
      expect(result['com.instagram.android'], 30);
    });

    test(
        '(b) пара событий, охватывающая полночь — до [start] время не '
        'учитывается (репро бага ~8ч)', () {
      final midnight = DateTime(2026, 7, 2, 0, 0);
      final now = DateTime(2026, 7, 2, 1, 0);
      final events = [
        // Foreground начался ВЧЕРА в 23:00 — до границы окна.
        UsageEventRecord(
          package: 'com.google.android.youtube',
          type: kEventTypeForeground,
          timestampMs: DateTime(2026, 7, 1, 23, 0).millisecondsSinceEpoch,
        ),
        // Background — сегодня в 00:30, внутри окна.
        UsageEventRecord(
          package: 'com.google.android.youtube',
          type: kEventTypeBackground,
          timestampMs: DateTime(2026, 7, 2, 0, 30).millisecondsSinceEpoch,
        ),
      ];
      final result =
          computeForegroundMinutesFromEvents(events, midnight, now);
      // Должно быть только midnight..00:30 = 30 мин, а НЕ 23:00..00:30 = 90 мин.
      expect(result['com.google.android.youtube'], 30);
    });

    test(
        '(b2) одиночное background-событие без парного foreground — сессия '
        'считается с [start], а не теряется целиком', () {
      final midnight = DateTime(2026, 7, 2, 0, 0);
      final now = DateTime(2026, 7, 2, 1, 0);
      final events = [
        UsageEventRecord(
          package: 'com.whatsapp',
          type: kEventTypeBackground,
          timestampMs: DateTime(2026, 7, 2, 0, 20).millisecondsSinceEpoch,
        ),
      ];
      final result =
          computeForegroundMinutesFromEvents(events, midnight, now);
      expect(result['com.whatsapp'], 20);
    });

    test('(c) незакрытый foreground (пакет всё ещё открыт) клипуется к now',
        () {
      final midnight = DateTime(2026, 7, 2, 0, 0);
      final now = DateTime(2026, 7, 2, 10, 15);
      final events = [
        UsageEventRecord(
          package: 'org.telegram.messenger',
          type: kEventTypeForeground,
          timestampMs: DateTime(2026, 7, 2, 10, 0).millisecondsSinceEpoch,
        ),
      ];
      final result =
          computeForegroundMinutesFromEvents(events, midnight, now);
      expect(result['org.telegram.messenger'], 15);
    });

    test('несколько сессий одного пакета за день суммируются', () {
      final midnight = DateTime(2026, 7, 2, 0, 0);
      final now = DateTime(2026, 7, 2, 23, 0);
      final events = [
        UsageEventRecord(
          package: 'com.discord',
          type: kEventTypeForeground,
          timestampMs: DateTime(2026, 7, 2, 8, 0).millisecondsSinceEpoch,
        ),
        UsageEventRecord(
          package: 'com.discord',
          type: kEventTypeBackground,
          timestampMs: DateTime(2026, 7, 2, 8, 10).millisecondsSinceEpoch,
        ),
        UsageEventRecord(
          package: 'com.discord',
          type: kEventTypeForeground,
          timestampMs: DateTime(2026, 7, 2, 20, 0).millisecondsSinceEpoch,
        ),
        UsageEventRecord(
          package: 'com.discord',
          type: kEventTypeBackground,
          timestampMs: DateTime(2026, 7, 2, 20, 5).millisecondsSinceEpoch,
        ),
      ];
      final result =
          computeForegroundMinutesFromEvents(events, midnight, now);
      expect(result['com.discord'], 15); // 10 + 5 мин
    });

    test('короткая сессия <60с всё равно округляется вверх до 1 мин', () {
      final midnight = DateTime(2026, 7, 2, 0, 0);
      final now = DateTime(2026, 7, 2, 23, 0);
      final events = [
        UsageEventRecord(
          package: 'com.king.candycrushsaga',
          type: kEventTypeForeground,
          timestampMs: DateTime(2026, 7, 2, 3, 0, 0).millisecondsSinceEpoch,
        ),
        UsageEventRecord(
          package: 'com.king.candycrushsaga',
          type: kEventTypeBackground,
          timestampMs: DateTime(2026, 7, 2, 3, 0, 30).millisecondsSinceEpoch,
        ),
      ];
      final result =
          computeForegroundMinutesFromEvents(events, midnight, now);
      expect(result['com.king.candycrushsaga'], 1);
    });

    test('несортированные события обрабатываются корректно (сортируются внутри)',
        () {
      final midnight = DateTime(2026, 7, 2, 0, 0);
      final now = DateTime(2026, 7, 2, 23, 0);
      // BACKGROUND раньше FOREGROUND в списке — но по времени наоборот.
      final events = [
        UsageEventRecord(
          package: 'com.viber.voip',
          type: kEventTypeBackground,
          timestampMs: DateTime(2026, 7, 2, 14, 20).millisecondsSinceEpoch,
        ),
        UsageEventRecord(
          package: 'com.viber.voip',
          type: kEventTypeForeground,
          timestampMs: DateTime(2026, 7, 2, 14, 0).millisecondsSinceEpoch,
        ),
      ];
      final result =
          computeForegroundMinutesFromEvents(events, midnight, now);
      expect(result['com.viber.voip'], 20);
    });

    test('end <= start → пустая карта (защита от невалидного окна)', () {
      final t = DateTime(2026, 7, 2, 10, 0);
      final events = [
        UsageEventRecord(
          package: 'com.instagram.android',
          type: kEventTypeForeground,
          timestampMs: t.millisecondsSinceEpoch,
        ),
      ];
      expect(computeForegroundMinutesFromEvents(events, t, t), isEmpty);
    });
  });
}
