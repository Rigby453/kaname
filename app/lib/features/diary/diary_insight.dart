// Бесплатный (rule-based) инсайт для дневника — ТЗ C6: «инсайт (rule-based;
// ИИ глубже — paid)». Считается ЛОКАЛЬНО из Drift, без сети и без бэкенда:
// % закрытых главных задач за неделю, текущая серия, главная причина срывов,
// среднее настроение. Премиум-AI-инсайт (глубже) остаётся отдельной кнопкой.
//
// Строки локализуются в UI-слое (DiaryInsightLines.resolve) через context.s(),
// чтобы провайдер оставался без BuildContext.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/day_window.dart';

/// Формат тегов «What went wrong?» в note (зеркалит diary_screen):
/// свободный текст + "\n\nIssues: tag1, tag2".
const String _kIssuesPrefix = '\n\nIssues: ';

/// Ключ тега → ключ локализации для отображаемого имени блокера.
const Map<String, String> _kIssueLabelKeys = {
  'social_media': 'diary.issue_label_social_media',
  'went_out': 'diary.issue_label_went_out',
  'was_tired': 'diary.issue_label_was_tired',
  'sick': 'diary.issue_label_sick',
  'other': 'diary.issue_label_other',
};

/// Ключ тега → человекочитаемая подпись на английском (fallback для парсинга).
const Map<String, String> _kIssueLabels = {
  'social_media': 'social media',
  'went_out': 'going out',
  'was_tired': 'tiredness',
  'sick': 'feeling sick',
  'other': 'other',
};

const List<String> _kMoodEmojis = ['😞', '😕', '😐', '🙂', '😄'];

/// Сырые данные для недельного инсайта (без строк — строки резолвятся в UI).
class WeeklyInsightData {
  const WeeklyInsightData({
    required this.mainTotal,
    required this.mainDone,
    required this.streak,
    this.moodAvg,
    this.topIssueKey,
  });

  final int mainTotal;
  final int mainDone;
  final int streak;
  final double? moodAvg;
  /// Ключ тега (e.g. 'social_media') или null если нет данных.
  final String? topIssueKey;

  bool get isEmpty => mainTotal == 0 && streak == 0 && moodAvg == null;

  /// Резолвит строки через context.s() и возвращает готовый список строк.
  List<String> resolve(BuildContext context) {
    final lines = <String>[];

    if (mainTotal > 0) {
      final pct = ((mainDone / mainTotal) * 100).round();
      lines.add(
        context.s('diary.weekly_tasks')
            .replaceAll('{done}', '$mainDone')
            .replaceAll('{total}', '$mainTotal')
            .replaceAll('{pct}', '$pct'),
      );
    }

    if (streak > 0) {
      lines.add(
        context.s('diary.weekly_streak').replaceAll('{streak}', '$streak'),
      );
    }

    if (topIssueKey != null) {
      final labelKey = _kIssueLabelKeys[topIssueKey!];
      final label = labelKey != null ? context.s(labelKey) : topIssueKey!;
      lines.add(
        context.s('diary.weekly_blocker').replaceAll('{label}', label),
      );
    }

    if (moodAvg != null) {
      final idx = (moodAvg!.round() - 1).clamp(0, _kMoodEmojis.length - 1);
      lines.add(
        context.s('diary.weekly_mood')
            .replaceAll('{emoji}', _kMoodEmojis[idx])
            .replaceAll('{avg}', moodAvg!.toStringAsFixed(1)),
      );
    }

    return lines;
  }
}

/// Результат инсайта: список коротких строк (пусто = показывать нечего).
/// Используется в _QuickInsightCard после резолва строк.
class DiaryInsight {
  const DiaryInsight(this.lines);
  final List<String> lines;
  bool get isEmpty => lines.isEmpty;
}

/// Совместимая функция для юнит-тестов: строит инсайт на английском без BuildContext.
/// В продакшн UI используйте WeeklyInsightData.resolve(context) для локализации.
DiaryInsight buildWeeklyInsight({
  required int mainTotal,
  required int mainDone,
  required int streak,
  double? moodAvg,
  String? topIssueLabel,
}) {
  final lines = <String>[];

  if (mainTotal > 0) {
    final pct = ((mainDone / mainTotal) * 100).round();
    lines.add('Closed $mainDone of $mainTotal main tasks this week ($pct%).');
  }

  if (streak > 0) {
    lines.add('🔥 $streak-day streak — keep it going.');
  }

  if (topIssueLabel != null) {
    lines.add('Most common blocker lately: $topIssueLabel.');
  }

  if (moodAvg != null) {
    final idx = (moodAvg.round() - 1).clamp(0, _kMoodEmojis.length - 1);
    lines.add('Average mood: ${_kMoodEmojis[idx]} (${moodAvg.toStringAsFixed(1)}/5).');
  }

  return DiaryInsight(lines);
}

/// Парсит теги Issues из note (тот же формат, что пишет diary_screen).
List<String> parseIssueKeys(String? note) {
  if (note == null) return const [];
  final idx = note.indexOf(_kIssuesPrefix);
  if (idx == -1) return const [];
  final tagsPart = note.substring(idx + _kIssuesPrefix.length);
  return [
    for (final raw in tagsPart.split(','))
      if (_kIssueLabels.containsKey(raw.trim())) raw.trim(),
  ];
}

/// План vs факт за сегодня (SPEC C6).
class PlanVsFact {
  const PlanVsFact({
    required this.planned,
    required this.done,
    required this.skipped,
  });
  final int planned;
  final int done;
  final int skipped;

  bool get isEmpty => planned == 0;
}

/// Провайдер плана/факта на сегодня (реактивно из Drift).
final todayPlanVsFactProvider =
    StreamProvider.autoDispose<PlanVsFact>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now()).map(
    (items) => PlanVsFact(
      planned: items.length,
      done: items.where((i) => i.status == 'done').length,
      skipped: items.where((i) => i.status == 'skipped').length,
    ),
  );
});

/// Объединяет настроения из дневника (day_logs) и медитаций (mood_logs)
/// и вычисляет среднее. Возвращает null, если данных нет.
/// [diaryMoods] — значения 1-5 из day_logs.mood (не null),
/// [meditationMoods] — значения 1-5 из mood_logs WHERE source='meditation'.
/// Дневниковые данные из mood_logs(source='diary') намеренно исключены —
/// они дублируют day_logs.mood, что приведёт к двойному счёту.
double? mergedMoodAvg(List<int> diaryMoods, List<int> meditationMoods) {
  final all = [...diaryMoods, ...meditationMoods];
  if (all.isEmpty) return null;
  return all.reduce((a, b) => a + b) / all.length;
}

/// Провайдер: собирает локальные данные за последние 7 дней.
/// Возвращает WeeklyInsightData (без строк). Строки резолвятся в _QuickInsightCard.
final weeklyDiaryInsightProvider =
    FutureProvider.autoDispose<WeeklyInsightData>((ref) async {
  final now = DateTime.now();
  // Локальная полночь для оконного запроса items (как watchTodayItems).
  final todayStart = localDayStart(now);
  final weekStart = todayStart.subtract(const Duration(days: 6));
  final weekEnd = todayStart.add(const Duration(days: 1));

  // Главные задачи за неделю
  final items =
      await ref.read(itemsDaoProvider).itemsInRange(weekStart, weekEnd);
  final main = items.where((i) => i.priority == 'main').toList();
  final mainDone = main.where((i) => i.status == 'done').length;

  // Серия
  final streak = await ref.read(streakDaoProvider).getStreak();

  // Записи дневника за неделю: настроение + причины срывов
  final logs = await ref.read(dayLogsDaoProvider).since(weekStart);

  // Настроение: day_logs (дневник) + mood_logs(source='meditation').
  // Медитационные чек-ины учитываются вместе с дневниковым настроением,
  // что даёт более точную недельную картину самочувствия.
  final diaryMoods = [for (final l in logs) if (l.mood != null) l.mood!];
  final moodLogs =
      await ref.read(moodLogsDaoProvider).getSince(weekStart);
  final meditationMoods = moodLogs
      .where((m) => m.source == 'meditation')
      .map((m) => m.mood)
      .toList();
  final double? moodAvg = mergedMoodAvg(diaryMoods, meditationMoods);

  // Самая частая причина срывов (возвращаем ключ, не строку)
  final counts = <String, int>{};
  for (final l in logs) {
    for (final key in parseIssueKeys(l.note)) {
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  String? topIssueKey;
  if (counts.isNotEmpty) {
    topIssueKey =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  return WeeklyInsightData(
    mainTotal: main.length,
    mainDone: mainDone,
    streak: streak?.current ?? 0,
    moodAvg: moodAvg,
    topIssueKey: topIssueKey,
  );
});
