// ANIMATIONS.md §1.1 + §1.2 — Lift (hover) и Scale при нажатии.
// Pressable оборачивает child и добавляет визуальный отклик:
//   - onTapDown/Up/Cancel: AnimatedScale 1.0→0.97 (snap 120ms) / →1.0 (fast 180ms)
//   - hover/focus (web/desktop): translateY(-2px), kDurationFast, kCurveLift
// Reduce motion → трансформации отключены.
// onTap НЕ перехватывается (прокидывается опционально через параметр).
// Используется вариант "только визуальный": onTap=null → Pressable реагирует
// только на tapDown/Up визуально, не глотая onTap родителя (ListTile etc.).

import 'package:flutter/material.dart';

import 'constants.dart';

/// Виджет-обёртка для визуального отклика карточек (§1.1 + §1.2).
///
/// По умолчанию [onTap] == null — Pressable добавляет только анимацию
/// нажатия/hover, не перехватывая события tap у дочерних виджетов.
/// Если [onTap] передан — он вызывается при нажатии (используй для
/// элементов без собственного onTap).
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    super.key,
  });

  final Widget child;

  /// Необязательный обработчик нажатия. Если null — событие не захватывается.
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;

  void _onTapDown(TapDownDetails _) {
    if (mounted) setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (mounted) setState(() => _pressed = false);
  }

  void _onTapCancel() {
    if (mounted) setState(() => _pressed = false);
  }

  void _onTap() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);

    Widget child = widget.child;

    // §1.1 Lift: hover/focus → translateY(-2px)
    // MouseRegion используется только на web/desktop (на мобильном нет hover)
    if (!reduce) {
      child = AnimatedContainer(
        duration: kDurationFast,
        curve: kCurveLift,
        transform: Matrix4.translationValues(0, _hovered ? -2.0 : 0.0, 0),
        child: child,
      );

      child = MouseRegion(
        onEnter: (_) {
          if (mounted) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _hovered = false);
        },
        child: child,
      );
    }

    // §1.2 Scale при нажатии: 1.0→0.97→1.0
    if (!reduce) {
      child = AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed ? kDurationSnap : kDurationFast,
        curve: kCurveSnap,
        child: child,
      );
    }

    // GestureDetector для отслеживания tapDown/Up/Cancel.
    // behavior: HitTestBehavior.translucent → не блокирует события у child.
    child = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null ? _onTap : null,
      child: child,
    );

    return child;
  }
}
