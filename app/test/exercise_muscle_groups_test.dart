// Unit-тесты маппинга упражнений → группа мышц (Part 2). PURE, без виджетов.

import 'package:app/core/l10n/app_strings.dart';
import 'package:app/features/health/exercise_muscle_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kExerciseSlugToGroup покрывает основные группы движения', () {
    expect(kExerciseSlugToGroup['barbell_bench_press'], MuscleGroup.push);
    expect(kExerciseSlugToGroup['barbell_row'], MuscleGroup.pull);
    expect(kExerciseSlugToGroup['barbell_back_squat'], MuscleGroup.legs);
    expect(kExerciseSlugToGroup['plank'], MuscleGroup.core);
    expect(kExerciseSlugToGroup['burpee'], MuscleGroup.cardio);
  });

  test('reverse-lookup строится из реальных строк exercise.* (все локали)', () {
    final lookup = buildExerciseNameToGroup(S.all);
    // Английское display-имя встроенного упражнения резолвится в группу.
    expect(groupForName('Barbell Bench Press', lookup), MuscleGroup.push);
    expect(groupForName('Pull-Up', lookup), MuscleGroup.pull);
    expect(groupForName('Plank', lookup), MuscleGroup.core);
  });

  test('reverse-lookup матчит и НЕ английские локали (русское имя)', () {
    final lookup = buildExerciseNameToGroup(S.all);
    // «Жим штанги лёжа» (ru exercise.barbell_bench_press) → push.
    expect(groupForName('Жим штанги лёжа', lookup), MuscleGroup.push);
    // «Планка» (ru exercise.plank) → core.
    expect(groupForName('Планка', lookup), MuscleGroup.core);
  });

  test('матч устойчив к регистру и пробелам', () {
    final lookup = buildExerciseNameToGroup(S.all);
    expect(groupForName('  barbell bench press  ', lookup), MuscleGroup.push);
  });

  test('кастомное/неизвестное имя → MuscleGroup.other', () {
    final lookup = buildExerciseNameToGroup(S.all);
    expect(groupForName('My Special Exercise', lookup), MuscleGroup.other);
    expect(groupForName('', lookup), MuscleGroup.other);
  });

  test('каждая группа имеет стабильный i18n-ключ и присутствует в порядке', () {
    for (final g in MuscleGroup.values) {
      expect(muscleGroupKey(g), startsWith('muscle.'));
      expect(kMuscleGroupOrder, contains(g));
    }
  });
}
