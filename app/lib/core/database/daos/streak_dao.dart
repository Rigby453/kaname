// DAO для таблицы streaks
// MVP: одна строка на приложение (userId = 'local')
// Читается StreakRow виджетом через Riverpod

import 'package:drift/drift.dart';

import '../database.dart';

part 'streak_dao.g.dart';

@DriftAccessor(tables: [StreakTable])
class StreakDao extends DatabaseAccessor<AppDatabase> with _$StreakDaoMixin {
  StreakDao(super.db);

  /// Нормализует прочитанную строку: Drift по умолчанию хранит DateTime как
  /// unix-epoch и при чтении декодирует его как ЛОКАЛЬНЫЙ DateTime
  /// (isUtc=false), даже если изначально был записан DateTime.utc(...) — сам
  /// момент времени (epoch) не искажается, но флаг зоны и, следовательно,
  /// печатаемые часы/минуты «съезжают» на локальный offset (например,
  /// 00:00 UTC на Europe/Moscow читается назад как 03:00). StreakService
  /// хранит lastCompletedDate как «UTC-релейбл» маркер календарного дня
  /// (см. _dayMarker), поэтому здесь и восстанавливаем эту гарантию:
  /// .toUtc() на same-instant DateTime не меняет момент, но возвращает
  /// исходные Y/M/D в UTC и делает объект снова `==`-сравнимым с
  /// DateTime.utc(...), как ожидают вызывающие (см. streak_service_test.dart).
  StreakTableData? _normalize(StreakTableData? row) {
    if (row == null || row.lastCompletedDate == null) return row;
    return row.copyWith(
      lastCompletedDate: Value(row.lastCompletedDate!.toUtc()),
    );
  }

  /// Реактивное чтение единственной строки streak (или null, если ещё нет)
  Stream<StreakTableData?> watchStreak() {
    return (select(streakTable)).watchSingleOrNull().map(_normalize);
  }

  /// Получить streak один раз (для синхронных проверок)
  Future<StreakTableData?> getStreak() async {
    return _normalize(await (select(streakTable)).getSingleOrNull());
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
