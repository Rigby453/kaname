// Юнит-тесты бесплатного инсайта дневника (чистая логика).

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
