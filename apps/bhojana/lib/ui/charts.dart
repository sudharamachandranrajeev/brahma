import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'look.dart';

/// One row of [BarRows].
class BarRow {
  const BarRow({
    required this.label,
    required this.figure,
    required this.value,
    required this.tone,
    this.caption = '',
    this.stress = false,
    this.trailing,
  });
  final String label;
  final String figure;
  final int value;
  final (Color, Color) tone;
  final String caption;

  /// Draws the figure in coral: the cheapest, the one to pick.
  final bool stress;
  final Widget? trailing;
}

/// Pastel bars, one per row, longest for the largest value: the reference's
/// bar chart turned on its side so shop names fit on a phone.
class BarRows extends StatelessWidget {
  const BarRows(this.rows, {super.key});
  final List<BarRow> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = rows.fold(1, (m, r) => r.value > m ? r.value : m);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(child: Text(r.label, style: text.titleSmall)),
                          Text(
                            r.figure,
                            style: text.titleMedium?.copyWith(color: r.stress ? priceInk(context) : null),
                          ),
                        ],
                      ),
                      if (r.caption.isNotEmpty)
                        Text(
                          r.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: muted(context)),
                        ),
                      const SizedBox(height: 6),
                      _Bar(fraction: r.value / top, tone: r.tone),
                    ],
                  ),
                ),
                ?r.trailing,
              ],
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.tone});
  final double fraction;
  final (Color, Color) tone;

  @override
  Widget build(BuildContext context) => Container(
    height: 12,
    decoration: BoxDecoration(color: softFill(context), borderRadius: BorderRadius.circular(6)),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fraction.clamp(0.04, 1.0),
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(colors: [Color.lerp(tone.$2, Colors.white, 0.35)!, tone.$2]),
        ),
      ),
    ),
  );
}

/// A soft line of the lowest price on each day, oldest on the left, with the
/// first and last day beneath.
class PriceTrend extends StatelessWidget {
  const PriceTrend(this.days, {super.key});

  /// (ISO day, pence), oldest first.
  final List<(String, int)> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _TrendPainter(
              [for (final d in days) d.$2],
              line: scheme.primary,
              grid: hairline(context),
              dot: scheme.surface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(niceDate(days.first.$1), style: small),
            Text(niceDate(days.last.$1), style: small),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, {required this.line, required this.grid, required this.dot});
  final List<int> values;
  final Color line;
  final Color grid;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    // A flat price sits in the middle rather than on an edge.
    final span = high == low ? 2 : high - low;
    final base = high == low ? low - 1 : low;
    const pad = 10.0;
    Offset at(int i) => Offset(
      pad + (size.width - 2 * pad) * i / (values.length - 1),
      pad + (size.height - 2 * pad) * (1 - (values[i] - base) / span),
    );
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = pad + (size.height - 2 * pad) * k / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = at(i - 1), b = at(i);
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final area = Path.from(path)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(at(i), 5, Paint()..color = line);
      canvas.drawCircle(at(i), 2.5, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.line != line || old.grid != grid || old.dot != dot || !listEquals(old.values, values);
}
