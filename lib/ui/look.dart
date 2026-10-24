import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

// Udyoga's look: a calm, airy canvas (soft azure light, deep navy at night)
// so the content stands forward; white cards lifted by soft tinted shadows;
// an ink pill navigation bar with an azure indicator; motion that adds depth
// (cards tilt towards the pointer, pages rise in) and stops when the system
// asks for reduced motion.

const azure = Color(0xFF2F6BFF);
const ink = Color(0xFF0B1020);
const mint = Color(0xFF12B886);

/// Headings: Plus Jakarta Sans. Reading text: Inter, made for screens.
const headingFont = 'PlusJakartaSans';
const bodyFont = 'Inter';

/// The canvas colours behind every page.
({Color top, Color bottom, Color glow, Color glow2}) canvas(Brightness b) => b == Brightness.dark
    ? (
        top: const Color(0xFF0A1022),
        bottom: const Color(0xFF05070F),
        glow: const Color(0x552F6BFF),
        glow2: const Color(0x3312B886),
      )
    : (
        top: const Color(0xFFDDE8FF),
        bottom: const Color(0xFFF7F9FD),
        glow: const Color(0x662F6BFF),
        glow2: const Color(0x3312B886),
      );

ThemeData udyogaTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = buildTheme(b, seed: azure, accent: mint);
  final scheme = base.colorScheme.copyWith(
    primary: dark ? const Color(0xFF6E9BFF) : azure,
    onPrimary: Colors.white,
    surface: dark ? const Color(0xFF0E1426) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF121A30) : Colors.white,
    surfaceContainerHighest: dark ? const Color(0xFF1A2440) : const Color(0xFFEFF3FB),
  );
  final c = canvas(b);
  final shadow = dark ? Colors.black : azure.withValues(alpha: 0.35);
  final text = base.textTheme.apply(
    fontFamily: bodyFont,
    bodyColor: dark ? const Color(0xFFE8ECF6) : ink,
    displayColor: dark ? Colors.white : ink,
  );
  TextStyle? heading(TextStyle? s, FontWeight w, [double spacing = -0.4]) =>
      s?.copyWith(fontFamily: headingFont, fontWeight: w, letterSpacing: spacing);
  final type = text.copyWith(
    displayLarge: heading(text.displayLarge, FontWeight.w800, -1.2),
    displayMedium: heading(text.displayMedium, FontWeight.w800, -1),
    displaySmall: heading(text.displaySmall, FontWeight.w700, -0.8),
    headlineLarge: heading(text.headlineLarge, FontWeight.w700, -0.6),
    headlineMedium: heading(text.headlineMedium, FontWeight.w700, -0.5),
    headlineSmall: heading(text.headlineSmall, FontWeight.w700),
    titleLarge: heading(text.titleLarge, FontWeight.w700, -0.3),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
    titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: text.bodyLarge?.copyWith(height: 1.5, letterSpacing: 0),
    bodyMedium: text.bodyMedium?.copyWith(height: 1.45, letterSpacing: 0),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
  );
  const stadium = StadiumBorder();
  return base.copyWith(
    colorScheme: scheme,
    textTheme: type,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: bodyFont),
    // The canvas (see Backdrop) shows through every page.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: c.top.withValues(alpha: dark ? 0.92 : 0.86),
      foregroundColor: type.titleLarge?.color,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.headlineSmall?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 0 : 2.5,
      shadowColor: shadow.withValues(alpha: dark ? 0.6 : 0.22),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE6ECF7)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: stadium,
      side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFDCE3F0)),
      backgroundColor: dark ? const Color(0xFF141C33) : Colors.white,
      selectedColor: dark ? Colors.white : ink,
      secondarySelectedColor: dark ? Colors.white : ink,
      checkmarkColor: dark ? ink : Colors.white,
      labelStyle: type.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (dark ? ink : Colors.white)
              : type.labelLarge?.color ?? scheme.onSurface,
        ),
      ),
      secondaryLabelStyle: type.labelLarge?.copyWith(color: dark ? ink : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(stadium),
        side: WidgetStatePropertyAll(BorderSide(color: dark ? Colors.white24 : const Color(0xFFDCE3F0))),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (dark ? Colors.white : ink) : scheme.surfaceContainerLow,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (dark ? ink : Colors.white) : type.bodyLarge?.color,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: type.labelLarge?.copyWith(fontSize: 15),
        elevation: 3,
        shadowColor: shadow,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFD5DDEC)),
        backgroundColor: scheme.surfaceContainerLow,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: stadium)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: azure,
      foregroundColor: Colors.white,
      shape: stadium,
      elevation: 6,
      highlightElevation: 10,
      extendedTextStyle: type.labelLarge?.copyWith(fontSize: 15, color: Colors.white),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: dark ? const Color(0xFF131B31) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFDCE3F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFDCE3F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Lifted off the night canvas so it still reads as floating.
      backgroundColor: dark ? const Color(0xFF222C4D) : ink,
      surfaceTintColor: Colors.transparent,
      indicatorColor: azure,
      indicatorShape: stadium,
      elevation: 0,
      height: 64,
      // Icons only, like the reference designs; the tooltip names each.
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        type.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: azure,
      indicatorShape: stadium,
      selectedIconTheme: const IconThemeData(color: Colors.white),
      selectedLabelTextStyle: type.labelLarge?.copyWith(color: scheme.primary),
      unselectedLabelTextStyle: type.labelLarge?.copyWith(
        color: type.bodyMedium?.color?.withValues(alpha: 0.7),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: type.headlineSmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: dark ? const Color(0xFF1C2643) : ink,
    ),
    sliderTheme: base.sliderTheme.copyWith(trackHeight: 6),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: RisePageTransitionsBuilder(),
        TargetPlatform.linux: RisePageTransitionsBuilder(),
        TargetPlatform.windows: RisePageTransitionsBuilder(),
        TargetPlatform.macOS: RisePageTransitionsBuilder(),
        TargetPlatform.iOS: RisePageTransitionsBuilder(),
        TargetPlatform.fuchsia: RisePageTransitionsBuilder(),
      },
    ),
  );
}

/// The canvas: a soft vertical wash with two faint glows, behind every page.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = canvas(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.top, c.bottom],
          stops: const [0, 0.55],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -160, right: -120, child: _Glow(c.glow, 420)),
          Positioned(bottom: -200, left: -160, child: _Glow(c.glow2, 460)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow(this.color, this.size);
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Pushed pages rise into place from slightly below and behind, while the
/// page underneath recedes: depth without a slide across the screen.
class RisePageTransitionsBuilder extends PageTransitionsBuilder {
  const RisePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Each page brings its own canvas, so the page beneath never shows through.
    child = Backdrop(child: child);
    if (Motion.reduced(context)) return FadeTransition(opacity: animation, child: child);
    final inCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: Listenable.merge([inCurve, outCurve]),
      child: child,
      builder: (context, child) {
        final t = inCurve.value;
        final back = outCurve.value;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0009)
          ..translateByDouble(0, (1 - t) * 48, 0, 1)
          ..rotateX((1 - t) * 0.08)
          ..scaleByDouble(1 - back * 0.04, 1 - back * 0.04, 1, 1);
        return Opacity(
          opacity: (t.clamp(0, 1) * (1 - back * 0.3)).toDouble(),
          child: Transform(transform: m, alignment: Alignment.topCenter, child: child),
        );
      },
    );
  }
}

/// Tilts its child towards the pointer in 3D and lifts it on hover; presses
/// sink it slightly. Static when the system asks for reduced motion.
class Tilt extends StatefulWidget {
  const Tilt({super.key, required this.child, this.maxAngle = 0.07});
  final Widget child;

  /// Radians at the edges.
  final double maxAngle;

  @override
  State<Tilt> createState() => _TiltState();
}

class _TiltState extends State<Tilt> {
  var _x = 0.0, _y = 0.0;
  var _hover = false, _down = false;

  void _move(Offset local, Size size) {
    setState(() {
      _x = (local.dx / size.width - 0.5) * 2;
      _y = (local.dy / size.height - 0.5) * 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth.isFinite ? box.maxWidth : 300, 120);
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onHover: (e) {
            final rb = context.findRenderObject() as RenderBox?;
            _move(e.localPosition, rb?.size ?? size);
          },
          onExit: (_) => setState(() {
            _hover = false;
            _x = 0;
            _y = 0;
          }),
          child: Listener(
            onPointerDown: (_) => setState(() => _down = true),
            onPointerUp: (_) => setState(() => _down = false),
            onPointerCancel: (_) => setState(() => _down = false),
            child: TweenAnimationBuilder<Offset>(
              tween: Tween(end: _hover ? Offset(_x, _y) : Offset.zero),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, o, child) {
                final scale = _down ? 0.985 : (_hover ? 1.012 : 1.0);
                final m = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX(-o.dy * widget.maxAngle)
                  ..rotateY(o.dx * widget.maxAngle)
                  ..scaleByDouble(scale, scale, 1, 1);
                return AnimatedSlide(
                  offset: Offset(0, _hover ? -0.012 : 0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Transform(transform: m, alignment: Alignment.center, child: child),
                );
              },
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// An employer's mark: its initials on a gradient picked from its name, so
/// the same employer always looks the same (no logos are fetched).
class OrgLogo extends StatelessWidget {
  const OrgLogo(this.name, {super.key, this.size = 44});
  final String name;
  final double size;

  /// FNV-1a: well spread, so similar names still get different colours.
  static int _hash(String s) => s.codeUnits.fold(0x811C9DC5, (h, c) => ((h ^ c) * 0x01000193) & 0xFFFFFFFF);

  static const _palettes = [
    [Color(0xFF2F6BFF), Color(0xFF7A5CFF)],
    [Color(0xFF12B886), Color(0xFF0CA5E9)],
    [Color(0xFFFF7A45), Color(0xFFFF4D7E)],
    [Color(0xFF7A5CFF), Color(0xFFE056FD)],
    [Color(0xFF0EA5E9), Color(0xFF2F6BFF)],
    [Color(0xFFF59F00), Color(0xFFFF6B3D)],
    [Color(0xFF20C997), Color(0xFF2F9E44)],
    [Color(0xFF364FC7), Color(0xFF15AABF)],
  ];

  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w[0].contains(RegExp('[A-Za-z0-9]')));
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    final colors = _palettes[(_hash(name.toLowerCase()) >> 8) % _palettes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Text(
        letters.isEmpty ? '•' : letters,
        style: TextStyle(
          fontFamily: headingFont,
          fontWeight: FontWeight.w800,
          fontSize: size * (letters.length > 1 ? 0.36 : 0.44),
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// A small tinted label: "Remote", "Shortlisted", "Closes in 3 days".
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.status, this.icon});
  final String label;
  final Status? status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = status == null || status == Status.info ? null : status!.color;
    final fg = tone ?? (dark ? Colors.white70 : const Color(0xFF3B4660));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color:
            tone?.withValues(alpha: dark ? 0.18 : 0.1) ?? (dark ? Colors.white10 : const Color(0xFFF1F4FA)),
        borderRadius: BorderRadius.circular(999),
        border: tone == null ? Border.all(color: dark ? Colors.white12 : const Color(0xFFE2E8F3)) : null,
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

/// A big greeting with one phrase picked out in the brand colour.
class Headline extends StatelessWidget {
  const Headline(this.parts, {super.key});

  /// Alternating plain and highlighted runs, starting plain.
  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final base = t.headlineMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.2);
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, p) in parts.indexed)
            TextSpan(
              text: p,
              style: i.isOdd
                  ? base?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)
                  : base,
            ),
        ],
      ),
    );
  }
}

/// A [TileGrid] whose tiles tilt towards the pointer.
class TiltGrid extends StatelessWidget {
  const TiltGrid({super.key, required this.children, this.minWidth = 200});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => TileGrid(
    minWidth: minWidth,
    children: [for (final c in children) Tilt(maxAngle: 0.1, child: c)],
  );
}
