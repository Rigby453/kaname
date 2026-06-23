// Бесплатный (offline, без ИИ) генератор программ тренировок (Feature A).
//
// PURE + тестируемый: никаких Flutter-зависимостей, никакой сети, никакой БД*.
// На вход — ответы анкеты, на выход — структурированная WorkoutProgram
// (имя + дни + упражнения с подходами/повторами/отдыхом).
//
// ВАЖНО: и бесплатный путь (buildTemplateProgram), и AI-путь (ответ
// /ai/workout-build → parseAiWorkoutProgram) маппятся в ОДНУ И ТУ ЖЕ модель
// WorkoutProgram, чтобы маршрут сохранения был общим (saveWorkoutProgram).
//
// * Единственная не-pure функция — saveWorkoutProgram (внизу файла): она пишет
//   программу в Drift через WorkoutsDao. Сам Dao — чистый Dart (без Flutter),
//   так что файл по-прежнему не тянет Flutter SDK и тестируется без виджетов.

import '../../core/database/daos/workouts_dao.dart';

// ---------------------------------------------------------------------------
// Модель программы (общая для template-пути и AI-ответа)
// ---------------------------------------------------------------------------

/// Одно упражнение в дне программы.
/// [reps] — СТРОКА (как и в API): диапазон "8-12" или "AMRAP". Целое для БД
/// извлекается отдельно в маршруте сохранения (см. repsToInt).
class ProgramExercise {
  const ProgramExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.note,
  });

  final String name;
  final int sets;
  final String reps;
  final int restSeconds;
  final String? note;
}

/// Один тренировочный день программы (станет одним шаблоном Workout).
class ProgramDay {
  const ProgramDay({required this.title, required this.exercises});

  final String title;
  final List<ProgramExercise> exercises;
}

/// Готовая программа: имя + дни + заметка тренера.
class WorkoutProgram {
  const WorkoutProgram({
    required this.programName,
    required this.days,
    this.note = '',
  });

  final String programName;
  final List<ProgramDay> days;
  final String note;
}

// ---------------------------------------------------------------------------
// Каталог упражнений (модест, первый драфт — пользователь потом правит)
// ---------------------------------------------------------------------------

/// Шаблон упражнения с требуемым инвентарём и группой движения.
/// [equipment] — какой инвентарь НУЖЕН (одно из barbell/dumbbells/pullup_bar/
/// bodyweight). 'full_gym' в запросе разблокирует всё (см. _hasEquipment).
class _ExerciseTemplate {
  const _ExerciseTemplate({
    required this.name,
    required this.equipment,
    required this.group, // 'push' | 'pull' | 'legs' | 'core' | 'cardio'
  });

  final String name;
  final String equipment;
  final String group;
}

// Скромный пул упражнений. Достаточно разнообразный, чтобы собрать
// push/pull/legs и full-body под доступный инвентарь.
const List<_ExerciseTemplate> _catalog = [
  // --- Push (грудь/плечи/трицепс) ---
  _ExerciseTemplate(name: 'Barbell Bench Press', equipment: 'barbell', group: 'push'),
  _ExerciseTemplate(name: 'Overhead Barbell Press', equipment: 'barbell', group: 'push'),
  _ExerciseTemplate(name: 'Dumbbell Bench Press', equipment: 'dumbbells', group: 'push'),
  _ExerciseTemplate(name: 'Dumbbell Shoulder Press', equipment: 'dumbbells', group: 'push'),
  _ExerciseTemplate(name: 'Dumbbell Lateral Raise', equipment: 'dumbbells', group: 'push'),
  _ExerciseTemplate(name: 'Push-Up', equipment: 'bodyweight', group: 'push'),
  _ExerciseTemplate(name: 'Pike Push-Up', equipment: 'bodyweight', group: 'push'),
  _ExerciseTemplate(name: 'Dip', equipment: 'bodyweight', group: 'push'),

  // --- Pull (спина/бицепс) ---
  _ExerciseTemplate(name: 'Barbell Row', equipment: 'barbell', group: 'pull'),
  _ExerciseTemplate(name: 'Barbell Curl', equipment: 'barbell', group: 'pull'),
  _ExerciseTemplate(name: 'Dumbbell Row', equipment: 'dumbbells', group: 'pull'),
  _ExerciseTemplate(name: 'Dumbbell Curl', equipment: 'dumbbells', group: 'pull'),
  _ExerciseTemplate(name: 'Pull-Up', equipment: 'pullup_bar', group: 'pull'),
  _ExerciseTemplate(name: 'Chin-Up', equipment: 'pullup_bar', group: 'pull'),
  _ExerciseTemplate(name: 'Inverted Row', equipment: 'bodyweight', group: 'pull'),
  _ExerciseTemplate(name: 'Superman Hold', equipment: 'bodyweight', group: 'pull'),

  // --- Legs (ноги/ягодицы) ---
  _ExerciseTemplate(name: 'Barbell Back Squat', equipment: 'barbell', group: 'legs'),
  _ExerciseTemplate(name: 'Barbell Deadlift', equipment: 'barbell', group: 'legs'),
  _ExerciseTemplate(name: 'Barbell Romanian Deadlift', equipment: 'barbell', group: 'legs'),
  _ExerciseTemplate(name: 'Dumbbell Goblet Squat', equipment: 'dumbbells', group: 'legs'),
  _ExerciseTemplate(name: 'Dumbbell Lunge', equipment: 'dumbbells', group: 'legs'),
  _ExerciseTemplate(name: 'Bodyweight Squat', equipment: 'bodyweight', group: 'legs'),
  _ExerciseTemplate(name: 'Bulgarian Split Squat', equipment: 'bodyweight', group: 'legs'),
  _ExerciseTemplate(name: 'Glute Bridge', equipment: 'bodyweight', group: 'legs'),

  // --- Core ---
  _ExerciseTemplate(name: 'Plank', equipment: 'bodyweight', group: 'core'),
  _ExerciseTemplate(name: 'Hanging Knee Raise', equipment: 'pullup_bar', group: 'core'),
  _ExerciseTemplate(name: 'Hollow Body Hold', equipment: 'bodyweight', group: 'core'),
  _ExerciseTemplate(name: 'Russian Twist', equipment: 'bodyweight', group: 'core'),

  // --- Cardio / conditioning (для fat_loss/endurance) ---
  _ExerciseTemplate(name: 'Burpee', equipment: 'bodyweight', group: 'cardio'),
  _ExerciseTemplate(name: 'Mountain Climber', equipment: 'bodyweight', group: 'cardio'),
  _ExerciseTemplate(name: 'Jumping Jack', equipment: 'bodyweight', group: 'cardio'),
  _ExerciseTemplate(name: 'High Knees', equipment: 'bodyweight', group: 'cardio'),
];

/// Доступен ли инвентарь упражнения. 'full_gym' разблокирует всё; bodyweight
/// доступен всегда, если пользователь выбрал bodyweight ИЛИ full_gym (или если
/// список вообще пуст — деградация к bodyweight).
bool _hasEquipment(String needed, List<String> available) {
  if (available.contains('full_gym')) return true;
  return available.contains(needed);
}

/// Фильтрует каталог по доступному инвентарю.
List<_ExerciseTemplate> _availableExercises(List<String> equipment) {
  // Пустой ввод деградирует к собственному весу — программа всегда соберётся.
  final eq = equipment.isEmpty ? const ['bodyweight'] : equipment;
  return _catalog.where((e) => _hasEquipment(e.equipment, eq)).toList();
}

// ---------------------------------------------------------------------------
// Подходы/повторы/отдых по цели и опыту
// ---------------------------------------------------------------------------

/// Схема подходов/повторов/отдыха в зависимости от цели тренировки.
({int sets, String reps, int rest}) _schemeFor(String goal, String experience) {
  // Новичкам — меньше объёма (меньше подходов).
  final setBias = experience == 'beginner' ? -1 : (experience == 'advanced' ? 1 : 0);
  switch (goal) {
    case 'strength':
      return (sets: 4 + setBias, reps: '4-6', rest: 150);
    case 'muscle':
      return (sets: 4 + setBias, reps: '8-12', rest: 90);
    case 'fat_loss':
      return (sets: 3 + setBias, reps: '12-15', rest: 45);
    case 'endurance':
      return (sets: 3 + setBias, reps: '15-20', rest: 40);
    case 'general':
    default:
      return (sets: 3 + setBias, reps: '10-12', rest: 60);
  }
}

// Порядок «сплитов» по числу дней. Новичкам и при 1-3 днях — full-body,
// иначе классический push/pull/legs (с повтором при 4+).
List<String> _splitFor({required int daysPerWeek, required String experience}) {
  final d = daysPerWeek.clamp(1, 7);
  // Новичок всегда тренируется full-body — лучшая частота на группу.
  if (experience == 'beginner' || d <= 2) {
    return List.filled(d, 'full');
  }
  if (d == 3) return ['push', 'pull', 'legs'];
  if (d == 4) return ['upper', 'lower', 'upper', 'lower'];
  if (d == 5) return ['push', 'pull', 'legs', 'upper', 'lower'];
  if (d == 6) return ['push', 'pull', 'legs', 'push', 'pull', 'legs'];
  return ['push', 'pull', 'legs', 'upper', 'lower', 'full', 'core'];
}

/// Группы движений, которые входят в день данного типа.
List<String> _groupsForDay(String dayType, String goal) {
  // fat_loss/endurance добавляют кардио-финишер в каждый день.
  final conditioning =
      (goal == 'fat_loss' || goal == 'endurance') ? const ['cardio'] : const <String>[];
  switch (dayType) {
    case 'push':
      return ['push', 'push', ...conditioning];
    case 'pull':
      return ['pull', 'pull', 'core', ...conditioning];
    case 'legs':
      return ['legs', 'legs', 'core', ...conditioning];
    case 'upper':
      return ['push', 'pull', 'push', 'pull', ...conditioning];
    case 'lower':
      return ['legs', 'legs', 'core', ...conditioning];
    case 'core':
      return ['core', 'core', ...conditioning];
    case 'full':
    default:
      return ['legs', 'push', 'pull', 'core', ...conditioning];
  }
}

/// Человекочитаемый заголовок дня.
String _dayTitle(String dayType, int index) {
  switch (dayType) {
    case 'push':
      return 'Push Day';
    case 'pull':
      return 'Pull Day';
    case 'legs':
      return 'Leg Day';
    case 'upper':
      return 'Upper Body';
    case 'lower':
      return 'Lower Body';
    case 'core':
      return 'Core & Conditioning';
    case 'full':
    default:
      return 'Full Body ${index + 1}';
  }
}

/// Имя программы по цели.
String _programName(String goal) {
  switch (goal) {
    case 'strength':
      return 'Strength Program';
    case 'muscle':
      return 'Muscle Builder';
    case 'fat_loss':
      return 'Fat Loss Program';
    case 'endurance':
      return 'Endurance Program';
    case 'general':
    default:
      return 'General Fitness';
  }
}

// ---------------------------------------------------------------------------
// Главная функция: собрать программу из ответов анкеты (PURE)
// ---------------------------------------------------------------------------

/// Собирает программу тренировок из ответов анкеты, БЕЗ ИИ и без сети.
///
/// [goal]         — strength | muscle | fat_loss | endurance | general
/// [experience]   — beginner | intermediate | advanced
/// [equipment]    — доступный инвентарь (barbell/dumbbells/pullup_bar/
///                  bodyweight/full_gym); пустой список деградирует к bodyweight.
/// [daysPerWeek]  — 1..7; число дней в программе равно этому значению.
///
/// Гарантии (см. тесты):
///  - days.length == daysPerWeek (зажато в [1,7]);
///  - используются ТОЛЬКО упражнения с доступным инвентарём;
///  - каждый день непустой.
WorkoutProgram buildTemplateProgram({
  required String goal,
  required String experience,
  required List<String> equipment,
  required int daysPerWeek,
}) {
  final available = _availableExercises(equipment);
  final scheme = _schemeFor(goal, experience);
  final split = _splitFor(daysPerWeek: daysPerWeek, experience: experience);

  // Группируем доступные упражнения по группе движения для быстрого выбора.
  final byGroup = <String, List<_ExerciseTemplate>>{};
  for (final e in available) {
    byGroup.putIfAbsent(e.group, () => []).add(e);
  }

  // Курсор по каждой группе, чтобы дни не повторяли одни и те же упражнения.
  final cursor = <String, int>{};

  ProgramExercise? pick(String group) {
    final pool = byGroup[group];
    if (pool == null || pool.isEmpty) return null;
    final i = (cursor[group] ?? 0) % pool.length;
    cursor[group] = i + 1;
    final t = pool[i];
    // Кор/кардио по времени удержания → reps как количество/удержание.
    final isHold = t.group == 'core' || t.group == 'cardio';
    return ProgramExercise(
      name: t.name,
      sets: scheme.sets.clamp(2, 6),
      reps: isHold ? (t.group == 'core' ? '30-45s' : '30s') : scheme.reps,
      restSeconds: isHold ? 30 : scheme.rest,
    );
  }

  final days = <ProgramDay>[];
  for (var d = 0; d < split.length; d++) {
    final dayType = split[d];
    final groups = _groupsForDay(dayType, goal);
    final exercises = <ProgramExercise>[];
    for (final g in groups) {
      final ex = pick(g);
      if (ex != null) exercises.add(ex);
    }
    // Защита: если для типа дня ничего не нашлось (узкий инвентарь),
    // докидываем любое доступное упражнение, чтобы день не был пустым.
    if (exercises.isEmpty && available.isNotEmpty) {
      final t = available[d % available.length];
      exercises.add(ProgramExercise(
        name: t.name,
        sets: scheme.sets.clamp(2, 6),
        reps: scheme.reps,
        restSeconds: scheme.rest,
      ));
    }
    days.add(ProgramDay(title: _dayTitle(dayType, d), exercises: exercises));
  }

  return WorkoutProgram(
    programName: _programName(goal),
    days: days,
    note: '',
  );
}

// ---------------------------------------------------------------------------
// AI-путь: ответ бэкенда /ai/workout-build → WorkoutProgram (защитный парсер)
// ---------------------------------------------------------------------------

/// Маппит тело ответа /ai/workout-build в [WorkoutProgram].
///
/// Ожидаемая форма (snake_case, как в api-spec):
///   { program_name, note, days: [ { title, exercises: [
///       { name, sets, reps(строка), rest_seconds, note? } ] } ] }
///
/// ЗАЩИТНЫЙ: любое отсутствующее/кривое поле подменяется разумным дефолтом,
/// чтобы UI никогда не падал на неполном ответе модели. Пустые/битые
/// упражнения и дни без упражнений отбрасываются.
WorkoutProgram parseAiWorkoutProgram(Map<String, dynamic> json) {
  final programName = (json['program_name'] as String?)?.trim();
  final note = (json['note'] as String?)?.trim() ?? '';

  final rawDays = json['days'];
  final days = <ProgramDay>[];
  if (rawDays is List) {
    for (final rawDay in rawDays) {
      if (rawDay is! Map) continue;
      final day = Map<String, dynamic>.from(rawDay);

      final rawExercises = day['exercises'];
      final exercises = <ProgramExercise>[];
      if (rawExercises is List) {
        for (final rawEx in rawExercises) {
          if (rawEx is! Map) continue;
          final ex = Map<String, dynamic>.from(rawEx);
          final name = (ex['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue; // упражнение без имени — мусор
          exercises.add(
            ProgramExercise(
              name: name,
              sets: _asPositiveInt(ex['sets'], fallback: 3),
              // reps приходит строкой ("8-12"/"AMRAP"); число для БД извлекаем позже.
              reps: _asReps(ex['reps']),
              restSeconds: _asPositiveInt(ex['rest_seconds'], fallback: 60),
              note: (ex['note'] as String?)?.trim(),
            ),
          );
        }
      }

      if (exercises.isEmpty) continue; // день без упражнений не сохраняем
      final title = (day['title'] as String?)?.trim();
      days.add(
        ProgramDay(
          title: title == null || title.isEmpty ? 'Workout ${days.length + 1}' : title,
          exercises: exercises,
        ),
      );
    }
  }

  return WorkoutProgram(
    programName: programName == null || programName.isEmpty ? 'AI Program' : programName,
    days: days,
    note: note,
  );
}

/// Приводит динамическое значение к положительному int (терпит num/строку).
int _asPositiveInt(Object? v, {required int fallback}) {
  if (v is int && v > 0) return v;
  if (v is num && v > 0) return v.round();
  if (v is String) {
    final n = int.tryParse(v.trim());
    if (n != null && n > 0) return n;
  }
  return fallback;
}

/// Приводит reps к непустой строке (модель может прислать число или строку).
String _asReps(Object? v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  if (v is num) return '${v is int ? v : v.round()}';
  return '10';
}

// ---------------------------------------------------------------------------
// reps-строка → int для БД (колонка reps — INT)
// ---------------------------------------------------------------------------

/// Извлекает представительное целое из reps-строки для целочисленной колонки БД.
///
/// Правила:
///  - "8-12" / "8–12" → 8 (ведущее число диапазона);
///  - "12" → 12;
///  - "30s" / "45s" (удержание/время) → 30 / 45;
///  - "AMRAP" / "max" / любое без чисел → [fallback] (по умолчанию 10).
///
/// Оригинальная строка сохраняется отдельно (в technique) — не теряется.
int repsToInt(String reps, {int fallback = 10}) {
  final match = RegExp(r'\d+').firstMatch(reps);
  if (match == null) return fallback;
  final n = int.tryParse(match.group(0)!);
  return (n == null || n <= 0) ? fallback : n;
}

// ---------------------------------------------------------------------------
// Сохранение программы в Drift (общий маршрут для template- и AI-пути)
// ---------------------------------------------------------------------------

/// Сохраняет [program] в локальную БД: КАЖДЫЙ [ProgramDay] становится отдельным
/// шаблоном Workout, а его упражнения — строками WorkoutExercisesTable.
///
/// Маппинг полей упражнения на addExercise:
///  - sets        → sets (как есть);
///  - reps(строка)→ reps (int через [repsToInt]); ОРИГИНАЛ диапазона/AMRAP
///    кладём в technique (колонки note у упражнения нет), чтобы не терять "8-12";
///  - restSeconds → restSeconds;
///  - sortOrder   — addExercise сам выставляет по порядку добавления.
///
/// AI-заметка по упражнению (note) дописывается к technique, если задана.
Future<void> saveWorkoutProgram(WorkoutsDao dao, WorkoutProgram program) async {
  for (final day in program.days) {
    final workoutId = await dao.createWorkout(day.title);
    for (final ex in day.exercises) {
      // technique сохраняет человекочитаемый диапазон + опциональную заметку,
      // т.к. колонка reps в БД — int и теряет "8-12"/"AMRAP".
      final parts = <String>[
        if (ex.reps.trim().isNotEmpty) ex.reps.trim(),
        if (ex.note != null && ex.note!.trim().isNotEmpty) ex.note!.trim(),
      ];
      final technique = parts.isEmpty ? null : parts.join(' · ');
      await dao.addExercise(
        workoutId: workoutId,
        name: ex.name,
        sets: ex.sets,
        reps: repsToInt(ex.reps),
        restSeconds: ex.restSeconds,
        technique: technique,
      );
    }
  }
}
