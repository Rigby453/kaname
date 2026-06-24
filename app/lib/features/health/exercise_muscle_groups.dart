// Канонический маппинг встроенных упражнений → группа мышц (Part 2).
//
// КОНТЕКСТ / ВЕРДИКТ: в БД (workout_exercises.name) хранится ЛОКАЛИЗОВАННОЕ
// имя упражнения (translate('exercise.<slug>')), а НЕ слаг. Поля «группа мышц»
// в схеме нет. Слаги и их группа движения (push/pull/legs/core/cardio) живут
// в приватном каталоге workout_templates.dart, но завязка на лог теряется на
// этапе локализации имени. Поэтому надёжная группировка по группе мышц без
// миграции схемы невозможна для произвольных/переименованных упражнений.
//
// БЮДЖЕТНОЕ РЕШЕНИЕ (без миграции): строим reverse-lookup из ВСЕХ локалей
// строк 'exercise.<slug>' → группа мышц. Это покрывает встроенные упражнения
// в любой из 11 локалей; для кастомных/переименованных имён — мягкий fallback
// в группу «Other». Никаких изменений БД.
//
// PURE: без Flutter-зависимостей; вход — карта переводов exercise.* (передаётся
// из вызывающего кода), чтобы оставаться тестируемым без виджетов.

/// Группа мышц для UI-группировки «Прогресс по упражнениям».
/// Совпадает с группами движения каталога шаблонов + 'other' для остального.
enum MuscleGroup { push, pull, legs, core, cardio, other }

/// Стабильный i18n-ключ заголовка группы (строки в health_b.dart, 'muscle.*').
String muscleGroupKey(MuscleGroup g) {
  switch (g) {
    case MuscleGroup.push:
      return 'muscle.push';
    case MuscleGroup.pull:
      return 'muscle.pull';
    case MuscleGroup.legs:
      return 'muscle.legs';
    case MuscleGroup.core:
      return 'muscle.core';
    case MuscleGroup.cardio:
      return 'muscle.cardio';
    case MuscleGroup.other:
      return 'muscle.other';
  }
}

/// Порядок отображения групп в списке (push → pull → legs → core → cardio → other).
const List<MuscleGroup> kMuscleGroupOrder = [
  MuscleGroup.push,
  MuscleGroup.pull,
  MuscleGroup.legs,
  MuscleGroup.core,
  MuscleGroup.cardio,
  MuscleGroup.other,
];

/// Канонический слаг встроенного упражнения → группа мышц.
/// Источник истины — каталог в workout_templates.dart (там поле приватное);
/// здесь продублирован публично, чтобы переиспользоваться и будущей
/// schema-задачей (когда у упражнений появится колонка muscleGroup/slug).
const Map<String, MuscleGroup> kExerciseSlugToGroup = {
  // push
  'barbell_bench_press': MuscleGroup.push,
  'overhead_barbell_press': MuscleGroup.push,
  'dumbbell_bench_press': MuscleGroup.push,
  'dumbbell_shoulder_press': MuscleGroup.push,
  'dumbbell_lateral_raise': MuscleGroup.push,
  'push_up': MuscleGroup.push,
  'pike_push_up': MuscleGroup.push,
  'dip': MuscleGroup.push,
  // pull
  'barbell_row': MuscleGroup.pull,
  'barbell_curl': MuscleGroup.pull,
  'dumbbell_row': MuscleGroup.pull,
  'dumbbell_curl': MuscleGroup.pull,
  'pull_up': MuscleGroup.pull,
  'chin_up': MuscleGroup.pull,
  'inverted_row': MuscleGroup.pull,
  'superman_hold': MuscleGroup.pull,
  // legs
  'barbell_back_squat': MuscleGroup.legs,
  'barbell_deadlift': MuscleGroup.legs,
  'barbell_romanian_deadlift': MuscleGroup.legs,
  'dumbbell_goblet_squat': MuscleGroup.legs,
  'dumbbell_lunge': MuscleGroup.legs,
  'bodyweight_squat': MuscleGroup.legs,
  'bulgarian_split_squat': MuscleGroup.legs,
  'glute_bridge': MuscleGroup.legs,
  // core
  'plank': MuscleGroup.core,
  'hanging_knee_raise': MuscleGroup.core,
  'hollow_body_hold': MuscleGroup.core,
  'russian_twist': MuscleGroup.core,
  // cardio
  'burpee': MuscleGroup.cardio,
  'mountain_climber': MuscleGroup.cardio,
  'jumping_jack': MuscleGroup.cardio,
  'high_knees': MuscleGroup.cardio,
};

/// Строит lookup «локализованное имя (любая локаль) → группа мышц» из всех
/// переводов строк `exercise.<slug>`. Имена нормализуются (lower + trim),
/// чтобы матчить устойчиво независимо от регистра.
///
/// [allStrings] — объединённая карта строк приложения (S._all): key → {lang→текст}.
Map<String, MuscleGroup> buildExerciseNameToGroup(
  Map<String, Map<String, String>> allStrings,
) {
  final result = <String, MuscleGroup>{};
  for (final entry in kExerciseSlugToGroup.entries) {
    final translations = allStrings['exercise.${entry.key}'];
    if (translations == null) continue;
    for (final localized in translations.values) {
      result[localized.trim().toLowerCase()] = entry.value;
    }
  }
  return result;
}

/// Группа мышц для отображаемого имени упражнения (или [MuscleGroup.other],
/// если это кастомное/переименованное упражнение, которого нет в каталоге).
MuscleGroup groupForName(
  String displayName,
  Map<String, MuscleGroup> nameToGroup,
) {
  return nameToGroup[displayName.trim().toLowerCase()] ?? MuscleGroup.other;
}
