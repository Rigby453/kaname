// Юнит-тесты парсера Todoist CSV (lib/features/import/todoist_csv_parser.dart).
// Чистый Dart, без Drift и без виджетов.

import 'package:app/features/import/todoist_csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _header =
    'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,RESPONSIBLE,DATE,DATE_LANG,TIMEZONE';

void main() {
  group('TodoistCsvParser.parse', () {
    test('одна задача со всеми полями', () {
      final csv = '$_header\n'
          'task,Buy milk,At the store,1,1,Me,,2024-06-17,en,Europe/Moscow';
      final tasks = TodoistCsvParser.parse(csv);
      expect(tasks, hasLength(1));
      final t = tasks.single;
      expect(t.content, 'Buy milk');
      expect(t.description, 'At the store');
      expect(t.priority, '1');
      expect(t.date, '2024-06-17');
    });

    test('несколько задач; не-task строки (section/note) отфильтровываются', () {
      final csv = '$_header\n'
          'task,First,,4,1,Me,,,en,\n'
          'section,My Section,,,,,,,,\n'
          'note,a comment,,,,,,,,\n'
          'task,Second,,2,1,Me,,2024-06-18,en,';
      final tasks = TodoistCsvParser.parse(csv);
      expect(tasks.map((t) => t.content), ['First', 'Second']);
    });

    test('задача без DESCRIPTION → description == null', () {
      final csv = '$_header\ntask,No desc,,4,1,Me,,,en,';
      expect(TodoistCsvParser.parse(csv).single.description, isNull);
    });

    test('запятая внутри кавычек не ломает поле', () {
      final csv = '$_header\n'
          'task,"Milk, eggs and bread","note, with comma",4,1,Me,,,en,';
      final t = TodoistCsvParser.parse(csv).single;
      expect(t.content, 'Milk, eggs and bread');
      expect(t.description, 'note, with comma');
    });

    test('экранированные кавычки ("") внутри поля', () {
      final csv = '$_header\ntask,"Say ""hi"" now",,4,1,Me,,,en,';
      expect(TodoistCsvParser.parse(csv).single.content, 'Say "hi" now');
    });

    test('пустой контент пропускается', () {
      final csv = '$_header\ntask,,,4,1,Me,,,en,';
      expect(TodoistCsvParser.parse(csv), isEmpty);
    });

    test('пустой файл → пустой список', () {
      expect(TodoistCsvParser.parse(''), isEmpty);
    });

    test('только заголовок → пустой список', () {
      expect(TodoistCsvParser.parse(_header), isEmpty);
    });

    test('нет обязательных колонок (TYPE/CONTENT) → пустой список', () {
      const csv = 'FOO,BAR\nx,y';
      expect(TodoistCsvParser.parse(csv), isEmpty);
    });

    test('CRLF переносы строк нормализуются', () {
      final csv = '$_header\r\ntask,Win,,4,1,Me,,,en,\r\n';
      expect(TodoistCsvParser.parse(csv).single.content, 'Win');
    });

    test('пустые строки между задачами игнорируются', () {
      final csv = '$_header\ntask,A,,4,1,Me,,,en,\n\n\ntask,B,,4,1,Me,,,en,';
      expect(TodoistCsvParser.parse(csv).map((t) => t.content), ['A', 'B']);
    });

    test('отсутствует колонка PRIORITY → дефолт "4"', () {
      const csv = 'TYPE,CONTENT,DATE\ntask,No prio,2024-06-17';
      final t = TodoistCsvParser.parse(csv).single;
      expect(t.priority, '4');
      expect(t.date, '2024-06-17');
    });

    test('пустая дата → date == null', () {
      final csv = '$_header\ntask,No date,,4,1,Me,,,en,';
      expect(TodoistCsvParser.parse(csv).single.date, isNull);
    });
  });

  group('TodoistCsvParser.mapPriority', () {
    test('1 (urgent) → main', () {
      expect(TodoistCsvParser.mapPriority('1'), 'main');
    });
    test('2 (high) → medium', () {
      expect(TodoistCsvParser.mapPriority('2'), 'medium');
    });
    test('3 и 4 → low', () {
      expect(TodoistCsvParser.mapPriority('3'), 'low');
      expect(TodoistCsvParser.mapPriority('4'), 'low');
    });
    test('неизвестное значение → low', () {
      expect(TodoistCsvParser.mapPriority(''), 'low');
      expect(TodoistCsvParser.mapPriority('x'), 'low');
    });
  });

  group('TodoistCsvParser.parseDate', () {
    test('ISO формат 2024-06-17 → 09:00 локальное', () {
      expect(
        TodoistCsvParser.parseDate('2024-06-17'),
        DateTime(2024, 6, 17, 9, 0),
      );
    });

    test('сокращённое имя месяца "Jun 17 2024"', () {
      expect(
        TodoistCsvParser.parseDate('Jun 17 2024'),
        DateTime(2024, 6, 17, 9, 0),
      );
    });

    test('полное имя месяца "June 17 2024 @ 09:00"', () {
      expect(
        TodoistCsvParser.parseDate('June 17 2024 @ 09:00'),
        DateTime(2024, 6, 17, 9, 0),
      );
    });

    test('null и пустая строка → null', () {
      expect(TodoistCsvParser.parseDate(null), isNull);
      expect(TodoistCsvParser.parseDate(''), isNull);
    });

    test('неразбираемая дата → null', () {
      expect(TodoistCsvParser.parseDate('someday'), isNull);
    });
  });
}
