// Юнит-тест пользовательских оверрайдов категорий экранного времени.
// Проверяет только чистую функцию categorizeUsageMinutes с параметром userOverrides —
// никакого I/O, плагинов, Riverpod и виджетов не нужно.

import 'package:app/features/health/screen_time_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('user category override', () {
    test(
      'неизвестный пакет без оверрайда → other; '
      'с оверрайдом → games',
      () {
        // Используем пакет, которого заведомо нет в kPackageToCategory.
        const pkg = 'com.miui.videoplayer.unknown';

        // Без оверрайда и без android-override → other.
        final withoutOverride = categorizeUsageMinutes(
          const {pkg: 45},
        );
        expect(withoutOverride['other'], 45);
        expect(withoutOverride['games'], 0);

        // С пользовательским оверрайдом: должен оказаться в games.
        final withOverride = categorizeUsageMinutes(
          const {pkg: 45},
          userOverrides: const {pkg: 'games'},
        );
        expect(withOverride['games'], 45);
        expect(withOverride['other'], 0);
      },
    );

    test('userOverride имеет приоритет над whitelist', () {
      // Instagram в whitelist → social. Пользователь решает перевести в browsing.
      const pkg = 'com.instagram.android';

      final r = categorizeUsageMinutes(
        const {pkg: 60},
        userOverrides: const {pkg: 'browsing'},
      );
      expect(r['browsing'], 60);
      expect(r['social'], 0);
    });

    test('userOverride имеет приоритет над androidCategoryOverride', () {
      const pkg = 'com.some.unknown.game';

      // Android говорит games, пользователь решает: social.
      final r = categorizeUsageMinutes(
        const {pkg: 30},
        androidCategoryOverrides: const {pkg: 'games'},
        userOverrides: const {pkg: 'social'},
      );
      expect(r['social'], 30);
      expect(r['games'], 0);
    });

    test('несколько пакетов — оверрайд применяется только к нужному', () {
      final r = categorizeUsageMinutes(
        const {
          'com.unknown.app1': 20, // → будет games через userOverride
          'com.unknown.app2': 10, // → останется в other
        },
        userOverrides: const {'com.unknown.app1': 'games'},
      );
      expect(r['games'], 20);
      expect(r['other'], 10);
    });
  });

  group('resolvePackageCategory', () {
    test('userOverride побеждает whitelist', () {
      final cat = resolvePackageCategory(
        'com.instagram.android',
        userOverrides: const {'com.instagram.android': 'video'},
      );
      expect(cat, 'video');
    });

    test('нет оверрайда → whitelist', () {
      final cat = resolvePackageCategory('com.instagram.android');
      expect(cat, 'social'); // из kPackageToCategory
    });

    test('нет ни оверрайда ни whitelist → other', () {
      final cat = resolvePackageCategory('com.totally.unknown.app');
      expect(cat, 'other');
    });

    test('androidCategoryOverride применяется если нет user и whitelist', () {
      final cat = resolvePackageCategory(
        'com.totally.unknown.app',
        androidCategoryOverrides: const {
          'com.totally.unknown.app': 'games',
        },
      );
      expect(cat, 'games');
    });
  });
}
