// Тест C3: после явного logout все пользовательские данные очищаются из Drift.
// Проверяем AppDatabase.clearAllUserData() напрямую — именно его вызывает
// AuthController.logout() после инвалидации токена.
// In-memory NativeDatabase — чистый Dart, без Flutter-зависимостей.

import 'package:app/core/database/database.dart';
import 'package:drift/drift.dart' show HasResultSet, ResultSetImplementation, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // Хелпер: считает строки через select().get().length
  Future<int> count<T extends HasResultSet, D>(
    ResultSetImplementation<T, D> table,
  ) async =>
      (await db.select(table).get()).length;

  test('clearAllUserData: ключевые таблицы пусты после очистки', () async {
    final now = DateTime.now();

    // ── Засеваем данные ──────────────────────────────────────────────────────

    // Задача
    await db.into(db.itemsTable).insert(ItemsTableCompanion.insert(
          id: 'item-1',
          userId: 'local',
          title: 'Test task',
          type: 'task',
          scheduledAt: now,
          createdAt: now,
          updatedAt: now,
        ));

    // Вода
    await db.into(db.waterLogsTable).insert(WaterLogsTableCompanion.insert(
          id: 'water-1',
          amountMl: 250,
          loggedAt: now,
        ));

    // Дневник
    await db.into(db.dayLogsTable).insert(DayLogsTableCompanion.insert(
          id: 'daylog-1',
          date: now,
          createdAt: now,
        ));

    // Привычка + лог (в правильном порядке: родитель → дочерняя FK)
    await db.into(db.habitsTable).insert(HabitsTableCompanion.insert(
          id: 'habit-1',
          name: 'Morning run',
          createdAt: now,
        ));
    await db.into(db.habitLogsTable).insert(HabitLogsTableCompanion.insert(
          id: 'hlog-1',
          habitId: 'habit-1',
          date: now,
        ));

    // Цель + шаг
    await db.into(db.goalsTable).insert(GoalsTableCompanion.insert(
          id: 'goal-1',
          title: 'Learn Dart',
          horizon: 'year',
        ));
    await db.into(db.goalStepsTable).insert(GoalStepsTableCompanion.insert(
          id: 'gstep-1',
          goalId: 'goal-1',
          title: 'Read docs',
        ));

    // Лог настроения
    await db.into(db.moodLogsTable).insert(MoodLogsTableCompanion.insert(
          id: 'mood-1',
          mood: 4,
          loggedAt: now,
        ));

    // Очередь синхронизации
    await db.into(db.syncQueueTable).insert(SyncQueueTableCompanion.insert(
          tableName_: 'items',
          recordId: 'item-1',
          operation: 'create',
          payload: '{}',
          createdAt: now,
        ));

    // ── Убеждаемся, что данные вставлены ─────────────────────────────────────
    expect(await count(db.itemsTable), 1, reason: 'items до очистки');
    expect(await count(db.waterLogsTable), 1, reason: 'water_logs до очистки');
    expect(await count(db.dayLogsTable), 1, reason: 'day_logs до очистки');
    expect(await count(db.habitsTable), 1, reason: 'habits до очистки');
    expect(await count(db.habitLogsTable), 1, reason: 'habit_logs до очистки');
    expect(await count(db.goalsTable), 1, reason: 'goals до очистки');
    expect(await count(db.goalStepsTable), 1, reason: 'goal_steps до очистки');
    expect(await count(db.moodLogsTable), 1, reason: 'mood_logs до очистки');
    expect(await count(db.syncQueueTable), 1, reason: 'sync_queue до очистки');

    // ── Вызываем очистку ─────────────────────────────────────────────────────
    await db.clearAllUserData();

    // ── Все таблицы должны быть пустыми ──────────────────────────────────────
    expect(await count(db.itemsTable), 0, reason: 'items после logout');
    expect(await count(db.waterLogsTable), 0, reason: 'water_logs после logout');
    expect(await count(db.dayLogsTable), 0, reason: 'day_logs после logout');
    expect(await count(db.habitsTable), 0, reason: 'habits после logout');
    expect(await count(db.habitLogsTable), 0, reason: 'habit_logs после logout');
    expect(await count(db.goalsTable), 0, reason: 'goals после logout');
    expect(await count(db.goalStepsTable), 0, reason: 'goal_steps после logout');
    expect(await count(db.moodLogsTable), 0, reason: 'mood_logs после logout');
    expect(await count(db.syncQueueTable), 0, reason: 'sync_queue после logout');
    expect(await count(db.foodLogsTable), 0, reason: 'food_logs после logout');
    expect(await count(db.sleepLogsTable), 0, reason: 'sleep_logs после logout');
    expect(await count(db.workoutsTable), 0, reason: 'workouts после logout');
    expect(await count(db.shoppingItemsTable), 0,
        reason: 'shopping_items после logout');
  });

  test('clearAllUserData: пустая БД не бросает исключений', () async {
    // Повторный вызов на пустой БД — идемпотентность
    await expectLater(db.clearAllUserData(), completes);
    await expectLater(db.clearAllUserData(), completes);
  });

  test('clearAllUserData: streak очищается (одна строка без PK)', () async {
    // StreakTable не имеет явного PK — проверяем отдельно
    await db.into(db.streakTable).insert(const StreakTableCompanion(
          current: Value(5),
          longest: Value(10),
          freezeCount: Value(1),
        ));
    expect(await count(db.streakTable), 1);

    await db.clearAllUserData();

    expect(await count(db.streakTable), 0, reason: 'streak после logout');
  });
}
