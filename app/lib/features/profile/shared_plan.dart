// Хелпер «Поделились со мной» (SPEC C7, Ф3, v1).
// Разбор токена из ссылки или сырой строки — чистая логика, без Flutter.
// UI-компонент (_SharedWithMeCard) живёт в profile_screen.dart.

/// Извлекает токен из вставленной пользователем строки.
///
/// Правила:
/// - Если строка содержит '/share/' — берём хвост после последнего '/share/',
///   обрезаем query-параметры (всё с '?' включительно) и пробелы.
/// - Иначе — trim и возвращаем как есть.
/// - Пустая строка → null.
String? extractShareToken(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  const marker = '/share/';
  final idx = trimmed.lastIndexOf(marker);
  if (idx != -1) {
    // Берём всё после '/share/'
    var tail = trimmed.substring(idx + marker.length);
    // Обрезаем query (?foo=bar) и anchor (#...)
    final qIdx = tail.indexOf('?');
    if (qIdx != -1) tail = tail.substring(0, qIdx);
    final hIdx = tail.indexOf('#');
    if (hIdx != -1) tail = tail.substring(0, hIdx);
    tail = tail.trim();
    return tail.isEmpty ? null : tail;
  }

  return trimmed;
}
