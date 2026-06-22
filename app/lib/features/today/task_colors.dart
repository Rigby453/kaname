// Палитра цветов-меток для задач (#14).
// Чистый модуль без I/O — источник правды по пресетам цветов.
// Пользователь выбирает один из пресетов в add/edit-листе; в БД хранится
// стабильный строковый ключ (колонка items.color, schemaVersion 13).
// Рендерится на блоках сетки Plan, строках Today и карточках дня.
//
// Цвета подобраны как различимые ярлыки, читаемые на тёмной теме Focus.
// Это пользовательские метки, а НЕ акцент темы — поэтому отдельная палитра.

import 'package:flutter/painting.dart' show Color;

/// Один пресет палитры: стабильный ключ + цвет.
class TaskColorOption {
  const TaskColorOption(this.key, this.color);

  /// Стабильный строковый ключ (хранится в БД). Не локализуется, не меняется.
  final String key;

  /// Цвет-метка для отображения.
  final Color color;
}

/// Пресеты цветов задач (~18). Источник правды — этот список.
/// Ключи стабильны: переименование сломает уже сохранённые задачи.
const List<TaskColorOption> kTaskColors = <TaskColorOption>[
  TaskColorOption('tomato', Color(0xFFE6584D)),
  TaskColorOption('red', Color(0xFFD7443B)),
  TaskColorOption('orange', Color(0xFFE8743B)),
  TaskColorOption('amber', Color(0xFFEFA53B)),
  TaskColorOption('yellow', Color(0xFFE6C84B)),
  TaskColorOption('lime', Color(0xFFAFD24B)),
  TaskColorOption('green', Color(0xFF5DB45F)),
  TaskColorOption('emerald', Color(0xFF3FB07A)),
  TaskColorOption('teal', Color(0xFF3DB1A6)),
  TaskColorOption('cyan', Color(0xFF45B6D1)),
  TaskColorOption('sky', Color(0xFF4D9BE6)),
  TaskColorOption('blue', Color(0xFF5878E6)),
  TaskColorOption('indigo', Color(0xFF6E63D9)),
  TaskColorOption('purple', Color(0xFF9B5FD0)),
  TaskColorOption('magenta', Color(0xFFC457C9)),
  TaskColorOption('pink', Color(0xFFE05D97)),
  TaskColorOption('brown', Color(0xFFA9755A)),
  TaskColorOption('gray', Color(0xFF8E8B85)),
];

/// Возвращает цвет по ключу палитры.
/// null/неизвестный ключ → null (вызывающий код откатывается на текущий стиль).
Color? taskColorFromKey(String? key) {
  if (key == null) return null;
  for (final option in kTaskColors) {
    if (option.key == key) return option.color;
  }
  return null;
}
