// Универсальный бар+линия чарт без сторонних chart-пакетов (в проекте нет
// fl_chart и т.п. — см. ANIMATIONS.md/CLAUDE.md «no heavy deps»).
// Столбцы — значение за бакет (день/час), линия поверх — тренд
// («ломаная кривая потребления во времени»). Подписи оси X рисуются
// обычными Text-виджетами (не в Canvas) — переживают textScale без overflow.
// Используется в water_report_screen.dart и sleep_report_screen.dart.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BarLineChart extends StatelessWidget {
  const BarLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.goalLine,
    this.height = 120,
    this.highlightIndex,
  });

  /// Значения по бакетам (одна точка = один столбец + одна вершина линии).
  final List<double> values;

  /// Подписи под столбцами, длина должна совпадать с [values].
  /// Пустая строка — подпись не рисуется (для плотных месячных графиков).
  final List<String> labels;

  /// Необязательная горизонтальная пунктирная линия-ориентир (например цель/день).
  final double? goalLine;

  final double height;

  /// Индекс «текущего» бакета (сегодня) — рисуется акцентным цветом без затухания.
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final maxVal = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;
    final chartMax =
        (goalLine != null && goalLine! > safeMax ? goalLine! : safeMax) * 1.08;

    final showLabels = labels.any((l) => l.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarLinePainter(
              values: values,
              maxValue: chartMax,
              barColor: cs.primary,
              lineColor: cs.primary,
              mutedColor: ext.textMuted,
              goalLine: goalLine,
              highlightIndex: highlightIndex,
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              for (final l in labels)
                Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(color: ext.textFaint),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BarLinePainter extends CustomPainter {
  const _BarLinePainter({
    required this.values,
    required this.maxValue,
    required this.barColor,
    required this.lineColor,
    required this.mutedColor,
    this.goalLine,
    this.highlightIndex,
  });

  final List<double> values;
  final double maxValue;
  final Color barColor;
  final Color lineColor;
  final Color mutedColor;
  final double? goalLine;
  final int? highlightIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
    final n = values.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.55).clamp(1.0, slotW);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    // Пунктирная линия-ориентир (цель)
    if (goalLine != null && goalLine! > 0 && goalLine! <= safeMax) {
      final y = size.height * (1 - goalLine! / safeMax);
      final dashPaint = Paint()
        ..color = mutedColor.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      var startX = 0.0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset((startX + dashWidth).clamp(0, size.width), y),
          dashPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final cx = slotW * i + slotW / 2;
      final v = values[i].clamp(0.0, safeMax);
      final barH = safeMax <= 0 ? 0.0 : (v / safeMax) * size.height;
      final top = size.height - barH;
      final isHi = highlightIndex == i;

      if (barH > 0.5) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, top, barW, barH),
          Radius.circular((barW / 2).clamp(0.0, 4.0)),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = barColor.withValues(alpha: isHi ? 0.85 : 0.32),
        );
      }
      points.add(Offset(cx, top));
    }

    // Ломаная кривая тренда поверх столбцов
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      for (final p in points) {
        canvas.drawCircle(p, 2.4, Paint()..color = lineColor);
      }
    } else if (points.length == 1) {
      canvas.drawCircle(points.first, 2.4, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _BarLinePainter old) {
    return old.values != values ||
        old.maxValue != maxValue ||
        old.barColor != barColor ||
        old.lineColor != lineColor ||
        old.goalLine != goalLine ||
        old.highlightIndex != highlightIndex;
  }
}
