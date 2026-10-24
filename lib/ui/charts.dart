import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'zen.dart';

/// A progress ring with [child] in the middle. Animates to new values.
class Ring extends StatelessWidget {
  const Ring({
    super.key,
    required this.value,
    required this.child,
    this.size = 120,
    this.stroke = 10,
    this.color,
  });
  final double value, size, stroke;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, c, softFill(context), stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track, this.stroke);
  final double v, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.width - stroke) / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    if (v > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color || o.track != track;
}

/// Vertical bars with a label under each; the last is highlighted.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, this.height = 120, this.unit = ''});
  final List<num> values;
  final List<String> labels;
  final double height;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final top = values.fold<num>(1, math.max);
    final primary = Theme.of(context).colorScheme.primary;
    final t = Theme.of(context).textTheme.labelSmall?.copyWith(color: muted(context));
    return SizedBox(
      height: height + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, v) in values.indexed)
            Expanded(
              child: Tooltip(
                message: '${labels[i]}: $v$unit',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: v / top),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => Container(
                        height: math.max(4, (height - 4) * f),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == values.length - 1 ? primary : primary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[i], style: t, maxLines: 1, overflow: TextOverflow.clip),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A line through [values] (0 to [max]) with a dot on the latest.
class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.max = 100, this.height = 72});
  final List<double> values;
  final double max, height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _LinePainter(values, max, Theme.of(context).colorScheme.primary, hairline(context)),
    ),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.v, this.max, this.color, this.grid);
  final List<double> v;
  final double max;
  final Color color, grid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), Paint()..color = grid);
    if (v.isEmpty) return;
    Offset at(int i) => Offset(
      v.length == 1 ? size.width / 2 : size.width * i / (v.length - 1),
      size.height - 6 - (size.height - 12) * (v[i] / max).clamp(0, 1),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(v.length - 1), 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.v != v || o.color != color;
}

/// A thin labelled meter: label, bar and a value on the right.
class Meter extends StatelessWidget {
  const Meter(this.label, this.value, {super.key, this.trailing, this.color});
  final String label;
  final double value;
  final String? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (trailing != null)
              Text(trailing!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted(context))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 7, color: color),
          ),
        ),
      ],
    ),
  );
}
