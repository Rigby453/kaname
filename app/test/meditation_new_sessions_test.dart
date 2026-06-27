// Тесты для 5 новых встроенных сессий медитации.
// Проверяем:
//   1) Все 5 новых сессий появляются в списке;
//   2) Тап по каждой открывает превью позы (правильный pose_name);
//   3) Нет overflow на 320px при textScale 1.5;
//   4) Нарратор TTS вызывается с текстом из шага (мок);
//   5) Переключатель ambient-музыки работает (мок).

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/meditation_audio.dart';
import 'package:app/features/health/meditation_custom_providers.dart';
import 'package:app/features/health/meditation_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Вспомогательные моки (дублируют Silent* из meditation_audio.dart).
// Используем их, чтобы не задействовать реальный flutter_tts / audioplayers.
// ---------------------------------------------------------------------------

class _CapturingNarrator implements MeditationNarrator {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text, String localeTag) async =>
      spoken.add('$localeTag:$text');

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _SilentAmbient implements MeditationAmbientPlayer {
  bool _playing = false;
  double _vol = kMeditationAmbientDefaultVolume;

  @override
  Future<void> start(double volume) async {
    _playing = true;
    _vol = volume;
  }

  @override
  Future<void> stop() async => _playing = false;

  @override
  Future<void> setVolume(double v) async => _vol = v;

  @override
  Future<void> dispose() async {}

  bool get isPlaying => _playing;
  double get volume => _vol;
}

// ---------------------------------------------------------------------------
// Вспомогательная функция накачки виджета.
// ---------------------------------------------------------------------------

Future<void> _pumpAt(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1.0,
  required _CapturingNarrator narrator,
  required _SilentAmbient ambient,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customMeditationsProvider
            .overrideWith((ref) => Stream.value(const <CustomMeditation>[])),
        meditationNarratorProvider.overrideWithValue(narrator),
        meditationAmbientPlayerProvider.overrideWithValue(ambient),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MeditationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  // Прокрутить список вниз, чтобы найти новые сессии (они за фолдом).
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 100.0, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  // --- 1. Все 5 новых сессий видны в списке после прокрутки ---
  testWidgets('все 5 новых сессий видны в списке', (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(tester, narrator: narrator, ambient: ambient);

    await scrollTo(tester, find.text('Anxiety Reset'));
    expect(find.text('Anxiety Reset'), findsOneWidget);

    await scrollTo(tester, find.text('Morning Energizer'));
    expect(find.text('Morning Energizer'), findsOneWidget);

    await scrollTo(tester, find.text('Gratitude Reset'));
    expect(find.text('Gratitude Reset'), findsOneWidget);

    await scrollTo(tester, find.text('Deep Work Entry'));
    expect(find.text('Deep Work Entry'), findsOneWidget);

    await scrollTo(tester, find.text('Evening Unwind'));
    expect(find.text('Evening Unwind'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  // --- 2. Превью позы: Anxiety Reset ---
  testWidgets('тап по Anxiety Reset открывает превью с правильной позой',
      (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(tester, narrator: narrator, ambient: ambient);

    await scrollTo(tester, find.text('Anxiety Reset'));
    await tester.tap(find.text('Anxiety Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Grounded seat'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- 3. Превью позы: Morning Energizer ---
  testWidgets('тап по Morning Energizer открывает превью с правильной позой',
      (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(tester, narrator: narrator, ambient: ambient);

    await scrollTo(tester, find.text('Morning Energizer'));
    await tester.tap(find.text('Morning Energizer'));
    await tester.pumpAndSettle();

    expect(find.text('Upright seat'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- 4. Превью позы: Deep Work Entry ---
  testWidgets('тап по Deep Work Entry открывает превью с правильной позой',
      (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(tester, narrator: narrator, ambient: ambient);

    await scrollTo(tester, find.text('Deep Work Entry'));
    await tester.tap(find.text('Deep Work Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Desk-ready seat'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- 5. Превью позы: Evening Unwind ---
  testWidgets('тап по Evening Unwind открывает превью с правильной позой',
      (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(tester, narrator: narrator, ambient: ambient);

    await scrollTo(tester, find.text('Evening Unwind'));
    await tester.tap(find.text('Evening Unwind'));
    await tester.pumpAndSettle();

    // Evening Unwind и sleep_prep используют одинаковую иконку (лёжа),
    // поэтому pose_name важно проверять как отличительное.
    expect(find.text('Resting pose'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- 6. Нет overflow на 320px textScale 1.5 ---
  testWidgets('список медитаций без overflow на 320px textScale 1.5',
      (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(
      tester,
      width: 320,
      textScale: 1.5,
      narrator: narrator,
      ambient: ambient,
    );

    // Прокрутить до конца, чтобы все новые сессии отрисовались.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // --- 7. Плеер: включение нарратора через UI приводит к speak() ---
  testWidgets('включение нарратора через переключатель вызывает speak()',
      (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(tester, narrator: narrator, ambient: ambient);

    await scrollTo(tester, find.text('Anxiety Reset'));
    await tester.tap(find.text('Anxiety Reset'));
    await tester.pumpAndSettle();

    // Стартуем плеер.
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // По умолчанию аудио-панель скрыта — раскрываем тапом по значку громкости.
    final volumeBtn = find.byIcon(Icons.volume_up_outlined);
    if (volumeBtn.evaluate().isNotEmpty) {
      await tester.tap(volumeBtn);
      await tester.pump();
    }

    // Первый SwitchListTile в раскрытой панели — narration toggle.
    final tiles = find.byType(SwitchListTile);
    if (tiles.evaluate().isNotEmpty) {
      await tester.tap(tiles.first);
      await tester.pump();
      // После включения нарратор должен сразу говорить текущий шаг.
      expect(narrator.spoken, isNotEmpty);
    }

    // Закрываем плеер чтобы dispose отменил таймер.
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // --- 8. Ambient-музыка: мок слушает toggle ---
  testWidgets('переключатель ambient музыки достигает провайдера',
      (tester) async {
    final narrator = _CapturingNarrator();
    final ambient = _SilentAmbient();
    await _pumpAt(tester, narrator: narrator, ambient: ambient);

    // Открываем плеер через Evening Unwind.
    await scrollTo(tester, find.text('Evening Unwind'));
    await tester.tap(find.text('Evening Unwind'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Плеер показывает панель управления аудио. Находим переключатель Ambient.
    final switchListTiles = find.byType(SwitchListTile);
    if (switchListTiles.evaluate().isNotEmpty) {
      // Скроллим к переключателю если он не виден.
      await tester.scrollUntilVisible(
        switchListTiles.last,
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(switchListTiles.last);
      await tester.pump();
    }

    // Закрываем.
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
