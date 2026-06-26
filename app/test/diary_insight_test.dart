// Юнит-тесты бесплатного инсайта дневника (чистая логика).
// §3b: mergedMoodAvg — объединение diary (day_logs) + meditation (mood_logs).

import 'package:app/features/diary/diary_insight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildWeeklyInsight', () {
    test('empty when nothing to report', () {
      final insight = buildWeeklyInsight(
        mainTotal: 0,
        mainDone: 0,
        streak: 0,
        moodAvg: null,
        topIssueLabel: null,
      );
      expect(insight.isEmpty, isTrue);
    });

    test('reports completion, streak, blocker and mood', () {
      final insight = buildWeeklyInsight(
        mainTotal: 5,
        mainDone: 3,
        streak: 2,
        moodAvg: 4.0,
        topIssueLabel: 'social media',
      );
      expect(insight.lines.length, 4);
      expect(insight.lines[0], contains('3 of 5'));
      expect(insight.lines[0], contains('60%'));
      expect(insight.lines.any((l) => l.contains('2-day streak')), isTrue);
      expect(insight.lines.any((l) => l.contains('social media')), isTrue);
      expect(insight.lines.any((l) => l.contains('mood')), isTrue);
    });

    test('omits lines with no data', () {
      final insight = buildWeeklyInsight(
        mainTotal: 2,
        mainDone: 2,
        streak: 0,
        moodAvg: null,
        topIssueLabel: null,
      );
      expect(insight.lines.length, 1);
      expect(insight.lines.single, contains('100%'));
    });
  });

  group('mergedMoodAvg (§3b — mood_logs + day_logs aggregation)', () {
    test('returns null when both lists are empty', () {
      expect(mergedMoodAvg([], []), isNull);
    });

    test('meditation mood (source=meditation) is included in the average', () {
      // Только медитационное настроение — попадает в агрегацию
      expect(mergedMoodAvg([], [4, 5]), closeTo(4.5, 0.01));
    });

    test('diary mood from day_logs is included', () {
      expect(mergedMoodAvg([3], []), closeTo(3.0, 0.01));
    });

    test('diary + meditation are averaged together correctly', () {
      // 2 дневниковых + 2 медитационных: (2+4+4+2)/4 = 3.0
      expect(mergedMoodAvg([2, 4], [4, 2]), closeTo(3.0, 0.01));
    });

    test('meditation check-in raises avg when diary mood is low', () {
      // Плохое дневниковое настроение + хорошая медитация → точнее среднее
      expect(mergedMoodAvg([1], [5]), closeTo(3.0, 0.01));
    });

    test('single meditation entry produces correct avg without diary data', () {
      expect(mergedMoodAvg([], [3]), closeTo(3.0, 0.01));
    });
  });

  group('parseIssueKeys', () {
    test('extracts known issue tags from note suffix', () {
      const note = 'Tired all day\n\nIssues: social_media, was_tired';
      expect(parseIssueKeys(note), ['social_media', 'was_tired']);
    });

    test('returns empty for plain note or null', () {
      expect(parseIssueKeys('just a normal note'), isEmpty);
      expect(parseIssueKeys(null), isEmpty);
    });

    test('ignores unknown tags', () {
      const note = 'x\n\nIssues: social_media, bogus_tag';
      expect(parseIssueKeys(note), ['social_media']);
    });
  });
}
