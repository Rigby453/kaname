// Юнит-тесты палитры цветов задач (#14).
// Проверяем: уникальность ключей, размер палитры (~16-20),
// round-trip taskColorFromKey для известных ключей и null для null/unknown.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/today/task_colors.dart';

void main() {
  group('kTaskColors', () {
    test('keys are unique', () {
      final keys = kTaskColors.map((o) => o.key).toList();
      final unique = keys.toSet();
      expect(unique.length, keys.length, reason: 'duplicate color key found');
    });

    test('palette size is ~16-20', () {
      expect(kTaskColors.length, greaterThanOrEqualTo(16));
      expect(kTaskColors.length, lessThanOrEqualTo(20));
    });
  });

  group('taskColorFromKey', () {
    test('round-trips every known key to its color', () {
      for (final option in kTaskColors) {
        expect(taskColorFromKey(option.key), option.color,
            reason: 'key ${option.key} did not round-trip');
      }
    });

    test('returns null for null', () {
      expect(taskColorFromKey(null), isNull);
    });

    test('returns null for unknown key', () {
      expect(taskColorFromKey('not-a-real-color'), isNull);
      expect(taskColorFromKey(''), isNull);
    });
  });
}
