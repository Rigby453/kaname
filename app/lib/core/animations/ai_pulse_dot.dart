// AI-анимации §7.1: пульсирующая точка — индикатор анализа ИИ.
// Виджет знает только о своей анимации — не знает о запросах/состоянии.
// Пока смонтирован — крутится. Остановить → просто убрать из дерева.

import 'package:flutter/material.dart';

import 'constants.dart';

/// Зелёная пульсирующая точка (§7.1 ANIMATIONS.md).
///
/// Внешнее кольцо: scale 1.0 → 1.7 + opacity clamp(0.8 → 0), цикл 1400 мс easeInOut.
/// Центральная точка — статичная.
///
/// При reduce motion — статичная точка без пульса.
class AiPulseDot extends StatefulWidget {
  const AiPulseDot({
    super.key,
    this.size = 8.0,
    this.color,
  });

  /// Диаметр центральной точки.
  final double size;

  /// Цвет точки; если null — берётся colorScheme.primary.
  final Color? color;

  @override
  State<AiPulseDot> createState() => _AiPulseDotState();
}

class _AiPulseDotState extends State<AiPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // длительность цикла из spec §7.1 — не совпадает ни с одной константой,
      // поэтому захардкожена здесь как число из spec
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Запускаем / останавливаем в зависимости от reduce-motion
    if (reduceMotionOf(context)) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final size = widget.size;

    // При reduce motion — просто статичная точка
    if (reduceMotionOf(context)) {
      return _Dot(size: size, color: color);
    }

    // Обёртка в RepaintBoundary: рекомендовано в §7.1 — пульс рисуется
    // независимо от родительского дерева и не вызывает его repaint.
    return RepaintBoundary(
      child: SizedBox(
        // Внешнее кольцо растёт до scale 1.7 от размера точки.
        // Чтобы не было clip, резервируем достаточно места.
        width: size * 2.0,
        height: size * 2.0,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            // Кривая easeInOut из §7.1
            final t = Curves.easeInOut.transform(_controller.value);
            // Opacity: от 0.8 (t=0) до 0 (t=1), clamp дополнительно страхует
            final ringOpacity = (1.0 - t).clamp(0.0, 0.8);
            // Scale: 1.0 → 1.7 (×0.7 из spec)
            final ringScale = 1.0 + t * 0.7;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Внешнее кольцо (§7.1)
                Opacity(
                  opacity: ringOpacity,
                  child: Transform.scale(
                    scale: ringScale,
                    child: _Dot(size: size, color: color),
                  ),
                ),
                // Центральная точка — поверх кольца
                _Dot(size: size, color: color),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Простой круглый виджет — используется и как центр, и как кольцо.
class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
