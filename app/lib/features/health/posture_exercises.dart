// Контент упражнений для осанки (SPEC C5 Ф2 «осанка»).
// Нет БД, нет видео — только l10n-ключи; виджет резолвит через context.s().

/// Одно упражнение для осанки.
class PostureExercise {
  const PostureExercise({
    required this.nameKey,
    required this.stepsKey,
    required this.seconds,
  });

  /// Ключ l10n для названия упражнения.
  final String nameKey;

  /// Ключ l10n для инструкций (2-3 предложения).
  final String stepsKey;

  /// Рекомендуемая длительность в секундах.
  final int seconds;
}

/// Список упражнений для осанки — 6 штук, без медицинских обещаний.
/// nameKey / stepsKey резолвятся через context.s() в виджете.
const postureExercises = <PostureExercise>[
  PostureExercise(
    nameKey: 'posture.chin_tucks.name',
    stepsKey: 'posture.chin_tucks.steps',
    seconds: 30,
  ),
  PostureExercise(
    nameKey: 'posture.shoulder_blade_squeeze.name',
    stepsKey: 'posture.shoulder_blade_squeeze.steps',
    seconds: 30,
  ),
  PostureExercise(
    nameKey: 'posture.wall_angels.name',
    stepsKey: 'posture.wall_angels.steps',
    seconds: 60,
  ),
  PostureExercise(
    nameKey: 'posture.doorway_chest_stretch.name',
    stepsKey: 'posture.doorway_chest_stretch.steps',
    seconds: 30,
  ),
  PostureExercise(
    nameKey: 'posture.upper_trap_stretch.name',
    stepsKey: 'posture.upper_trap_stretch.steps',
    seconds: 30,
  ),
  PostureExercise(
    nameKey: 'posture.cat_cow.name',
    stepsKey: 'posture.cat_cow.steps',
    seconds: 60,
  ),
];
