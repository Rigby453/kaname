// Юнит-тесты чистой логики недавних предметов (mergeRecent).

import 'package:app/core/settings/recent_subjects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeRecent', () {
    test('adds new title to the front', () {
      expect(mergeRecent(['Math', 'Physics'], 'CS'), ['CS', 'Math', 'Physics']);
    });

    test('moves existing title to front (case-insensitive dedup)', () {
      expect(mergeRecent(['Math', 'Physics'], 'physics'),
          ['physics', 'Math']);
    });

    test('trims and ignores empty/whitespace titles', () {
      expect(mergeRecent(['Math'], '  '), ['Math']);
      expect(mergeRecent(['Math'], '  CS  '), ['CS', 'Math']);
    });

    test('caps the list length', () {
      final current = List.generate(8, (i) => 'S$i');
      final out = mergeRecent(current, 'New', cap: 8);
      expect(out.length, 8);
      expect(out.first, 'New');
      expect(out.contains('S7'), isFalse); // самый старый вытеснен
    });
  });
}
