// FL-TODAY-02: Кольцо прогресса для MAIN-задач
// CustomPainter рисует дугу 0→2π×(done/total)
// Анимируется за 300ms (slow из design-tokens) при изменении значения
// Если total=0 — серое полное кольцо

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database.dart';

class ProgressRing extends StatefulWidget {
  const ProgressRing({
    required this.items,
    super.key,
  });

  /// Список MAIN-задач текущего дня (из watchMainItems)
  final List<ItemsTableData> items;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  double _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // slow = 300ms из design-tokens.json
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _updateProgress(animate: false);
  }

  @override
  void didUpdateWidget(ProgressRing old) {
    super.didUpdateWidget(old);
    final newProgress = _computeProgress();
    if (newProgress != _currentProgress) {
      _animateTo(newProgress);
    }
  }

  double _computeProgress() {
    final total = widget.items.length;
    if (total == 0) return 0;
    final done = widget.items
        .where((i) => i.status == 'done' || i.status == 'skipped')
        .length;
    return done / total;
  }

  void _updateProgress({bool animate = true}) {
    final target = _computeProgress();
    if (animate) {
      _animateTo(target);
    } else {
      _currentProgress = target;
      _progressAnimation = Tween<double>(
        begin: target,
        end: target,
      ).animate(_controller);
    }
  }

  void _animateTo(double target) {
    final from = _currentProgress;
    _currentProgress = target;
    _progressAnimation = Tween<double>(
      begin: from,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = widget.items.length;
    final done = total == 0
        ? 0
        : widget.items
            .where((i) => i.status == 'done' || i.status == 'skipped')
            .length;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, _) {
        return SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: _RingPainter(
              progress: total == 0 ? 1.0 : _progressAnimation.value,
              isEmpty: total == 0,
              accentColor: colorScheme.primary,
              // Серый — border из theme extension, fallback на onSurface с opacity
              trackColor: colorScheme.onSurface.withAlpha(30),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total == 0 ? '—' : '$done/$total',
                    style: GoogleFonts.fraunces(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (total > 0)
                    Text(
                      'main',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.isEmpty,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final bool isEmpty;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2; // Начало сверху (12 часов)

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Всегда рисуем полный трек
    canvas.drawCircle(center, radius, trackPaint);

    // Если данных нет — только серый круг
    if (isEmpty) return;

    final progressPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.isEmpty != isEmpty ||
      old.accentColor != accentColor;
}
