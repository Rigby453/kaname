// Юнит-тесты FocusStopwatchController.
//
// Тестируемые сценарии:
//  1. Начальное состояние (idle): elapsed=0, !running, !inSession.
//  2. start() → running=true, inSession=true.
//  3. tick() при running → elapsed инкрементируется.
//  4. tick() при паузе → elapsed не меняется.
//  5. pause() после start() → running=false, но inSession=true (пауза ≠ idle).
//  6. start() после pause() (resume) → running снова true, tick() работает.
//  7. reset() из running → idle: elapsed=0, !running, !inSession.
//  8. reset() из паузы → idle.
//  9. display: начальный «00:00».
// 10. display: ровно 1 минута → «01:00».
// 11. display: 59:59 (3599 с) → «59:59» (ещё mm:ss).
// 12. display: 60:00 (3600 с) → «1:00:00» (переход в h:mm:ss).
// 13. display: 1:02:03 (3723 с).
// 14. Несколько тиков: start + 3 тика = elapsed=3, display «00:03».
// 15. Переключение режимов (state machine): idle → run → pause → run → reset → idle.

import 'package:app/features/focus/focus_stopwatch_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Фабрика: каждый тест работает со свежим контроллером.
  FocusStopwatchController make() => FocusStopwatchController();

  // ---------------------------------------------------------------------------
  // 1. Начальное состояние
  // ---------------------------------------------------------------------------
  group('initial state', () {
    test('elapsed=0, running=false, inSession=false', () {
      final c = make();
      expect(c.elapsed, 0);
      expect(c.running, isFalse);
      expect(c.inSession, isFalse);
    });

    test('display = «00:00»', () {
      expect(make().display, '00:00');
    });
  });

  // ---------------------------------------------------------------------------
  // 2-3. start() и tick()
  // ---------------------------------------------------------------------------
  group('start and tick', () {
    test('start → running=true, inSession=true', () {
      final c = make()..start();
      expect(c.running, isTrue);
      expect(c.inSession, isTrue);
    });

    test('tick while running increments elapsed', () {
      final c = make()..start();
      c.tick();
      expect(c.elapsed, 1);
      c.tick();
      expect(c.elapsed, 2);
    });

    test('14 ticks → elapsed=14, display «00:14»', () {
      final c = make()..start();
      for (var i = 0; i < 14; i++) {
        c.tick();
      }
      expect(c.elapsed, 14);
      expect(c.display, '00:14');
    });
  });

  // ---------------------------------------------------------------------------
  // 4-5. pause()
  // ---------------------------------------------------------------------------
  group('pause', () {
    test('tick while paused does not increment elapsed', () {
      final c = make()
        ..start()
        ..tick()
        ..tick(); // elapsed=2
      c.pause();
      c.tick(); // не должно работать
      c.tick(); // не должно работать
      expect(c.elapsed, 2);
    });

    test('pause: running=false, but inSession=true (not idle)', () {
      final c = make()..start()..tick();
      c.pause();
      expect(c.running, isFalse);
      expect(c.inSession, isTrue); // elapsed=1 > 0 → в сессии
    });
  });

  // ---------------------------------------------------------------------------
  // 6. resume (start после pause)
  // ---------------------------------------------------------------------------
  group('resume', () {
    test('start() after pause resumes counting', () {
      final c = make()
        ..start()
        ..tick() // elapsed=1
        ..pause()
        ..start(); // resume
      c.tick(); // elapsed=2
      c.tick(); // elapsed=3
      expect(c.elapsed, 3);
      expect(c.running, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 7-8. reset()
  // ---------------------------------------------------------------------------
  group('reset', () {
    test('reset from running → idle (elapsed=0, !running, !inSession)', () {
      final c = make()
        ..start()
        ..tick()
        ..tick();
      c.reset();
      expect(c.elapsed, 0);
      expect(c.running, isFalse);
      expect(c.inSession, isFalse);
      expect(c.display, '00:00');
    });

    test('reset from pause → idle', () {
      final c = make()
        ..start()
        ..tick()
        ..pause();
      c.reset();
      expect(c.elapsed, 0);
      expect(c.running, isFalse);
      expect(c.inSession, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 9-13. display форматирование
  // ---------------------------------------------------------------------------
  group('display formatting', () {
    test('0 s → «00:00»', () {
      expect(make().display, '00:00');
    });

    test('60 s → «01:00»', () {
      final c = make()..start();
      for (var i = 0; i < 60; i++) {
        c.tick();
      }
      expect(c.display, '01:00');
    });

    test('3599 s → «59:59» (ещё mm:ss)', () {
      final c = make()..start();
      for (var i = 0; i < 3599; i++) {
        c.tick();
      }
      expect(c.display, '59:59');
    });

    test('3600 s → «1:00:00» (переход в h:mm:ss)', () {
      final c = make()..start();
      for (var i = 0; i < 3600; i++) {
        c.tick();
      }
      expect(c.display, '1:00:00');
    });

    test('3723 s → «1:02:03»', () {
      final c = make()..start();
      for (var i = 0; i < 3723; i++) {
        c.tick();
      }
      expect(c.display, '1:02:03');
    });
  });

  // ---------------------------------------------------------------------------
  // 15. Полный state-machine: idle → run → pause → resume → reset → idle
  // ---------------------------------------------------------------------------
  group('state machine', () {
    test('full cycle: idle → run → pause → resume → reset → idle', () {
      final c = make();

      // Idle
      expect(c.inSession, isFalse);

      // Start
      c.start();
      expect(c.running, isTrue);
      expect(c.inSession, isTrue);
      c.tick();
      c.tick(); // elapsed=2

      // Pause
      c.pause();
      expect(c.running, isFalse);
      expect(c.inSession, isTrue);
      c.tick(); // не засчитывается

      // Resume
      c.start();
      expect(c.running, isTrue);
      c.tick(); // elapsed=3

      // Reset → idle
      c.reset();
      expect(c.elapsed, 0);
      expect(c.running, isFalse);
      expect(c.inSession, isFalse);
    });
  });
}
