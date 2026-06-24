// Unit-тесты для дневника подходов (Feature B, set-by-set diary).
// In-memory Drift — без Flutter-зависимостей, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WorkoutsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = WorkoutsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('logSet вставляет строку с корректными полями', () async {
    await dao.logSet(
      sessionId: 's1',
      exerciseId: 'e1',
      setIndex: 0,
      reps: 12,
      weightKg: 50.0,
    );

    final sets = await dao.watchSessionSets('s1').first;
    expect(sets, hasLength(1));
    final row = sets.single;
    expect(row.sessionId, 's1');
    expect(row.exerciseId, 'e1');
    expect(row.setIndex, 0);
    expect(row.reps, 12);
    expect(row.weightKg, 50.0);
    expect(row.completedAt, isNotNull);
  });

  test('weightKg null обрабатывается (bodyweight)', () async {
    await dao.logSet(
      sessionId: 's1',
      exerciseId: 'e1',
      setIndex: 0,
      reps: 15,
    );

    final sets = await dao.watchSessionSets('s1').first;
    expect(sets.single.weightKg, isNull);
    expect(sets.single.reps, 15);
  });

  test('watchSessionSets возвращает только подходы своей сессии, по порядку',
      () async {
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 1, reps: 8);
    // Чужая сессия — не должна попасть в выборку s1.
    await dao.logSet(sessionId: 's2', exerciseId: 'e1', setIndex: 0, reps: 5);

    final sets = await dao.watchSessionSets('s1').first;
    expect(sets, hasLength(2));
    // Старые первыми (completedAt asc)
    expect(sets[0].setIndex, 0);
    expect(sets[0].reps, 10);
    expect(sets[1].setIndex, 1);
    expect(sets[1].reps, 8);
  });

  test(
      'watchExerciseHistory собирает подходы упражнения через сессии, свежие первыми',
      () async {
    // Старая сессия
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10);
    // Drift хранит DateTime с точностью до секунды — разводим по секундам.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    // Новая сессия, то же упражнение
    await dao.logSet(sessionId: 's2', exerciseId: 'e1', setIndex: 0, reps: 12);
    // Другое упражнение — не должно попасть
    await dao.logSet(sessionId: 's2', exerciseId: 'e2', setIndex: 0, reps: 20);

    final history = await dao.watchExerciseHistory('e1').first;
    expect(history, hasLength(2));
    // Свежие первыми (completedAt desc): s2 раньше s1 в списке
    expect(history[0].sessionId, 's2');
    expect(history[0].reps, 12);
    expect(history[1].sessionId, 's1');
    expect(history[1].reps, 10);
  });

  test('getExerciseHistory совпадает с реактивной выборкой', () async {
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10);
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 1, reps: 9);

    final oneShot = await dao.getExerciseHistory('e1');
    expect(oneShot, hasLength(2));
    expect(oneShot.every((r) => r.exerciseId == 'e1'), isTrue);
  });

  test(
      'watchExercisesWithLogs возвращает уникальные упражнения с логами, '
      'свежие первыми, с именем из шаблона', () async {
    // Сидим два упражнения с известными id (для join по имени).
    final wId = await dao.createWorkout('Push Day');
    await db.into(db.workoutExercisesTable).insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'e1',
            workoutId: wId,
            name: 'Bench Press',
          ),
        );
    await db.into(db.workoutExercisesTable).insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'e2',
            workoutId: wId,
            name: 'Squat',
          ),
        );

    // e1 — два подхода (должно схлопнуться в одну запись).
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10);
    // Drift хранит время с точностью до секунды — разводим по секундам,
    // чтобы e2 был свежее e1.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await dao.logSet(sessionId: 's1', exerciseId: 'e1', setIndex: 1, reps: 8);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await dao.logSet(sessionId: 's2', exerciseId: 'e2', setIndex: 0, reps: 5);

    final result = await dao.watchExercisesWithLogs().first;
    // Два уникальных упражнения, e2 свежее → первым.
    expect(result, hasLength(2));
    expect(result[0].exerciseId, 'e2');
    expect(result[0].name, 'Squat');
    expect(result[1].exerciseId, 'e1');
    expect(result[1].name, 'Bench Press');
  });

  test('watchExercisesWithLogs пустой, если логов нет', () async {
    final result = await dao.watchExercisesWithLogs().first;
    expect(result, isEmpty);
  });

  test(
      'watchSessionSetGroups группирует подходы сессии по упражнению '
      'с именем из шаблона, чужая сессия не попадает', () async {
    // Два упражнения в шаблоне (для join по имени).
    final wId = await dao.createWorkout('Push Day');
    await db.into(db.workoutExercisesTable).insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'e1',
            workoutId: wId,
            name: 'Bench Press',
          ),
        );
    await db.into(db.workoutExercisesTable).insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'e2',
            workoutId: wId,
            name: 'Overhead Press',
          ),
        );

    // Сессия s1: e1 (два подхода) затем e2 (один подход).
    await dao.logSet(
        sessionId: 's1', exerciseId: 'e1', setIndex: 0, reps: 10, weightKg: 50);
    await dao.logSet(
        sessionId: 's1', exerciseId: 'e1', setIndex: 1, reps: 8, weightKg: 55);
    await dao.logSet(
        sessionId: 's1', exerciseId: 'e2', setIndex: 0, reps: 12);
    // Чужая сессия — не должна попасть в s1.
    await dao.logSet(sessionId: 's2', exerciseId: 'e1', setIndex: 0, reps: 5);

    final groups = await dao.watchSessionSetGroups('s1').first;

    // Две группы упражнений: e1 (2 подхода) и e2 (1 подход).
    expect(groups, hasLength(2));

    final g1 = groups.firstWhere((g) => g.exerciseId == 'e1');
    expect(g1.name, 'Bench Press');
    expect(g1.sets, hasLength(2));
    // Подходы упорядочены по setIndex.
    expect(g1.sets[0].setIndex, 0);
    expect(g1.sets[0].reps, 10);
    expect(g1.sets[0].weightKg, 50);
    expect(g1.sets[1].setIndex, 1);
    expect(g1.sets[1].reps, 8);

    final g2 = groups.firstWhere((g) => g.exerciseId == 'e2');
    expect(g2.name, 'Overhead Press');
    expect(g2.sets, hasLength(1));
    expect(g2.sets.single.reps, 12);
    expect(g2.sets.single.weightKg, isNull); // bodyweight
  });

  test('watchSessionSetGroups: имя = null, если упражнение удалено из шаблона',
      () async {
    // Логируем подход на упражнение, которого нет в workout_exercises.
    await dao.logSet(
        sessionId: 's1', exerciseId: 'ghost', setIndex: 0, reps: 7);

    final groups = await dao.watchSessionSetGroups('s1').first;
    expect(groups, hasLength(1));
    expect(groups.single.exerciseId, 'ghost');
    expect(groups.single.name, isNull);
    expect(groups.single.sets, hasLength(1));
  });

  test('watchSessionSetGroups пустой для неизвестной сессии', () async {
    final groups = await dao.watchSessionSetGroups('nope').first;
    expect(groups, isEmpty);
  });
}
