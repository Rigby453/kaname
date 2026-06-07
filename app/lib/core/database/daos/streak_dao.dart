// DAO для таблицы streaks
// MVP: одна строка на приложение (userId = 'local')
// Читается StreakRow виджетом через Riverpod

import 'package:drift/drift.dart';

import '../database.dart';

part 'streak_dao.g.dart';

@DriftAccessor(tables: [StreakTable])
class StreakDao extends DatabaseAccessor<AppDatabase> with _$StreakDaoMixin {
  StreakDao(super.db);

  /// Реактивное чтение единственной строки streak (или null, если ещё нет)
  Stream<StreakTableData?> watchStreak() {
    return (select(streakTable)).watchSingleOrNull();
  }

  /// Получить streak один раз (для синхронных проверок)
  Future<StreakTableData?> getStreak() {
    return (select(streakTable)).getSingleOrNull();
  }

  /// Создать первую строку, если её нет; вернуть существующую
  Future<StreakTableData> getOrCreate() async {
    final existing = await getStreak();
    if (existing != null) return existing;

    await into(streakTable).insert(
      const StreakTableCompanion(
        current: Value(0),
        longest: Value(0),
        freezeCount: Value(0),
      ),
    );
    return (await getStreak())!;
  }

  /// Обновить streak-данные
  Future<void> updateStreak(StreakTableCompanion companion) async {
    // streakTable не имеет явного PK кроме rowid, обновляем всю таблицу
    await update(streakTable).write(companion);
  }
}
