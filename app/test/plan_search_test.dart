// Юнит-тесты чистой функции planSearchMatches (фильтр поиска на экране Plan).
// Покрываем: подстрока заголовка, #хэштег как целое слово (+ негатив
// «#mathematics»), type:exam и голое «exam», комбинацию #math type:exam
// (AND-семантика), пустой запрос (совпадает со всем), регистронезависимость.

import 'package:app/core/database/database.dart';
import 'package:app/features/plan/widgets/plan_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Минимальная фабрика item для теста фильтра (поля как в ItemsTableData).
ItemsTableData makeItem({
  String title = 'T',
  String type = 'task',
}) {
  return ItemsTableData(
    id: 'i1',
    userId: 'local',
    title: title,
    type: type,
    priority: 'medium',
    status: 'pending',
    scheduledAt: DateTime(2026, 6, 22, 10),
    durationMinutes: 30,
    isProtected: false,
    recurrenceRule: null,
    moduleLink: null,
    color: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('planSearchMatches — пустой запрос', () {
    test('пустая строка совпадает со всем', () {
      expect(planSearchMatches(makeItem(title: 'Anything'), ''), isTrue);
    });
    test('только пробелы совпадают со всем', () {
      expect(planSearchMatches(makeItem(title: 'Anything'), '   '), isTrue);
    });
  });

  group('planSearchMatches — подстрока заголовка', () {
    test('подстрока совпадает', () {
      expect(planSearchMatches(makeItem(title: 'Algebra lecture'), 'lecture'),
          isTrue);
    });
    test('отсутствующая подстрока не совпадает', () {
      expect(planSearchMatches(makeItem(title: 'Algebra lecture'), 'physics'),
          isFalse);
    });
    test('регистронезависимость', () {
      expect(planSearchMatches(makeItem(title: 'Algebra Lecture'), 'LECTURE'),
          isTrue);
      expect(planSearchMatches(makeItem(title: 'ALGEBRA'), 'algebra'), isTrue);
    });
  });

  group('planSearchMatches — #хэштег как целое слово', () {
    test('#math совпадает с заголовком, содержащим #math', () {
      expect(
        planSearchMatches(makeItem(title: 'Homework #math today'), '#math'),
        isTrue,
      );
    });
    test('#math НЕ совпадает с #mathematics (граница слова)', () {
      expect(
        planSearchMatches(makeItem(title: 'Read #mathematics book'), '#math'),
        isFalse,
      );
    });
    test('#хэштег регистронезависим', () {
      expect(
        planSearchMatches(makeItem(title: 'Lab #Math'), '#math'),
        isTrue,
      );
    });
    test('хэштег отсутствует — не совпадает', () {
      expect(
        planSearchMatches(makeItem(title: 'Plain title'), '#math'),
        isFalse,
      );
    });
  });

  group('planSearchMatches — фильтр по типу', () {
    test('type:exam совпадает с exam-элементом', () {
      expect(planSearchMatches(makeItem(type: 'exam'), 'type:exam'), isTrue);
    });
    test('type:exam не совпадает с task-элементом', () {
      expect(planSearchMatches(makeItem(type: 'task'), 'type:exam'), isFalse);
    });
    test('голое слово exam совпадает с exam-элементом', () {
      expect(planSearchMatches(makeItem(type: 'exam'), 'exam'), isTrue);
    });
    test('голое слово exam не совпадает с task-элементом', () {
      expect(planSearchMatches(makeItem(type: 'task'), 'exam'), isFalse);
    });
    test('тип регистронезависим', () {
      expect(planSearchMatches(makeItem(type: 'exam'), 'TYPE:EXAM'), isTrue);
      expect(planSearchMatches(makeItem(type: 'exam'), 'EXAM'), isTrue);
    });
  });

  group('planSearchMatches — комбинация токенов (AND)', () {
    test('#math type:exam совпадает только когда оба условия истинны', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Final #math', type: 'exam'),
          '#math type:exam',
        ),
        isTrue,
      );
    });
    test('#math type:exam не совпадает, если тип не exam', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Final #math', type: 'task'),
          '#math type:exam',
        ),
        isFalse,
      );
    });
    test('#math type:exam не совпадает, если хэштега нет', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Final review', type: 'exam'),
          '#math type:exam',
        ),
        isFalse,
      );
    });
    test('подстрока + тип вместе', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Algebra final', type: 'exam'),
          'algebra exam',
        ),
        isTrue,
      );
      expect(
        planSearchMatches(
          makeItem(title: 'Algebra final', type: 'task'),
          'algebra exam',
        ),
        isFalse,
      );
    });
  });
}
