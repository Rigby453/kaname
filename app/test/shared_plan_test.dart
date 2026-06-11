// Юнит-тесты для extractShareToken (SPEC C7, Ф3, v1).
// Проверяем: полный URL, голый токен, URL с query, пустая строка.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/profile/shared_plan.dart';

void main() {
  group('extractShareToken', () {
    test('полный URL с токеном → возвращает токен', () {
      const url = 'https://example.com/share/abc123xyz';
      expect(extractShareToken(url), 'abc123xyz');
    });

    test('http URL с токеном → возвращает токен', () {
      const url = 'http://localhost:3000/share/tok-456-def';
      expect(extractShareToken(url), 'tok-456-def');
    });

    test('голый токен (без URL) → возвращает его же', () {
      expect(extractShareToken('plaintoken'), 'plaintoken');
    });

    test('голый токен с пробелами — trim → возвращает токен', () {
      expect(extractShareToken('  tok123  '), 'tok123');
    });

    test('URL с query-параметром → обрезает query, возвращает только токен', () {
      const url = 'https://app.kaizen.io/share/mytoken?ref=social&utm=1';
      expect(extractShareToken(url), 'mytoken');
    });

    test('URL с anchor (#) → обрезает anchor', () {
      const url = 'https://app.kaizen.io/share/tokenABC#section';
      expect(extractShareToken(url), 'tokenABC');
    });

    test('пустая строка → null', () {
      expect(extractShareToken(''), isNull);
    });

    test('строка только из пробелов → null', () {
      expect(extractShareToken('   '), isNull);
    });

    test('URL без пути /share/ → возвращает всю строку (trim)', () {
      const url = 'https://example.com/other/path';
      expect(extractShareToken(url), 'https://example.com/other/path');
    });
  });
}
