// ANIMATIONS.md §2.3 — галочка при отметке выполнения.
// Кастомный CustomPainter без внешних пакетов.
// Анимация: круг заполняется (scale + fade) + галочка рисуется через PathMetric.
// Reduce motion (MediaQuery.disableAnimations) → конечное состояние без анимации.

import 'package:flutter/material.dart';

import 'constants.dart';

/// Анимированная галочка (§2.3).
///
/// [checked] — текущее состояние.
/// Переход false→true воспроизводит анимацию (200 мс, kCurveSnap).
/// При первом build с checked==true рисует статично (без анимации),
/// чтобы не анимировать каждую строку при открытии экрана.
/// При переходе (didUpdateWidget) — анимирует.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    required this.checked,
    required this.color,
    this.size = 24.0,
    this.animateOnAppear = false,
    super.key,
  });

  final bool checked;
  final Color color;
  final double size;

  /// true → анимировать при ПЕРВОМ появлении уже в checked-состоянии.
  /// Нужно, когда строка списка пересобирается при смене статуса и
  /// AnimatedCheck монтируется сразу с checked=true (переход false→true
  /// через didUpdateWidget в этом случае не случается).
  final bool animateOnAppear;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  // Флаг: анимировать ли при следующем build (false = статично)
  bool _animate = false;

  // Запрошена анимация появления; запускается в didChangeDependencies,
  // т.к. в initState нельзя читать MediaQuery (reduce motion).
  bool _pendingAppearAnimation = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // При reduce motion — Duration.zero не поддерживается до build,
      // используем короткое время; в build учитываем disableAnimations.
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _progress = CurvedAnimation(parent: _controller, curve: kCurveSnap);

    if (widget.checked && widget.animateOnAppear) {
      // Смонтирован сразу done, но это свежий переход — анимируем появление.
      _pendingAppearAnimation = true;
    } else if (widget.checked) {
      // Уже done при создании (открытие экрана) — статично, без анимации.
      _controller.value = 1.0;
      _animate = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendingAppearAnimation) {
      _pendingAppearAnimation = false;
      if (reduceMotionOf(context)) {
        _controller.value = 1.0;
        _animate = false;
      } else {
        _animate = true;
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void didUpdateWidget(AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Анимируем только переход false→true.
    if (!oldWidget.checked && widget.checked) {
      _animate = true;
      final reduce = reduceMotionOf(context);
      if (reduce) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    } else if (!widget.checked) {
      _animate = false;
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.checked) {
      // Незачёркнутое состояние — пустой круг (outline)
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _CheckPainter(
            progress: 0.0,
            color: widget.color,
          ),
        ),
      );
    }

    // Reduce motion → статичная галочка без AnimatedBuilder
    final reduce = reduceMotionOf(context);
    if (reduce || !_animate) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _CheckPainter(
            progress: 1.0,
            color: widget.color,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CheckPainter(
              progress: _progress.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

/// Рисует круг + галочку по прогрессу [0..1].
/// progress==0: пустой outline-круг.
/// progress==1: заполненный круг + полная галочка.
class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // --- Заполненный круг (scale + opacity по progress) ---
    if (progress > 0) {
      final circlePaint = Paint()
        ..color = color.withValues(alpha: progress.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      final circleRadius = radius * progress;
      canvas.drawCircle(center, circleRadius, circlePaint);
    }

    // --- Outline круга (всегда виден, fade out по мере заполнения) ---
    final outlinePaint = Paint()
      ..color = color.withValues(alpha: (1.0 - progress * 0.6).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 1, outlinePaint);

    // --- Галочка через PathMetric (рисуется от 0 до progress) ---
    if (progress > 0) {
      final checkPath = _buildCheckPath(size);
      final pathMetric = checkPath.computeMetrics().first;
      final drawLength = pathMetric.length * progress;
      final extractedPath = pathMetric.extractPath(0, drawLength);

      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(extractedPath, checkPaint);
    }
  }

  /// Строит path галочки внутри заданного size.
  Path _buildCheckPath(Size size) {
    // Точки галочки: левый-нижний угол, нижний центр, правый-верхний угол
    final path = Path();
    path.moveTo(size.width * 0.22, size.height * 0.50);
    path.lineTo(size.width * 0.42, size.height * 0.70);
    path.lineTo(size.width * 0.78, size.height * 0.30);
    return path;
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
