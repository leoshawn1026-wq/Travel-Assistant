import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// 雷达图组件 - 多目的地各维度评分可视化
class RadarChartWidget extends StatelessWidget {
  final List<String> labels;
  final List<RadarSeries> series;
  final double size;

  const RadarChartWidget({
    super.key,
    required this.labels,
    required this.series,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarChartPainter(labels: labels, series: series),
      ),
    );
  }
}

class RadarSeries {
  final String name;
  final List<double> values;
  final Color color;

  const RadarSeries({required this.name, required this.values, required this.color});
}

class _RadarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<RadarSeries> series;

  _RadarChartPainter({required this.labels, required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 24;
    final n = labels.length;
    final angleStep = 2 * math.pi / n;

    // 1. 画网格（同心多边形）
    final gridPaint = Paint()
      ..color = AppTheme.divider.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int level = 1; level <= 5; level++) {
      final r = radius * level / 5;
      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = -math.pi / 2 + i * angleStep;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 2. 画辐射线
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // 3. 画标签
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final labelR = radius + 18;
      final x = center.dx + labelR * math.cos(angle);
      final y = center.dy + labelR * math.sin(angle);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withAlpha(180)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // 4. 画数据多边形
    for (final s in series) {
      if (s.values.length < n) continue;
      final dataPaint = Paint()
        ..color = s.color.withAlpha(80)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path();
      for (int i = 0; i < n; i++) {
        final value = s.values[i].clamp(0.0, 5.0) / 5.0;
        final r = radius * value;
        final angle = -math.pi / 2 + i * angleStep;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, dataPaint);
      canvas.drawPath(path, strokePaint);

      // 画数据点
      for (int i = 0; i < n; i++) {
        final value = s.values[i].clamp(0.0, 5.0) / 5.0;
        final r = radius * value;
        final angle = -math.pi / 2 + i * angleStep;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter old) => true;
}
