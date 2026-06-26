// DAO для таблицы mood_logs — настроение после медитации (и в будущем других
// источников). Локальная таблица (schemaVersion 22), без синхронизации с
// сервером. Используется meditation_mood_log.dart вместо SharedPreferences.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'mood_logs_dao.g.dart';

@DriftAccessor(tables: [MoodLogsTable])
class MoodLogsDao extends DatabaseAccessor<AppDatabase>
    with _$MoodLogsDaoMixin {
  MoodLogsDao(super.db);

  /// Вставить запись настроения. Возвращает сгенерированный id.
  Future<String> insertMood({
    required int mood,
    required DateTime loggedAt,
    String source = 'meditation',
    String? sessionId,
    String? note,
  }) async {
    final id = uuidV4();
    await into(moodLogsTable).insert(
      MoodLogsTableCompanion(
        id: Value(id),
        mood: Value(mood),
        loggedAt: Value(loggedAt),
        source: Value(source),
        sessionId: Value(sessionId),
        note: Value(note),
        createdAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  /// Все записи начиная с [from] (включительно), по возрастанию loggedAt.
  /// Используется инсайт-модулем (§3b) для агрегации настроения за период.
  Future<List<MoodLogsTableData>> getSince(DateTime from) {
    return (select(moodLogsTable)
          ..where((t) => t.loggedAt.isBiggerOrEqualValue(from))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .get();
  }

  /// Реактивный стрим записей начиная с [from] (обновляется при каждой вставке).
  /// Предназначен для будущего экрана истории настроений / виджетов дашборда.
  Stream<List<MoodLogsTableData>> watchSince(DateTime from) {
    return (select(moodLogsTable)
          ..where((t) => t.loggedAt.isBiggerOrEqualValue(from))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .watch();
  }

  /// Все записи за [source] (например 'meditation') с [from] включительно.
  /// Удобно для фильтрации по источнику при агрегации инсайтов.
  Future<List<MoodLogsTableData>> getSinceBySource(
    DateTime from,
    String source,
  ) {
    return (select(moodLogsTable)
          ..where(
            (t) =>
                t.loggedAt.isBiggerOrEqualValue(from) &
                t.source.equals(source),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .get();
  }
}
