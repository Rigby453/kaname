// Юнит-тесты чистой функции computeShoppingSuggestions.
// Без БД, без виджетов, без HTTP — только логика частотного анализа.

import 'package:app/features/food/shopping_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Вспомогательный конструктор записи с простой датой.
FoodLogEntry _entry(String name, {int daysAgo = 0}) => FoodLogEntry(
      name: name,
      date: DateTime.now().subtract(Duration(days: daysAgo)),
    );

/// Список из [count] одинаковых записей.
List<FoodLogEntry> _repeat(String name, int count, {int daysAgo = 0}) =>
    List.generate(count, (_) => _entry(name, daysAgo: daysAgo));

void main() {
  group('computeShoppingSuggestions', () {
    // --- Базовый порог частоты ---

    test('продукт с частотой ниже kMinFrequency не попадает в результат', () {
      final logs = _repeat('Apple', kMinFrequency - 1);
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: const {},
      );
      expect(result, isEmpty);
    });

    test('продукт с частотой >= kMinFrequency попадает в результат', () {
      final logs = _repeat('Apple', kMinFrequency);
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: const {},
      );
      expect(result, contains('Apple'));
    });

    // --- Исключение корзины ---

    test('продукт уже в корзине (exact match) исключается', () {
      final logs = _repeat('Milk', kMinFrequency);
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: {'Milk'},
      );
      expect(result, isEmpty);
    });

    test('исключение нечувствительно к регистру', () {
      final logs = _repeat('Bread', kMinFrequency);
      // В корзине «bread» строчными
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: {'bread'},
      );
      expect(result, isEmpty);
    });

    test('в корзине другой продукт — текущий остаётся в предложениях', () {
      final logs = _repeat('Eggs', kMinFrequency);
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: {'Butter'},
      );
      expect(result, contains('Eggs'));
    });

    // --- Нормализация / дедупликация вариантов написания ---

    test('варианты регистра считаются одним продуктом', () {
      final logs = [
        ..._repeat('yogurt', 2),
        ..._repeat('Yogurt', 2),
      ];
      // Итого 4 вхождения → >= kMinFrequency(3)
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: const {},
      );
      expect(result.length, 1);
      // Написание с наибольшим count: по 2 — tie → лексикографически первое
      // 'Yogurt' < 'yogurt' (заглавная буква имеет меньший code point в Unicode),
      // поэтому выигрывает 'Yogurt'
      expect(result.first.toLowerCase(), 'yogurt');
    });

    test('ведущие/хвостовые пробелы нормализуются', () {
      final logs = [
        _entry('  Rice  '),
        _entry(' Rice'),
        _entry('Rice '),
        _entry('Rice'),
      ];
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: const {},
      );
      // 4 >= kMinFrequency(3) → попадает; один кластер
      expect(result.length, 1);
    });

    // --- Сортировка ---

    test('более частый продукт идёт раньше менее частого', () {
      final logs = [
        ..._repeat('Banana', 5),
        ..._repeat('Cherry', 3),
      ];
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: const {},
      );
      expect(result.first.toLowerCase(), 'banana');
      expect(result.last.toLowerCase(), 'cherry');
    });

    test('при одинаковой частоте более свежий продукт идёт раньше', () {
      // Оба по kMinFrequency раз; 'OldFood' добавлялся 20 дней назад, 'NewFood' — вчера
      final logs = [
        ..._repeat('OldFood', kMinFrequency, daysAgo: 20),
        ..._repeat('NewFood', kMinFrequency, daysAgo: 1),
      ];
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: const {},
      );
      expect(result.first.toLowerCase(), 'newfood');
      expect(result.last.toLowerCase(), 'oldfood');
    });

    // --- Ограничение top-N ---

    test('результат не превышает kMaxSuggestions', () {
      // Создаём kMaxSuggestions + 5 уникальных продуктов, каждый с частотой >= kMinFrequency
      final logs = <FoodLogEntry>[];
      for (var i = 0; i < kMaxSuggestions + 5; i++) {
        logs.addAll(_repeat('Product_$i', kMinFrequency));
      }
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: const {},
      );
      expect(result.length, kMaxSuggestions);
    });

    // --- Пустой ввод ---

    test('пустой список логов → пустой результат', () {
      final result = computeShoppingSuggestions(
        logs: const [],
        basketNames: const {},
      );
      expect(result, isEmpty);
    });

    // --- Комбинированный сценарий ---

    test('комбинированный: порог + корзина + top-N', () {
      final logs = <FoodLogEntry>[
        ..._repeat('Milk', 10),     // частый → предлагаем
        ..._repeat('Eggs', 5),      // средний → предлагаем
        ..._repeat('Butter', 3),    // ровно на пороге → предлагаем
        ..._repeat('Honey', 2),     // ниже порога → НЕ предлагаем
        ..._repeat('Cheese', 7),    // в корзине → НЕ предлагаем
      ];
      final result = computeShoppingSuggestions(
        logs: logs,
        basketNames: {'Cheese'},
      );
      // Должно быть 3: Milk, Eggs, Butter (Honey < threshold, Cheese в корзине)
      expect(result.length, 3);
      expect(result.map((s) => s.toLowerCase()), containsAll(['milk', 'eggs', 'butter']));
      expect(result.map((s) => s.toLowerCase()), isNot(contains('honey')));
      expect(result.map((s) => s.toLowerCase()), isNot(contains('cheese')));
    });
  });
}
