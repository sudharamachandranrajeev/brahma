import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../domain/models.dart';

// Vani's look: a near-black canvas with soft charcoal cards, one confident
// red for what matters (the selected page, the next action), green for
// growth. Big tight headings, generous radii, and motion that settles:
// content rises in staggered, numbers count up, cards lift under the
// pointer. Everything animated stops when the system asks for reduced motion.

const signal = Color(0xFFE5262B);
const growth = Color(0xFF22C55E);
const ink = Color(0xFF0B0B0D);

const headingFont = 'PlusJakartaSans';
const bodyFont = 'Inter';

/// Card radius used across the app.
const cardRadius = 28.0;

/// Colours that the theme's scheme has no slot for.
class Tone {
  Tone._(this.canvas, this.card, this.cardHigh, this.stroke, this.muted, this.text);

  factory Tone.of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static final _dark = Tone._(
    const Color(0xFF09090B),
    const Color(0xFF17171A),
    const Color(0xFF222226),
    const Color(0x14FFFFFF),
    const Color(0xFF8E8E96),
    const Color(0xFFF4F4F5),
  );
  static final _light = Tone._(
    const Color(0xFFF1F1F4),
    Colors.white,
    const Color(0xFFF4F4F6),
    const Color(0x140B0B0D),
    const Color(0xFF6B6B74),
    ink,
  );

  final Color canvas, card, cardHigh, stroke, muted, text;
}

ThemeData vaniTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = buildTheme(b, seed: signal, accent: growth);
  final tone = dark ? Tone._dark : Tone._light;
  final scheme = base.colorScheme.copyWith(
    primary: signal,
    onPrimary: Colors.white,
    secondary: growth,
    surface: tone.card,
    onSurface: tone.text,
    onSurfaceVariant: tone.muted,
    surfaceContainerLow: tone.card,
    surfaceContainer: tone.card,
    surfaceContainerHigh: tone.cardHigh,
    surfaceContainerHighest: tone.cardHigh,
    outline: tone.stroke,
    outlineVariant: tone.stroke,
    errorContainer: dark ? const Color(0xFF3A1416) : const Color(0xFFFFE2E2),
    onErrorContainer: dark ? const Color(0xFFFFB4B4) : const Color(0xFF7A1014),
  );
  final text = base.textTheme.apply(fontFamily: bodyFont, bodyColor: tone.text, displayColor: tone.text);
  TextStyle? heading(TextStyle? s, FontWeight w, [double spacing = -0.4]) =>
      s?.copyWith(fontFamily: headingFont, fontWeight: w, letterSpacing: spacing);
  final type = text.copyWith(
    displayLarge: heading(text.displayLarge, FontWeight.w800, -2),
    displayMedium: heading(text.displayMedium, FontWeight.w800, -1.6),
    displaySmall: heading(text.displaySmall, FontWeight.w800, -1.2),
    headlineLarge: heading(text.headlineLarge, FontWeight.w800, -1),
    headlineMedium: heading(text.headlineMedium, FontWeight.w700, -0.8),
    headlineSmall: heading(text.headlineSmall, FontWeight.w700, -0.5),
    titleLarge: heading(text.titleLarge, FontWeight.w700, -0.3),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
    titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: text.bodyLarge?.copyWith(height: 1.5, letterSpacing: 0),
    bodyMedium: text.bodyMedium?.copyWith(height: 1.45, letterSpacing: 0),
    bodySmall: text.bodySmall?.copyWith(color: tone.muted),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
  );
  const stadium = StadiumBorder();
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: tone.stroke),
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: type,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: bodyFont),
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: tone.card,
    dividerColor: tone.stroke,
    dividerTheme: DividerThemeData(color: tone.stroke, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: tone.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.headlineSmall?.copyWith(fontSize: 24),
    ),
    cardTheme: CardThemeData(
      color: tone.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: tone.stroke),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: stadium,
      side: BorderSide(color: tone.stroke),
      backgroundColor: tone.cardHigh,
      selectedColor: signal,
      secondarySelectedColor: signal,
      checkmarkColor: Colors.white,
      labelStyle: type.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : tone.text,
        ),
      ),
      secondaryLabelStyle: type.labelLarge?.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(stadium),
        side: WidgetStatePropertyAll(BorderSide(color: tone.stroke)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? signal : tone.cardHigh,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : tone.text,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : tone.text,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: signal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: type.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tone.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: tone.stroke),
        backgroundColor: tone.cardHigh,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tone.text, shape: stadium),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: tone.text)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: signal,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      extendedTextStyle: type.labelLarge?.copyWith(fontSize: 15, color: Colors.white),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: tone.cardHigh,
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(borderSide: const BorderSide(color: signal, width: 1.6)),
      hintStyle: TextStyle(color: tone.muted),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? signal : tone.cardHigh,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: WidgetStatePropertyAll(tone.stroke),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? signal : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(color: signal, borderRadius: BorderRadius.circular(999)),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: tone.muted,
      labelStyle: type.labelLarge,
      splashBorderRadius: BorderRadius.circular(999),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF1C1C20) : ink,
      surfaceTintColor: Colors.transparent,
      indicatorColor: signal,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tone.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      titleTextStyle: type.headlineSmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tone.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tone.cardHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(tone.cardHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: dark ? const Color(0xFF26262B) : ink,
      contentTextStyle: type.bodyMedium?.copyWith(color: Colors.white),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconColor: tone.muted,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: signal, linearTrackColor: tone.cardHigh),
    tooltipTheme: base.tooltipTheme.copyWith(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2A30) : ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: type.bodySmall?.copyWith(color: Colors.white),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: SharedAxisPageTransitionsBuilder()},
    ),
  );
}

/// The canvas behind every page: near-black (or soft grey) with one faint
/// red glow in the corner.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: tone.canvas,
      child: Stack(
        children: [
          Positioned(
            top: -260,
            right: -200,
            child: IgnorePointer(
              child: Container(
                width: 620,
                height: 620,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      signal.withValues(alpha: dark ? 0.16 : 0.09),
                      signal.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Pushed pages come forward along the z axis: the new page scales up from
/// 94% and fades in while the old one recedes (Material's shared axis).
class SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    child = Backdrop(child: child);
    if (Motion.reduced(context)) return FadeTransition(opacity: animation, child: child);
    final inT = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    final outT = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: Listenable.merge([inT, outT]),
      child: child,
      builder: (context, child) {
        final t = inT.value, back = outT.value;
        final scale = (0.94 + 0.06 * t) * (1 + 0.04 * back);
        return Opacity(
          opacity: (Interval(0.2, 1).transform(t.clamp(0, 1)) * (1 - back)).clamp(0, 1).toDouble(),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

/// A rounded charcoal card. [onTap] makes it lift under the pointer.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
    this.radius = cardRadius,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: tone.stroke),
    );
    Widget card = Material(
      color: color ?? tone.card,
      shape: shape,
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    if (onTap != null) card = Lift(child: card);
    return card;
  }
}

/// Lifts its child a little and deepens its shadow while the pointer is
/// over it; presses sink it.
class Lift extends StatefulWidget {
  const Lift({super.key, required this.child, this.amount = 1.02});
  final Widget child;
  final double amount;

  @override
  State<Lift> createState() => _LiftState();
}

class _LiftState extends State<Lift> {
  var _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    final scale = _down ? 0.98 : (_hover ? widget.amount : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translateByDouble(0, _hover ? -3 : 0, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            boxShadow: [
              if (_hover)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades and lifts its child in, [index] steps after the first sibling.
class Stagger extends StatelessWidget {
  const Stagger(this.index, {super.key, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final delay = Duration(milliseconds: 55 * index.clamp(0, 10));
    final total = const Duration(milliseconds: 520) + delay;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutQuart),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
    );
  }
}

/// A number that counts up to [value] when shown or changed.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style, this.format = compactNumber, this.suffix = ''});
  final num value;
  final TextStyle? style;
  final String Function(num) format;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text('${format(value)}$suffix', style: style?.merge(tabular));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutExpo,
      builder: (context, v, _) =>
          Text('${format(value is int ? v.round() : v)}$suffix', style: style?.merge(tabular)),
    );
  }
}

/// 24800 as "24.8K", 1200000 as "1.2M".
String compactNumber(num n) {
  final a = n.abs();
  String trim(double v) => v.toStringAsFixed(v >= 100 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '');
  if (a >= 1e6) return '${trim(n / 1e6)}M';
  if (a >= 1e4) return '${trim(n / 1e3)}K';
  if (n is double) return n.toStringAsFixed(1);
  return '$n';
}

/// "+2.5%" on green, "-1.0%" on red.
class DeltaChip extends StatelessWidget {
  const DeltaChip(this.percent, {super.key});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    final c = up ? growth : signal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
      child: Text(
        '${up ? '+' : ''}${percent.toStringAsFixed(1)}%',
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700).merge(tabular),
      ),
    );
  }
}

/// Thin vertical bars rising from dim to bright, like a level meter; the
/// newest are brightest. Bars beyond [filled] are drawn as empty slots.
class MeterBars extends StatelessWidget {
  const MeterBars({super.key, required this.values, this.color = growth, this.slots = 40, this.height = 44});
  final List<double> values;
  final Color color;
  final int slots;
  final double height;

  @override
  Widget build(BuildContext context) {
    final empty = Tone.of(context).stroke.withValues(alpha: 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _MeterPainter(values, color, empty, slots, t),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.values, this.color, this.empty, this.slots, this.t);
  final List<double> values;
  final Color color, empty;
  final int slots;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final gap = 3.0;
    final w = math.max(1.5, (size.width - gap * (slots - 1)) / slots);
    final peak = values.fold<double>(0, math.max);
    final n = values.length.clamp(0, slots);
    for (var i = 0; i < slots; i++) {
      final x = i * (w + gap);
      final paint = Paint()..strokeCap = StrokeCap.round;
      if (i < n && peak > 0) {
        final v = values[values.length - n + i] / peak;
        final h = (0.25 + 0.75 * v) * size.height * t;
        paint.color = color.withValues(alpha: 0.35 + 0.65 * (i / math.max(1, n - 1)));
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, w, h), Radius.circular(w / 2)),
          paint,
        );
      } else {
        paint.color = empty;
        final h = size.height * 0.85;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, w, h), Radius.circular(w / 2)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) => old.t != t || old.values != values || old.color != color;
}

/// A half-ring gauge filled to [fraction] in green, with a label inside.
class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.fraction, this.size = 96, this.label = '%'});
  final double fraction;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final track = Tone.of(context).stroke;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: Motion.reduced(context) ? fraction : 0, end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 1300),
      curve: Curves.easeOutCubic,
      builder: (context, f, _) => SizedBox(
        width: size,
        height: size * 0.62,
        child: CustomPaint(
          painter: _GaugePainter(f, track),
          child: Align(
            alignment: const Alignment(0, 0.7),
            child: Text(
              label,
              style: TextStyle(color: growth, fontWeight: FontWeight.w800, fontSize: size * 0.22),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.f, this.track);
  final double f;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.width / 2),
      radius: size.width / 2 - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi * 1.05, math.pi * 0.9, false, base);
    canvas.drawArc(
      rect,
      math.pi * 1.05,
      math.pi * 0.9 * f,
      false,
      base
        ..shader = const LinearGradient(colors: [Color(0xFF15803D), growth]).createShader(rect)
        ..color = growth,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.f != f || old.track != track;
}

/// Text scrolling sideways forever, like a news ticker. Static when the
/// system asks for reduced motion.
class Marquee extends StatefulWidget {
  const Marquee(this.text, {super.key, this.style, this.speed = 40});
  final String text;
  final TextStyle? style;

  /// Logical pixels per second.
  final double speed;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 20));
  double _width = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tp = TextPainter(
      text: TextSpan(text: '${widget.text}   ', style: widget.style ?? DefaultTextStyle.of(context).style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _width = tp.width;
    tp.dispose();
    if (_width > 0) _c.duration = Duration(milliseconds: (_width / widget.speed * 1000).round());
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = Text('${widget.text}   ', style: widget.style, maxLines: 1, softWrap: false);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Transform.translate(offset: Offset(-_c.value * _width, 0), child: child),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [line, line, line, line]),
      ),
    );
  }
}

/// A grey placeholder block that shimmers while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = 12});
  final double height, width, radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final x = _c.value * 3 - 1.5;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [tone.cardHigh, tone.stroke.withValues(alpha: 0.35), tone.cardHigh],
            ),
          ),
        );
      },
    );
  }
}

/// A page's loading state: a few shimmering cards.
class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 18, width: 160 + 40.0 * (i % 3)),
                  const SizedBox(height: 12),
                  const Skeleton(height: 12),
                  const SizedBox(height: 8),
                  const Skeleton(height: 12, width: 220),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Brand colours and marks of each platform.
class PlatformStyle {
  const PlatformStyle(this.colors, this.icon);
  final List<Color> colors;
  final FaIconData icon;

  Color get color => colors.first;

  static PlatformStyle of(Platform p) => switch (p) {
    Platform.instagram => const PlatformStyle([
      Color(0xFFDD2A7B),
      Color(0xFFF58529),
      Color(0xFF8134AF),
    ], FontAwesomeIcons.instagram),
    Platform.facebook => const PlatformStyle([
      Color(0xFF1877F2),
      Color(0xFF3B8BFF),
    ], FontAwesomeIcons.facebookF),
    Platform.youtube => const PlatformStyle([Color(0xFFFF0033), Color(0xFFE52D27)], FontAwesomeIcons.youtube),
    Platform.linkedin => const PlatformStyle([
      Color(0xFF0A66C2),
      Color(0xFF2D84D8),
    ], FontAwesomeIcons.linkedinIn),
    Platform.threads => const PlatformStyle([Color(0xFF2B2B30), Color(0xFF444450)], FontAwesomeIcons.threads),
    Platform.bluesky => const PlatformStyle([Color(0xFF1185FE), Color(0xFF4EA5FF)], FontAwesomeIcons.bluesky),
    Platform.mastodon => const PlatformStyle([
      Color(0xFF6364FF),
      Color(0xFF563ACC),
    ], FontAwesomeIcons.mastodon),
  };
}

/// A round button-like badge in the platform's colours with its mark.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge(this.platform, {super.key, this.size = 40, this.ring = false});
  final Platform platform;
  final double size;

  /// A thin ring of the canvas colour around it, for badges sitting on images.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final s = PlatformStyle.of(platform);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: s.colors),
        border: ring ? Border.all(color: Tone.of(context).card, width: 2.5) : null,
        boxShadow: [
          BoxShadow(
            color: s.color.withValues(alpha: 0.35),
            blurRadius: size / 3,
            offset: Offset(0, size / 10),
          ),
        ],
      ),
      child: FaIcon(s.icon, size: size * 0.46, color: Colors.white),
    );
  }
}

/// An image from the web, or (when there is none or it fails) generated art:
/// a soft mesh of the platform's colours keyed by [seed], so the same post
/// always looks the same.
class Artwork extends StatelessWidget {
  const Artwork({super.key, this.url, required this.seed, this.platform, this.fit = BoxFit.cover});
  final String? url;
  final String seed;
  final Platform? platform;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = _Mesh(seed: seed, platform: platform);
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
      frameBuilder: (context, child, frame, sync) => sync || frame != null
          ? AnimatedOpacity(opacity: 1, duration: Motion.medium, child: child)
          : Stack(fit: StackFit.expand, children: [fallback, child]),
    );
  }
}

class _Mesh extends StatelessWidget {
  const _Mesh({required this.seed, this.platform});
  final String seed;
  final Platform? platform;

  static const _palettes = [
    [Color(0xFFFF6A3D), Color(0xFFB4261E), Color(0xFF2B0B0B)],
    [Color(0xFFFF9A8B), Color(0xFFFF6A88), Color(0xFF3B1C32)],
    [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF191654)],
    [Color(0xFF43C6AC), Color(0xFF191654), Color(0xFF0B1E2D)],
    [Color(0xFFF7971E), Color(0xFFFFD200), Color(0xFF3A2A00)],
    [Color(0xFFDA4453), Color(0xFF89216B), Color(0xFF1A0A1F)],
    [Color(0xFF00C6FF), Color(0xFF0072FF), Color(0xFF00122E)],
    [Color(0xFFE0C3FC), Color(0xFF8EC5FC), Color(0xFF2A2140)],
  ];

  static int _hash(String s) => s.codeUnits.fold(0x811C9DC5, (h, c) => ((h ^ c) * 0x01000193) & 0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final h = _hash(seed);
    final colors = _palettes[h % _palettes.length];
    final a = Alignment(((h >> 4) % 200) / 100 - 1, ((h >> 12) % 200) / 100 - 1);
    final b = Alignment(((h >> 20) % 200) / 100 - 1, ((h >> 8) % 200) / 100 - 1);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: a,
              radius: 0.9,
              colors: [colors[1].withValues(alpha: 0.9), colors[1].withValues(alpha: 0)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: b,
              radius: 0.7,
              colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
            ),
          ),
        ),
        if (platform != null)
          Align(
            alignment: const Alignment(0.75, -0.6),
            child: FaIcon(
              PlatformStyle.of(platform!).icon,
              size: 64,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
      ],
    );
  }
}

/// A person's picture, or their initial on a tinted circle.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 40});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = Text(
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.42, color: Colors.white),
    );
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) * 37) % 360;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? ColoredBox(
                color: HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.42).toColor(),
                child: Center(child: letter),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.42).toColor(),
                  child: Center(child: letter),
                ),
              ),
      ),
    );
  }
}

/// A small tinted label.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final fg = color ?? tone.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.15) ?? tone.cardHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour and icon of a post or target status.
({Color color, IconData icon, String label}) statusLook(String status) => switch (status) {
  'published' => (color: growth, icon: Icons.check_circle_rounded, label: 'Published'),
  'scheduled' => (color: const Color(0xFF3B82F6), icon: Icons.schedule_rounded, label: 'Scheduled'),
  'publishing' => (color: const Color(0xFFF59E0B), icon: Icons.sync_rounded, label: 'Publishing'),
  'failed' => (color: signal, icon: Icons.error_rounded, label: 'Failed'),
  _ => (color: const Color(0xFF8E8E96), icon: Icons.edit_note_rounded, label: 'Draft'),
};

/// A section heading with an optional action on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: Tone.of(context).muted,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(action!),
          ),
      ],
    ),
  );
}

/// A page title block: a big heading and a muted line under it.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 12,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: (narrow ? t.headlineMedium : t.displaySmall)?.copyWith(height: 1.05)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: t.bodyMedium?.copyWith(color: Tone.of(context).muted)),
              ],
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// A scrolling page body with the app's gutters, limited to a wide but
/// readable width, with room at the bottom for the floating nav bar.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1500, this.controller});
  final List<Widget> children;
  final double maxWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        narrow ? 16 : 28,
        narrow ? 12 + MediaQuery.paddingOf(context).top : 28,
        narrow ? 16 : 28,
        110 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final (i, c) in children.indexed) Stagger(i, child: c)],
            ),
          ),
        ),
      ],
    );
  }
}
