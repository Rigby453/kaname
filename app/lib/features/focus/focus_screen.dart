// Фокус-сессии (SPEC C8): пресеты 25/5, 50/10, 52/17, 90/20 и фирменный 67/15.
// Таймер с фазами работа/перерыв, Пауза/Стоп. Локальное эфемерное состояние
// (тикающий таймер) → StatefulWidget с Timer; бизнес-данных тут нет.
//
// Дизайн-система (03-components.md, 02-type-space.md, UX-LAYOUT.md):
// — 24dp экранные поля (02-type-space.md §4.1)
// — цифры таймера: displayLarge (display font, tight tracking)
// — фаза: titleLarge (body font)
// — акцент ТОЛЬКО на: кнопка Start/Stop (FilledButton), активная фаза work
// — Kai ambient в нижнем углу при активной сессии (MASCOT.md §6)
// — reduce-motion уважается (constants.dart)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../mascot/kai_mascot.dart';

class _Preset {
  const _Preset(this.label, this.workMin, this.breakMin);
  final String label;
  final int workMin;
  final int breakMin;
}

const _presets = [
  _Preset('25 / 5', 25, 5),
  _Preset('50 / 10', 50, 10),
  _Preset('52 / 17', 52, 17),
  _Preset('90 / 20', 90, 20),
  _Preset('67 / 15', 67, 15), // фирменный
];

enum _Phase { idle, work, rest }

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  int _presetIndex = 0;
  _Phase _phase = _Phase.idle;
  int _secondsLeft = 0;
  bool _running = false;
  Timer? _ticker;
  int _completedFocusBlocks = 0;

  _Preset get _preset => _presets[_presetIndex];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phase = _Phase.work;
      _secondsLeft = _preset.workMin * 60;
      _running = true;
    });
    _arm();
  }

  void _arm() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        return;
      }
      // Фаза закончилась — переключаемся
      setState(() {
        if (_phase == _Phase.work) {
          _completedFocusBlocks++;
          _phase = _Phase.rest;
          _secondsLeft = _preset.breakMin * 60;
        } else {
          _phase = _Phase.work;
          _secondsLeft = _preset.workMin * 60;
        }
      });
    });
  }

  void _togglePause() => setState(() => _running = !_running);

  void _stop() {
    _ticker?.cancel();
    setState(() {
      _phase = _Phase.idle;
      _running = false;
      _secondsLeft = 0;
    });
  }

  String get _mmss {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final idle = _phase == _Phase.idle;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('focus.title'))),
      body: Padding(
        // 24dp экранные поля (02-type-space.md §4.1 screen edge margin)
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: idle
            ? _buildIdle(textTheme, colorScheme, ext)
            : _buildRunning(textTheme, colorScheme, ext),
      ),
    );
  }

  Widget _buildIdle(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок секции — headlineSmall (display font, 22sp)
        Text(
          context.s('focus.pick_session'),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        // Подсказка — bodySmall (textMuted per design)
        Text(
          context.s('focus.session_hint'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 20),
        // Пресеты — ChoiceChip (03-components.md §11)
        // Выбранный пресет = accent fill; chip компонент из ThemeData автоматически
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_presets.length, (i) {
            return ChoiceChip(
              label: Text(_presets[i].label),
              selected: _presetIndex == i,
              onSelected: (_) => setState(() => _presetIndex = i),
            );
          }),
        ),
        const Spacer(),
        // Счётчик завершённых блоков — bodyMedium (textMuted)
        if (_completedFocusBlocks > 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context
                    .s('focus.blocks_today')
                    .replaceAll('{n}', '$_completedFocusBlocks'),
                style:
                    textTheme.bodyMedium?.copyWith(color: ext.textMuted),
              ),
            ),
          ),
        const SizedBox(height: 4),
        // Единственная кнопка: FilledButton — акцент, primary CTA
        // (03-components.md §2 и §3: FilledButton = единственный primary action)
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(context.s('focus.btn_start')),
          onPressed: _start,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRunning(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    final isWork = _phase == _Phase.work;

    // Kai в углу при активной сессии — ambient, не добавляет тапов (MASCOT.md §6).
    return Stack(
      children: [
        // Основной контент по центру
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Фаза: titleLarge, акцент = accent (work) / textMuted (rest)
            // Per accent discipline: активная фаза work = единственный цветной элемент здесь
            Center(
              child: Text(
                isWork
                    ? context.s('focus.phase_work')
                    : context.s('focus.phase_break'),
                style: textTheme.titleLarge?.copyWith(
                  // Work → accent; rest → textMuted (не ember/secondary)
                  color: isWork ? colorScheme.primary : ext.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Цифры таймера: displayLarge — display font, tabular figures
            // (02-type-space.md §1: 56sp, w700, letterSpacing -0.8, height 1.00)
            Center(
              child: Text(
                _mmss,
                style: textTheme.displayLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  // Цвет таймера = text (нейтральный) — акцент не здесь
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Метка пресета — bodyMedium (textMuted, вторичная информация)
            Center(
              child: Text(
                _preset.label,
                style: textTheme.bodyMedium?.copyWith(color: ext.textFaint),
              ),
            ),
            const SizedBox(height: 48),
            // Управление: Pause/Resume = OutlinedButton, Stop = OutlinedButton
            // Оба вторичные (не primary CTA) — FilledButton только у Start
            // (03-components.md §2 accent discipline)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    _running
                        ? context.s('focus.btn_pause')
                        : context.s('focus.btn_resume'),
                  ),
                  onPressed: _togglePause,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: Text(context.s('focus.btn_stop')),
                  onPressed: _stop,
                ),
              ],
            ),
          ],
        ),

        // Kai — тихо «дышит» в правом нижнем углу.
        // IgnorePointer: не перехватывает тапы, не перекрывает кнопки.
        Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Consumer(
              builder: (context, ref, _) {
                final showKai = ref.watch(showKaiProvider);
                if (!showKai) return const SizedBox.shrink();
                final isHarsh = ref.watch(toneProvider) == AppTone.harsh;
                final reduce = reduceMotionOf(context);
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: reduce ? Duration.zero : kDurationNormal,
                  child: KaiMascot(
                    size: 40,
                    // Во время работы — thinking (сосредоточен вместе с пользователем);
                    // во время перерыва — neutral (спокойно отдыхает).
                    emotion:
                        isWork ? KaiEmotion.thinking : KaiEmotion.neutral,
                    isHarsh: isHarsh,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
