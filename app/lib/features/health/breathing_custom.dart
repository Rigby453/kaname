// Кодек пользовательских дыхательных техник — чистый файл без зависимостей на
// Flutter/Drift. Преобразует список фаз движка (List<BreathPhase>) в JSON-строку
// для хранения в БД и обратно. Юнит-тестируется напрямую.
//
// Формат JSON: массив объектов фаз
//   [{ "label": "Inhale", "seconds": 4, "expand": true, "hold": false }, ...]
// Порядок фаз сохраняется. Любой невалидный JSON (битый, не-массив, не-объекты)
// безопасно деградирует в ПУСТОЙ список — вызывающий код сам решает, что делать
// (обычно — игнорировать технику без фаз).

import 'dart:convert';

import 'breathing_engine.dart';

/// Кодирует список фаз в компактную JSON-строку.
/// Сохраняем все четыре поля фазы, чтобы decode был точным round-trip:
/// label (тип), seconds (длительность), expand (растёт/сжимается), hold (задержка).
String encodePhases(List<BreathPhase> phases) {
  final list = phases
      .map((p) => <String, Object?>{
            'label': p.label,
            'seconds': p.duration.inSeconds,
            'expand': p.expand,
            'hold': p.hold,
          })
      .toList();
  return jsonEncode(list);
}

/// Декодирует JSON-строку в список фаз.
///
/// Контракт безопасности: при любой ошибке (битый JSON, не-массив, элемент не
/// объект, отсутствует/невалидный label или seconds) возвращает ПУСТОЙ список,
/// а не бросает исключение. Невалидные отдельные элементы пропускаются, валидные
/// сохраняются (с сохранением исходного порядка).
List<BreathPhase> decodePhases(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    final out = <BreathPhase>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final label = item['label'];
      final seconds = item['seconds'];
      if (label is! String || label.isEmpty) continue;
      if (seconds is! num) continue;
      final secs = seconds.toInt();
      if (secs <= 0) continue;
      out.add(BreathPhase(
        label: label,
        duration: Duration(seconds: secs),
        expand: item['expand'] == true,
        hold: item['hold'] == true,
      ));
    }
    return out;
  } catch (_) {
    // Любая ошибка парсинга → безопасный дефолт.
    return const [];
  }
}
