// Фокус-сессии (SPEC C8): пресеты 25/5, 50/10, 52/17, 90/20, 67/15.
// Kaname redesign §Phase 5: полный рестайл.
//
// Режимы:
//   Таймер — обратный отсчёт; пресеты work/break; фазы work→rest→work→…
//   Секундомер — счёт вперёд; старт/пауза/продолжить/сброс; mm:ss / h:mm:ss.
//
// Переключатель режима — пилюли в Kaname-стиле (surface + hairline / accentTint +
// accent border); видим только в idle-состоянии.
//
// Idle (таймер):   heading + пресет-чипы (pill, accentTint when selected) + Start CTA.
// Idle (секундомер): «00:00» приглушённый + Start CTA.
// Running (таймер): большой MM:SS mono-таймер + метка фазы + Pause/Stop.
// Running (секундомер): счётчик MM:SS/h:mm:ss + Pause/Resume + Reset.
//
// Kai ambient в углу (IgnorePointer) на обоих running-экранах.
// Трение: PopScope → AlertDialog при попытке уйти с активной сессии.
//
// Логирование: сессии в БД не пишутся (completedFocusBlocks — in-memory счётчик).
//
// Дизайн-система (design-tokens v4, REDESIGN-KANAME §4.3):
//   Чипы: accentTint fill + accent border (selected) / surface + hairline (idle).
//   Таймер/счётчик: displayLarge (40sp) + tabular figures — «мономерные» цифры.
//   Kai: size 56, thinking(work/running) / neutral(rest/paused), IgnorePointer.
//   Кнопки: ONE FilledButton (Start); Pause/Stop/Reset = OutlinedButton (secondary).
//   Иконки: Phosphor (play-fill для Start, pause/play/stop/arrow regular для управления).
//   reduce-motion уважается во всех AnimatedContainer/AnimatedOpacity.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../mascot/kai_mascot.dart';
import 'focus_stopwatch_controller.dart';

// ---------------------------------------------------------------------------
// Данные пресетов (не переводятся — числовые метки)
// ---------------------------------------------------------------------------

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
  _Preset('67 / 15', 67, 15), // фирменный формат
];

enum _Phase { idle, work, rest }

/// Режим фокус-экрана: обратный отсчёт (timer) или секундомер (stopwatch).
enum _Mode { timer, stopwatch }

// ---------------------------------------------------------------------------
// Виджет
// ---------------------------------------------------------------------------

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  // --- Режим ---
  _Mode _mode = _Mode.timer;

  // --- Таймер (обратный отсчёт) ---
  int _presetIndex = 0;
  _Phase _phase = _Phase.idle;
  int _secondsLeft = 0;
  bool _running = false;
  int _completedFocusBlocks = 0;

  // --- Секундомер ---
  final _sw = FocusStopwatchController();

  // --- Общий тикер: используется и таймером, и секундомером ---
  Timer? _ticker;

  _Preset get _preset => _presets[_presetIndex];

  /// Активна ли сессия (не в idle). Учитывает текущий режим.
  bool get _inSession =>
      _mode == _Mode.timer ? _phase != _Phase.idle : _sw.inSession;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Логика таймера (обратный отсчёт) — не изменена
  // ---------------------------------------------------------------------------

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
      // Фаза закончилась — переключаем
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

  // ---------------------------------------------------------------------------
  // Логика секундомера
  // ---------------------------------------------------------------------------

  /// Старт (или Continue после паузы, если тикер уже запущен).
  void _swStart() {
    setState(() => _sw.start());
    // Перезапускаем тикер; tick() сам проверяет _sw.running — пауза не ломает тикер.
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _sw.tick());
    });
  }

  /// Пауза / Продолжить.
  void _swTogglePause() => setState(() {
        if (_sw.running) {
          _sw.pause();
        } else {
          _sw.start();
        }
      });

  /// Сброс: отменяет тикер и возвращает секундомер в idle.
  void _swReset() {
    _ticker?.cancel();
    setState(() => _sw.reset());
  }

  // ---------------------------------------------------------------------------
  // Мягкое трение при навигации «назад» из активной сессии
  // ---------------------------------------------------------------------------

  Future<void> _showExitDialog(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ext = Theme.of(ctx).extension<FocusThemeExtension>();
        return AlertDialog(
          title: Text(ctx.s('focus.exit_title')),
          content: Text(ctx.s('focus.exit_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.s('focus.exit_stay')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                ctx.s('focus.exit_leave'),
                style: TextStyle(color: ext?.ember),
              ),
            ),
          ],
        );
      },
    );

    if (leave == true && mounted) {
      // Останавливаем активную сессию
      if (_mode == _Mode.timer) {
        _stop();
      } else {
        _swReset();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Форматирование таймера MM:SS (обратный отсчёт)
  // ---------------------------------------------------------------------------

  String get _mmss {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return PopScope(
      canPop: !_inSession,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitDialog(context);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.s('focus.title'))),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _inSession
              ? (_mode == _Mode.timer
                  ? _buildRunning(textTheme, colorScheme, ext)
                  : _buildStopwatchRunning(textTheme, colorScheme, ext))
              : _buildIdle(textTheme, colorScheme, ext),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Idle — выбор режима / пресета
  // ---------------------------------------------------------------------------

  Widget _buildIdle(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Переключатель Таймер / Секундомер — всегда вверху idle-экрана
        _buildModeSwitcher(colorScheme, ext, textTheme),
        const SizedBox(height: 24),

        // Контент, зависящий от режима
        if (_mode == _Mode.timer) ...[
          Text(
            context.s('focus.pick_session'),
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.s('focus.session_hint'),
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              _presets.length,
              (i) => _buildPresetChip(i, colorScheme, ext, textTheme),
            ),
          ),
        ] else ...[
          // Секундомер в idle: большой «00:00» приглушённым цветом
          Center(
            child: Text(
              _sw.display,
              style: textTheme.displayLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: ext.textFaint,
              ),
            ),
          ),
        ],

        const Spacer(),

        // Счётчик завершённых блоков (только если есть хоть один)
        if (_completedFocusBlocks > 0) ...[
          Center(
            child: Text(
              context
                  .s('focus.blocks_today')
                  .replaceAll('{n}', '$_completedFocusBlocks'),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Start CTA — режим выбирает нужный обработчик
        FilledButton.icon(
          icon: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 20),
          label: Text(context.s('focus.btn_start')),
          onPressed: _mode == _Mode.timer ? _start : _swStart,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Переключатель режима: pill-чипы «Таймер» / «Секундомер»
  // ---------------------------------------------------------------------------

  Widget _buildModeSwitcher(
    ColorScheme colorScheme,
    FocusThemeExtension ext,
    TextTheme textTheme,
  ) {
    // Expanded-чипы внутри Row: оба занимают половину ширины.
    // Overflow-safe на 320px (текст может быть длиннее в некоторых языках).
    return Row(
      children: [
        Expanded(
          child: _buildModeChip(
            _Mode.timer,
            PhosphorIcons.timer(),
            context.s('focus.mode_timer'),
            colorScheme,
            ext,
            textTheme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeChip(
            _Mode.stopwatch,
            PhosphorIcons.clockClockwise(),
            context.s('focus.mode_stopwatch'),
            colorScheme,
            ext,
            textTheme,
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(
    _Mode mode,
    IconData icon,
    String label,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
    TextTheme textTheme,
  ) {
    final selected = _mode == mode;
    final reduce = reduceMotionOf(context);

    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : kDurationFast,
        curve: kCurveLift,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ext.accentTint : colorScheme.surface,
          borderRadius: BorderRadius.circular(999), // pill
          border: Border.all(
            color: selected ? colorScheme.primary : ext.border,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? ext.accentInk : ext.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(
                  color: selected ? ext.accentInk : ext.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Один пресет-чип таймера.
  Widget _buildPresetChip(
    int index,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
    TextTheme textTheme,
  ) {
    final selected = _presetIndex == index;
    final reduce = reduceMotionOf(context);

    return GestureDetector(
      onTap: () => setState(() => _presetIndex = index),
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : kDurationFast,
        curve: kCurveLift,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ext.accentTint : colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colorScheme.primary : ext.border,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          _presets[index].label,
          style: textTheme.labelLarge?.copyWith(
            color: selected ? ext.accentInk : ext.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Running (таймер) — без изменений
  // ---------------------------------------------------------------------------

  Widget _buildRunning(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    final isWork = _phase == _Phase.work;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Метка фазы
              Text(
                isWork
                    ? context.s('focus.phase_work')
                    : context.s('focus.phase_break'),
                style: textTheme.titleMedium?.copyWith(
                  color: isWork ? colorScheme.primary : ext.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              // Большой таймер MM:SS
              Text(
                _mmss,
                style: textTheme.displayLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _preset.label,
                style: textTheme.bodySmall?.copyWith(
                  color: ext.textFaint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        _running
                            ? PhosphorIcons.pause()
                            : PhosphorIcons.play(),
                        size: 20,
                      ),
                      label: Text(
                        _running
                            ? context.s('focus.btn_pause')
                            : context.s('focus.btn_resume'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _togglePause,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.stop(), size: 20),
                      label: Text(
                        context.s('focus.btn_stop'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _stop,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Kai ambient
        _buildKaiAmbient(isWork: isWork),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Running (секундомер)
  // ---------------------------------------------------------------------------

  Widget _buildStopwatchRunning(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Метка режима
              Text(
                context.s('focus.mode_stopwatch'),
                style: textTheme.titleMedium?.copyWith(
                  color: _sw.running ? colorScheme.primary : ext.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              // Счётчик времени: mm:ss / h:mm:ss
              Text(
                _sw.display,
                style: textTheme.displayLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 48),
              // Пауза/Продолжить + Сброс
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        _sw.running
                            ? PhosphorIcons.pause()
                            : PhosphorIcons.play(),
                        size: 20,
                      ),
                      label: Text(
                        _sw.running
                            ? context.s('focus.btn_pause')
                            : context.s('focus.btn_resume'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _swTogglePause,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        PhosphorIcons.arrowCounterClockwise(),
                        size: 20,
                      ),
                      label: Text(
                        context.s('focus.btn_reset'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _swReset,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Kai ambient: thinking — тикает, neutral — пауза
        _buildKaiAmbient(isWork: _sw.running),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Kai ambient (общий для обоих running-экранов)
  // ---------------------------------------------------------------------------

  Widget _buildKaiAmbient({required bool isWork}) {
    return Positioned(
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
                size: 56,
                emotion: isWork ? KaiEmotion.thinking : KaiEmotion.neutral,
                isHarsh: isHarsh,
              ),
            );
          },
        ),
      ),
    );
  }
}
