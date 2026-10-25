import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

// Bhojana's look: a market stall. Cream paper and charcoal, leaf green for
// action and tomato for prices and offers. Soft edges, hairline borders, and
// a faint plate drawn behind every page.

const leaf = Color(0xFF2F7D4F);
const tomato = Color(0xFFD9481E);
const stone = Color(0xFF26302A);
const paper = Color(0xFFFBF6EC);

const headingFont = 'PlusJakartaSans';
const bodyFont = 'Inter';

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Colours for a hairline, a quiet fill and muted text.
Color hairline(BuildContext c) => isDark(c) ? Colors.white12 : const Color(0xFFE2DDD0);
Color softFill(BuildContext c) => isDark(c) ? const Color(0xFF1B231F) : const Color(0xFFEDE9DE);
Color muted(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;

ThemeData bhojanaTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = buildTheme(b, seed: leaf, accent: tomato);
  final scheme = base.colorScheme.copyWith(
    primary: dark ? const Color(0xFF84CFA0) : leaf,
    onPrimary: dark ? const Color(0xFF10201A) : Colors.white,
    tertiary: tomato,
    surface: dark ? const Color(0xFF151C18) : const Color(0xFFFBF9F4),
    surfaceContainerLow: dark ? const Color(0xFF18211C) : const Color(0xFFFBF9F4),
    surfaceContainerHighest: dark ? const Color(0xFF222C26) : const Color(0xFFEDE9DE),
    onSurface: dark ? const Color(0xFFE7EAE4) : stone,
    onSurfaceVariant: dark ? const Color(0xFFA3ADA6) : const Color(0xFF68716B),
  );
  final text = base.textTheme.apply(
    fontFamily: bodyFont,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  TextStyle? heading(TextStyle? s, FontWeight w, [double spacing = -0.3]) =>
      s?.copyWith(fontFamily: headingFont, fontWeight: w, letterSpacing: spacing);
  final type = text.copyWith(
    displaySmall: heading(text.displaySmall, FontWeight.w500, -0.6),
    headlineMedium: heading(text.headlineMedium, FontWeight.w500, -0.5),
    headlineSmall: heading(text.headlineSmall, FontWeight.w500),
    titleLarge: heading(text.titleLarge, FontWeight.w600),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
    bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
  );
  const stadium = StadiumBorder();
  final line = dark ? Colors.white12 : const Color(0xFFE2DDD0);
  OutlineInputBorder field([Color? c, double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c ?? line, width: w),
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: type,
    // The default trailing style is not built from [type], so it would
    // miss the app's font.
    listTileTheme: ListTileThemeData(leadingAndTrailingTextStyle: type.labelLarge),
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.headlineSmall?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    chipTheme: base.chipTheme.copyWith(
      shape: stadium,
      side: BorderSide(color: line),
      backgroundColor: Colors.transparent,
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      checkmarkColor: scheme.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: type.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        side: BorderSide(color: line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: stadium)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: stadium,
      elevation: 2,
      highlightElevation: 3,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: false,
      border: field(),
      enabledBorder: field(),
      focusedBorder: field(scheme.primary, 1.6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF212B25) : stone,
      surfaceTintColor: Colors.transparent,
      indicatorColor: leaf,
      indicatorShape: stadium,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      indicatorShape: stadium,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      selectedLabelTextStyle: type.labelLarge?.copyWith(color: scheme.primary),
      unselectedLabelTextStyle: type.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
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
    snackBarTheme: base.snackBarTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: dark ? const Color(0xFF263229) : stone,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    sliderTheme: base.sliderTheme.copyWith(trackHeight: 4),
  );
}

/// The canvas: cream paper (or night stone) with a plate drawn very faintly
/// in the corner.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? const [Color(0xFF111713), Color(0xFF0C110E)] : const [paper, Color(0xFFEFEBDF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -140,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(460, 460),
                painter: _Plate(leaf.withValues(alpha: dark ? 0.12 : 0.09)),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Plate extends CustomPainter {
  _Plate(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width / 2 - 20, ring);
    canvas.drawCircle(c, size.width / 2 - 90, ring..strokeWidth = 12);
  }

  @override
  bool shouldRepaint(_Plate old) => old.color != color;
}
