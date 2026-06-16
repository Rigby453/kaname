// Тосты приложения — ANIMATIONS.md §3.
// API: showAppToast(context, variant: ..., message: '...', onUndo: ...).
// Максимум 1 тост одновременно; новый вызов мгновенно убирает предыдущий.

import 'package:flutter/material.dart';

import 'constants.dart';

// ---------------------------------------------------------------------------
// Публичный enum вариантов
// ---------------------------------------------------------------------------

/// Варианты тоста (§3.1–3.3).
enum AppToastVariant {
  /// §3.1 Задача выполнена — зелёный фон #1D9E75
  done,

  /// §3.2 Напоминание о дедлайне — оранжевый #FF6A3D
  deadline,

  /// §3.3 Задача удалена — поверхность темы + рамка + кнопка Undo
  removed,
}

// ---------------------------------------------------------------------------
// Публичная точка входа
// ---------------------------------------------------------------------------

/// Показывает тост снизу экрана (§3 ANIMATIONS.md).
/// Максимум 1 тост одновременно — предыдущий убирается немедленно.
/// [onUndo] — только для варианта [AppToastVariant.removed]; таймер = 4 сек.
void showAppToast(
  BuildContext context, {
  required AppToastVariant variant,
  required String message,
  VoidCallback? onUndo,
}) {
  // Убираем предыдущий тост немедленно
  _AppToastManager._dismiss();

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  // Колбэк «скрыть» — передаётся в виджет
  void dismiss() => _AppToastManager._dismiss();

  entry = OverlayEntry(
    builder: (_) => _AppToastOverlay(
      variant: variant,
      message: message,
      onUndo: onUndo,
      onDismiss: dismiss,
    ),
  );

  _AppToastManager._current = entry;
  overlay.insert(entry);
}

// ---------------------------------------------------------------------------
// Внутренний менеджер единственного тоста
// ---------------------------------------------------------------------------

class _AppToastManager {
  _AppToastManager._();

  static OverlayEntry? _current;

  /// Убирает активный тост (если есть) немедленно, без анимации на уровне
  /// OverlayEntry — анимацию управляет сам виджет через _dismiss-колбэк.
  static void _dismiss() {
    _current?.remove();
    _current = null;
  }
}

// ---------------------------------------------------------------------------
// Виджет тоста с анимацией
// ---------------------------------------------------------------------------

class _AppToastOverlay extends StatefulWidget {
  const _AppToastOverlay({
    required this.variant,
    required this.message,
    required this.onDismiss,
    this.onUndo,
  });

  final AppToastVariant variant;
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onUndo;

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  // Длительности из §3
  static const Duration _enterDuration = kDurationNormal; // 280 мс
  static const Duration _exitDuration = Duration(milliseconds: 220);
  static const Curve _exitCurve = Curves.easeInCubic;

  // Смещение: +80px → 0 при входе, 0 → +80px при выходе
  static const double _slidePixels = 80.0;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: _enterDuration);

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: kCurveLift),
    );

    // Запускаем вход
    _ctrl.forward().then((_) => _scheduleAuto());
  }

  void _scheduleAuto() {
    // Задержка видимости: 3.5 сек (4 сек если есть onUndo) — §3
    final hangMs = widget.onUndo != null ? 4000 : 3500;
    Future.delayed(Duration(milliseconds: hangMs), () {
      if (mounted) _startExit();
    });
  }

  Future<void> _startExit() async {
    if (!mounted) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce) {
      // Перепрограммируем контроллер на выход
      await _ctrl.animateTo(
        0,
        duration: _exitDuration,
        curve: _exitCurve,
      );
    }
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // --- Цвета и иконка по варианту ---

  Color _bgColor(ThemeData theme) {
    switch (widget.variant) {
      case AppToastVariant.done:
        return const Color(0xFF1D9E75);
      case AppToastVariant.deadline:
        return const Color(0xFFFF6A3D);
      case AppToastVariant.removed:
        return theme.colorScheme.surface;
    }
  }

  IconData _icon() {
    switch (widget.variant) {
      case AppToastVariant.done:
        return Icons.check;
      case AppToastVariant.deadline:
        return Icons.access_time;
      case AppToastVariant.removed:
        return Icons.delete_outline;
    }
  }

  Color _iconAndTextColor(ThemeData theme) {
    switch (widget.variant) {
      case AppToastVariant.done:
      case AppToastVariant.deadline:
        return Colors.white;
      case AppToastVariant.removed:
        return theme.colorScheme.onSurface;
    }
  }

  // --- Построение виджета ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final reduce = mq.disableAnimations;

    // Отступ снизу: 16px + высота нижней навигации + padding (safe area)
    final bottomOffset = 16.0 +
        kBottomNavigationBarHeight +
        mq.viewPadding.bottom;

    final bg = _bgColor(theme);
    final fgColor = _iconAndTextColor(theme);

    // Рамка только для removed
    final border = widget.variant == AppToastVariant.removed
        ? Border.all(
            color: theme.colorScheme.onSurface.withAlpha(40),
          )
        : null;

    // Если reduce motion — мгновенное появление (Duration.zero в AnimationController
    // значит value = 1 после forward()). При вызове forwardInstant:
    // Используем IgnorePointer-обёртку и сразу показываем полностью.
    final effectiveOpacity = reduce ? 1.0 : _opacity.value;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) {
          // Вычисляем translateY: при входе от +80 до 0, кривая kCurveLift
          // При выходе мы двигаем от 0 до +80, через animateTo(0) — значит
          // ctrl.value: 1→0, поэтому translation = (1 - ctrl.value) * 80.
          final curvedValue = reduce
              ? 1.0
              : kCurveLift.transform(_ctrl.value.clamp(0.0, 1.0));
          final dy = (1.0 - curvedValue) * _slidePixels;

          return Transform.translate(
            offset: Offset(0, dy),
            child: Opacity(
              opacity: reduce ? 1.0 : effectiveOpacity,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(_icon(), color: fgColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fgColor,
                    ),
                  ),
                ),
                // Кнопка Undo — для removed и done (если передан onUndo)
                if (widget.onUndo != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: fgColor,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      widget.onUndo!();
                      widget.onDismiss();
                    },
                    child: const Text('Undo'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
