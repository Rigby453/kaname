// Контроллер секундомера — чистая Dart-логика, без зависимостей Flutter.
// Используется FocusScreen; тестируется изолированно в focus_stopwatch_test.dart.

/// Режим секундомера: счёт вверх от нуля.
/// Состояние:  idle (elapsed=0, !running) → running → paused → running → idle (reset).
/// Тикер живёт во FocusScreen; контроллер вызывает [tick] раз в секунду.
class FocusStopwatchController {
  int _elapsed = 0; // прошедшие секунды
  bool _running = false;

  /// Прошедшее время (секунды).
  int get elapsed => _elapsed;

  /// Тикает прямо сейчас.
  bool get running => _running;

  /// «В сессии» = запущен ИЛИ стоит на паузе с ненулевым elapsed.
  bool get inSession => _running || _elapsed > 0;

  /// Запустить / продолжить после паузы.
  void start() => _running = true;

  /// Пауза (elapsed сохраняется; тикер продолжает крутиться, но tick() ничего
  /// не делает — consistent с тем, как CountdownTimer обрабатывает паузу).
  void pause() => _running = false;

  /// Сброс к нулю и остановка (→ idle).
  void reset() {
    _elapsed = 0;
    _running = false;
  }

  /// Вызывается тикером каждую секунду.
  /// Инкрементирует [elapsed] только если [running].
  void tick() {
    if (_running) _elapsed++;
  }

  /// Форматирование: «mm:ss» (< 1 ч) / «h:mm:ss» (≥ 1 ч).
  /// Передавать в Text с FontFeature.tabularFigures().
  String get display {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
