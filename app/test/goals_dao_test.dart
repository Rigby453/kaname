// Unit-тесты для GoalsDao и goalProgress (SPEC C4).
// In-memory Drift — без Flutter-зависимостей, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/goals_dao.dart';
import 'package:app/features/plan/goal_progress.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GoalsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = GoalsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Цели
  // ---------------------------------------------------------------------------

  test('createGoal → watchGoals возвращает цель', () async {
    final id = await dao.createGoal('Learn Spanish', 'year');
    final all = await dao.watchGoals().first;
    expect(all, hasLength(1));
    expect(all.single.id, id);
    expect(all.single.title, 'Learn Spanish');
    expect(all.single.horizon, 'year');
  });

  test('watchGoals сортирует по updatedAt desc (свежие первыми)', () async {
    final id1 = await dao.createGoal('Goal A', 'month');
    // Drift хранит DateTime с точностью до секунды — ждём >1s для детерминированного порядка
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final id2 = await dao.createGoal('Goal B', 'year');

    final all = await dao.watchGoals().first;
    expect(all, hasLength(2));
    // Свежая (id2) первой
    expect(all.first.id, id2);
    expect(all.last.id, id1);
  });

  test('renameGoal меняет title и сдвигает updatedAt', () async {
    final id = await dao.createGoal('Old title', 'month');
    final before = (await dao.watchGoals().first).single.updatedAt;

    // Drift хранит DateTime с точностью до секунды
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await dao.renameGoal(id, 'New title');

    final goal = (await dao.watchGoals().first).single;
    expect(goal.title, 'New title');
    expect(goal.updatedAt.isBefore(before), isFalse);
  });

  // ---------------------------------------------------------------------------
  // Шаги
  // ---------------------------------------------------------------------------

  test('addStep сохраняет порядок добавления (sortOrder)', () async {
    final goalId = await dao.createGoal('Fitness', 'five_years');
    await dao.addStep(goalId, 'Run 5k');
    await dao.addStep(goalId, 'Run 10k');
    await dao.addStep(goalId, 'Run half-marathon');

    final steps = await dao.watchSteps(goalId).first;
    expect(steps, hasLength(3));
    expect(steps[0].title, 'Run 5k');
    expect(steps[0].sortOrder, 0);
    expect(steps[1].title, 'Run 10k');
    expect(steps[1].sortOrder, 1);
    expect(steps[2].title, 'Run half-marathon');
    expect(steps[2].sortOrder, 2);
  });

  test('setStepDone меняет флаг и сдвигает updatedAt цели', () async {
    final goalId = await dao.createGoal('Read more', 'year');
    await dao.addStep(goalId, 'Read 12 books');
    final step = (await dao.watchSteps(goalId).first).single;
    expect(step.done, isFalse);

    final before = (await dao.watchGoals().first).single.updatedAt;
    // Drift хранит DateTime с точностью до секунды
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    await dao.setStepDone(step.id, true);

    final updated = (await dao.watchSteps(goalId).first).single;
    expect(updated.done, isTrue);

    final goalAfter = (await dao.watchGoals().first).single.updatedAt;
    expect(goalAfter.isBefore(before), isFalse);
  });

  test('deleteGoal каскадно удаляет шаги, не трогает другие цели', () async {
    final id1 = await dao.createGoal('Goal 1', 'month');
    await dao.addStep(id1, 'Step A');
    await dao.addStep(id1, 'Step B');

    final id2 = await dao.createGoal('Goal 2', 'ten_years');
    await dao.addStep(id2, 'Step C');

    await dao.deleteGoal(id1);

    // Первая цель удалена
    final remaining = await dao.watchGoals().first;
    expect(remaining, hasLength(1));
    expect(remaining.single.id, id2);

    // Шаги первой цели удалены
    expect(await dao.watchSteps(id1).first, isEmpty);

    // Шаги второй цели целы
    expect(await dao.watchSteps(id2).first, hasLength(1));
  });

  test('removeStep удаляет только указанный шаг', () async {
    final goalId = await dao.createGoal('Study', 'year');
    await dao.addStep(goalId, 'Chapter 1');
    await dao.addStep(goalId, 'Chapter 2');

    final steps = await dao.watchSteps(goalId).first;
    await dao.removeStep(steps.first.id);

    final remaining = await dao.watchSteps(goalId).first;
    expect(remaining, hasLength(1));
    expect(remaining.single.title, 'Chapter 2');
  });

  // ---------------------------------------------------------------------------
  // goalProgress — чистая функция
  // ---------------------------------------------------------------------------

  test('goalProgress: нет шагов → 0.0', () async {
    final goalId = await dao.createGoal('Empty goal', 'month');
    final steps = await dao.watchSteps(goalId).first;
    expect(goalProgress(steps), 0.0);
  });

  test('goalProgress: все выполнены → 1.0', () async {
    final goalId = await dao.createGoal('Done goal', 'year');
    await dao.addStep(goalId, 'Step 1');
    await dao.addStep(goalId, 'Step 2');
    final steps = await dao.watchSteps(goalId).first;
    await dao.setStepDone(steps[0].id, true);
    await dao.setStepDone(steps[1].id, true);

    final fresh = await dao.watchSteps(goalId).first;
    expect(goalProgress(fresh), 1.0);
  });

  test('goalProgress: частичное выполнение → дробь', () async {
    final goalId = await dao.createGoal('Partial goal', 'five_years');
    await dao.addStep(goalId, 'A');
    await dao.addStep(goalId, 'B');
    await dao.addStep(goalId, 'C');
    await dao.addStep(goalId, 'D');
    final steps = await dao.watchSteps(goalId).first;
    // Отмечаем 1 из 4
    await dao.setStepDone(steps[0].id, true);

    final fresh = await dao.watchSteps(goalId).first;
    expect(goalProgress(fresh), closeTo(0.25, 0.001));
  });
}
