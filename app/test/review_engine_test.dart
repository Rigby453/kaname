// Юнит-тесты чистой логики разбора (review_engine): слоты, маппинг AI-планов.
// Не требуют Drift/виджетов.

import 'package:app/features/today/widgets/review_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('priorityWeight', () {
    test('orders main > high > medium > low', () {
      expect(priorityWeight('main'), 4);
      expect(priorityWeight('high'), 3);
      expect(priorityWeight('medium'), 2);
      expect(priorityWeight('low'), 1);
      expect(priorityWeight('unknown'), 1);
    });
  });

  group('slotKey', () {
    test('rounds minutes down to :00 / :30', () {
      expect(slotKey(DateTime(2026, 1, 1, 9, 15)), '09:00');
      expect(slotKey(DateTime(2026, 1, 1, 9, 45)), '09:30');
      expect(slotKey(DateTime(2026, 1, 1, 14, 0)), '14:00');
    });
  });

  group('freeSlots', () {
    final day = DateTime(2026, 6, 10);

    test('full day has 28 half-hour slots (08:00–22:00)', () {
      expect(freeSlots(day, {}).length, 28);
    });

    test('excludes occupied slots', () {
      final slots = freeSlots(day, {'09:00', '09:30'});
      expect(slots.length, 26);
      expect(slots.any((s) => slotKey(s) == '09:00'), isFalse);
      expect(slots.any((s) => slotKey(s) == '10:00'), isTrue);
    });
  });

  group('mapAiPlans', () {
    test('maps plans with items into PlanVariants', () {
      final raw = [
        {
          'label': 'Balanced',
          'reason': 'spread out',
          'items': [
            {'id': 'a', 'scheduled_at': '2026-06-10T09:00:00.000Z'},
            {'id': 'b', 'scheduled_at': '2026-06-10T11:00:00.000Z'},
          ],
        },
      ];
      final plans = mapAiPlans(raw);
      expect(plans.length, 1);
      expect(plans.first.label, 'Balanced');
      expect(plans.first.reason, 'spread out');
      expect(plans.first.assign.keys, containsAll(['a', 'b']));
    });

    test('skips plans without usable items and tolerates malformed input', () {
      final raw = [
        {'label': 'Empty', 'items': <dynamic>[]},
        {'label': 'Bad items', 'items': 'not-a-list'},
        'garbage',
        {
          'items': [
            {'id': 'x', 'scheduled_at': '2026-06-10T10:00:00.000Z'},
          ],
        },
      ];
      final plans = mapAiPlans(raw);
      // Только последний план имеет валидные items.
      expect(plans.length, 1);
      expect(plans.first.label, 'AI plan'); // дефолтная подпись
      expect(plans.first.assign.keys, ['x']);
    });
  });
}
