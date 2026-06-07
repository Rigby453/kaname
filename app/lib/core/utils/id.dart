// Генератор UUID v4 без внешних зависимостей.
// Клиентские id должны быть валидными UUID — сервер при синхронизации
// валидирует их как z.string().uuid() (см. backend/src/routes/sync.ts).
// Random здесь не криптостойкий, но для локальной уникальности id достаточно.

import 'dart:math';

final Random _rng = Random();

/// Возвращает случайный UUID версии 4 в каноничном виде
/// xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx.
String uuidV4() {
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));

  // Версия 4 (старшие 4 бита 7-го байта = 0100)
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Вариант RFC 4122 (старшие 2 бита 9-го байта = 10)
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).toList();

  return '${h[0]}${h[1]}${h[2]}${h[3]}-'
      '${h[4]}${h[5]}-'
      '${h[6]}${h[7]}-'
      '${h[8]}${h[9]}-'
      '${h[10]}${h[11]}${h[12]}${h[13]}${h[14]}${h[15]}';
}
