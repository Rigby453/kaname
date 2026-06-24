// Unit-тесты HabitsDao + computeHabitStats (стрик/история привычек).
// In-memory Drift — чистый Dart, без Flutter-зависимостей.
//
// computeHabitStats тестируется напрямую (чистая функция, карта дни→count) —
// детерминированно, без зависимости от системного времени.
// DAO-методы (logHabit, dayCountsForHabit, watchStats) проверяются на БД.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/habits_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late HabitsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = HabitsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Хелпер: «сегодня» в UTC-полночь для детерминированных дат.
  final now = DateTime.utc(2026, 6, 24);
  String key(DateTime d) => dayKey(d);
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));

  // ---------------------------------------------------------------------------
  // computeHabitStats — good-привычка
  // ---------------------------------------------------------------------------

  group('computeHabitStats good', () {
    test('последовательные дни с целью → стрик N', () {
      // Сегодня и 3 дня до — выполнено (target=1).
      final counts = {
        for (var i = 0; i < 4; i++) key(daysAgo(i)): 1,
      };
      final s = computeHabitStats(
        dayCounts: counts,
        type: 'good',
        targetPerDay: 1,
        now: now,
      );
      expect(s.currentStreak, 4);
      expect(s.bestStreak, 4);
      expect(s.totalCompletions, 4);
    });

    test('разрыв в днях → текущий стрик сбрасывается', () {
      // Выполнено сегодня и вчера, потом пропуск, потом ещё 3 дня.
      final counts = {
        key(daysAgo(0)): 1,
        key(daysAgo(1)): 1,
        // daysAgo(2) пропущен — разрыв
        key(daysAgo(3)): 1,
        key(daysAgo(4)): 1,
        key(daysAgo(5)): 1,
      };
      final s = computeHabitStats(
        dayCounts: counts,
        type: 'good',
        targetPerDay: 1,
        now: now,
      );
      // Текущий стрик — только сегодня+вчера.
      expect(s.currentStreak, 2);
      // Лучший — серия из 3 дней (daysAgo 3..5).
      expect(s.bestStreak, 3);
      expect(s.totalCompletions, 5);
    });

    test('сегодня не отмечено, но вчера было → стрик держится со вчера', () {
      final counts = {
        key(daysAgo(1)): 1,
        key(daysAgo(2)): 1,
      };
      final s = computeHabitStats(
        dayCounts: counts,
        type: 'good',
        targetPerDay: 1,
        now: now,
      );
      expect(s.currentStreak, 2);
    });

    test('count ниже target не засчитывается в стрик', () {
      final counts = {
        key(daysAgo(0)): 2, // выполнено (target=2)
        key(daysAgo(1)): 1, // недотянуто
        key(daysAgo(2)): 2,
      };
      final s = computeHabitStats(
        dayCounts: counts,
        type: 'good',
        targetPerDay: 2,
        now: now,
      );
      // Стрик прерывается на дне с count=1.
      expect(s.currentStreak, 1);
      expect(s.totalCompletions, 2); // два дня достигли цели
    });

    test('пустая история → нули', () {
      final s = computeHabitStats(
        dayCounts: {},
        type: 'good',
        targetPerDay: 1,
        now: now,
      );
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 0);
      expect(s.totalCompletions, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // computeHabitStats — bad-привычка (дней без срыва)
  // ---------------------------------------------------------------------------

  group('computeHabitStats bad', () {
    test('без логов вообще → стрик чистоты 0', () {
      final s = computeHabitStats(
        dayCounts: {},
        type: 'bad',
        targetPerDay: 1,
        now: now,
      );
      expect(s.daysClean, 0);
      expect(s.currentStreak, 0);
      expect(s.totalCompletions, 0);
    });

    test('последний срыв 3 дня назад → 3 дня без срыва', () {
      final counts = {
        key(daysAgo(3)): 1, // срыв 3 дня назад
      };
      final s = computeHabitStats(
        dayCounts: counts,
        type: 'bad',
        targetPerDay: 1,
        now: now,
      );
      // Сегодня, вчера, позавчера — чисто.
      expect(s.daysClean, 3);
      expect(s.currentStreak, 3);
      expect(s.totalCompletions, 1);
    });

    test('срыв сегодня → стрик чистоты сброшен в 0', () {
      final counts = {
        key(daysAgo(0)): 2, // два срыва сегодня
        key(daysAgo(5)): 1,
      };
      final s = computeHabitStats(
        dayCounts: counts,
        type: 'bad',
        targetPerDay: 1,
        now: now,
      );
      expect(s.daysClean, 0);
      // Всего нарушений — сумма count.
      expect(s.totalCompletions, 3);
      // Лучшая серия чистых дней — между двумя срывами (daysAgo 5 → 0): дни 4..1 = 4.
      expect(s.bestStreak, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // DAO — logHabit / dayCountsForHabit / watchStats
  // ---------------------------------------------------------------------------

  group('HabitsDao', () {
    test('logHabit пишет лог, dayCountsForHabit агрегирует по дню', () async {
      await dao.createHabit(name: 'Water', type: 'good');
      final habit = (await dao.watchActive().first).single;

      await dao.logHabit(habit.id);
      await dao.logHabit(habit.id, count: 2);

      final counts = await dao.dayCountsForHabit(habit.id);
      expect(counts.values.fold<int>(0, (a, b) => a + b), 3);
      // Один день (сегодня) — один ключ.
      expect(counts.keys, hasLength(1));
    });

    test('watchStats: после двух логов good с target=1 → стрик 1', () async {
      await dao.createHabit(name: 'Read', type: 'good');
      final habit = (await dao.watchActive().first).single;

      await dao.logHabit(habit.id);
      await dao.logHabit(habit.id);

      final stats = await dao.watchStats(habit).first;
      // Оба лога — сегодня → стрик 1 день.
      expect(stats.currentStreak, 1);
      expect(stats.totalCompletions, 1);
    });

    test('statsForHabit для bad без логов → 0 нарушений', () async {
      await dao.createHabit(name: 'No sugar', type: 'bad');
      final habit = (await dao.watchActive().first).single;

      final stats = await dao.statsForHabit(habit);
      expect(stats.totalCompletions, 0);
      expect(stats.daysClean, 0);
    });
  });
}
