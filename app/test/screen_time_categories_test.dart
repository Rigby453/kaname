// Юнит-тесты чистой категоризации экранного времени (categorizeUsageMinutes).
// Без I/O и плагина — проверяем только агрегацию пакетов в 5 категорий.

import 'package:app/features/health/screen_time_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categorizeUsageMinutes', () {
    test('пустой ввод → все категории по 0', () {
      final r = categorizeUsageMinutes(const {});
      expect(r, {
        'social': 0,
        'video': 0,
        'games': 0,
        'browsing': 0,
        'messaging': 0,
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
    });

    test('неизвестные пакеты игнорируются', () {
      final r = categorizeUsageMinutes(const {
        'com.unknown.app': 999,
        'com.android.chrome': 20, // browsing
      });
      expect(r['browsing'], 20);
      expect(r.values.fold<int>(0, (a, b) => a + b), 20);
    });

    test('нулевые/отрицательные минуты не учитываются', () {
      final r = categorizeUsageMinutes(const {
        'com.whatsapp': 0,
        'com.viber.voip': -5,
        'com.discord': 10, // messaging
      });
      expect(r['messaging'], 10);
    });

    test('каждый известный пакет маппится в одну из 5 валидных категорий', () {
      const valid = {'social', 'video', 'games', 'browsing', 'messaging'};
      for (final category in kPackageToCategory.values) {
        expect(valid.contains(category), isTrue,
            reason: 'неизвестная категория: $category');
      }
    });
  });
}
