// Юнит-тесты чистых хелперов «формы» задачи (task_shape.dart). Чистый Dart,
// без Flutter/Drift — не требует биндингов.

import 'package:app/features/plan/task_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('taskShapeOf', () {
    test('positive durationMinutes → block', () {
      expect(taskShapeOf(1), TaskShape.block);
      expect(taskShapeOf(30), TaskShape.block);
      expect(taskShapeOf(300), TaskShape.block);
    });

    test('zero (kMomentDuration) → moment', () {
      expect(taskShapeOf(0), TaskShape.moment);
      expect(taskShapeOf(kMomentDuration), TaskShape.moment);
    });

    test('-1 (kOpenEndedDuration) → open', () {
      expect(taskShapeOf(-1), TaskShape.open);
      expect(taskShapeOf(kOpenEndedDuration), TaskShape.open);
    });

    test('any value below -1 also → open (future-proof sentinel guard)', () {
      expect(taskShapeOf(-2), TaskShape.open);
      expect(taskShapeOf(-100), TaskShape.open);
    });
  });

  group('openEndedDurationMinutes', () {
    test('stretches to next event start when one exists', () {
      // Открытая с 15:00 (900 мин), следующее дело в 15:45 (945 мин) → 45 мин.
      expect(
        openEndedDurationMinutes(900, nextStartMin: 945),
        45,
      );
    });

    test('stretches to end of day when there is no next event', () {
      // 15:00 (900) до конца суток (1440) → 540 мин.
      expect(
        openEndedDurationMinutes(900, nextStartMin: null),
        540,
      );
    });

    test('ignores a "next" start that is not actually after the start', () {
      // nextStartMin <= startMin — защита от некорректного входа: как если бы
      // следующего дела не было (падаем на конец дня).
      expect(
        openEndedDurationMinutes(900, nextStartMin: 900),
        540,
      );
      expect(
        openEndedDurationMinutes(900, nextStartMin: 300),
        540,
      );
    });

    test('never collapses to 0 or negative — floor at minDuration', () {
      // Следующее дело буквально в ту же минуту, что начало открытой задачи —
      // без пола высота блока схлопнулась бы в 0.
      expect(
        openEndedDurationMinutes(900, nextStartMin: 901, minDuration: 15),
        15,
      );
    });

    test('custom endOfDayMin is respected', () {
      expect(
        openEndedDurationMinutes(0, nextStartMin: null, endOfDayMin: 60),
        60,
      );
    });
  });

  group('nextStartAfter', () {
    test('finds the closest start strictly after "after"', () {
      expect(nextStartAfter(900, [600, 945, 1000, 1200]), 945);
    });

    test('returns null when nothing starts later', () {
      expect(nextStartAfter(1200, [600, 900, 1000]), isNull);
    });

    test('ignores starts equal to "after" (not strictly greater)', () {
      expect(nextStartAfter(900, [900, 900, 1000]), 1000);
    });

    test('empty list → null', () {
      expect(nextStartAfter(900, []), isNull);
    });
  });
}
