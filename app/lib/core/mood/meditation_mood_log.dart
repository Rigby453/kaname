// Хранилище настроения после медитации — Drift-таблица mood_logs.
//
// Ранее использовалась SharedPreferences ('meditation_mood_logs'), перенесено
// в Drift (schemaVersion 22) чтобы инсайт-модуль мог читать данные через DAO.
//
// Запись ПОЛНОСТЬЮ независима от DayLogsTable.mood (дневник).
// Дневник управляет своим mood отдельно через DayLogsDao.saveForDate —
// этот модуль его НИКОГДА не трогает.
//
// SharedPreferences-ключ 'meditation_mood_logs' не удаляется (beta-данные
// остаются нетронутыми), но этот модуль его больше не читает и не пишет.

import '../database/daos/mood_logs_dao.dart';

/// Одна запись настроения после медитационной сессии.
/// Модель используется UI (диалог завершения медитации) независимо от слоя БД.
class MeditationMoodEntry {
  const MeditationMoodEntry({
    required this.sessionId,
    required this.mood,
    required this.loggedAt,
    this.note,
  });

  /// ID сессии медитации (например 'body_scan').
  final String sessionId;

  /// Настроение 1..5 (совпадает с эмодзи-шкалой дневника).
  final int mood;

  /// Необязательная заметка.
  final String? note;

  /// Момент завершения сессии.
  final DateTime loggedAt;
}

/// Добавить запись настроения в Drift-таблицу mood_logs.
/// Вызывается один раз при нажатии «Done» в диалоге завершения медитации.
///
/// [dao] — MoodLogsDao, полученный через ref.read(moodLogsDaoProvider).
/// Дневник ([DayLogsTable.mood]) остаётся неизменным.
///
/// Защита от ошибок: функция не бросает исключений — все ошибки
/// поглощаются (UI не краш), но могут быть залогированы.
Future<void> appendMeditationMood(
  MoodLogsDao dao,
  MeditationMoodEntry entry,
) async {
  try {
    await dao.insertMood(
      mood: entry.mood,
      loggedAt: entry.loggedAt,
      source: 'meditation',
      sessionId: entry.sessionId,
      note: entry.note,
    );
  } catch (_) {
    // БД недоступна или другая ошибка — не крашим UI, просто игнорируем.
  }
}

/// Прочитать все записи настроения начиная с [since] (для аналитики / истории).
/// Возвращает список MeditationMoodEntry, отсортированный по loggedAt asc.
Future<List<MeditationMoodEntry>> readMeditationMoodLogs(
  MoodLogsDao dao, {
  DateTime? since,
}) async {
  try {
    final from = since ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rows = await dao.getSinceBySource(from, 'meditation');
    return rows
        .map(
          (r) => MeditationMoodEntry(
            sessionId: r.sessionId ?? '',
            mood: r.mood,
            note: r.note,
            loggedAt: r.loggedAt,
          ),
        )
        .toList();
  } catch (_) {
    // Повреждённые данные или закрытая БД → пустой список (никогда не крашим).
    return const [];
  }
}
