import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../domain/aisles.dart';
import '../domain/shops.dart';

// Bhojana's look: a sunny kitchen in soft clay. Warm cream and cocoa ink,
// rounded Nunito, cards that float on gentle shadows, pastel tiles (sage,
// peach, butter, sky, lilac) with glossy icon chips, a floating sage-green
// rail and coral for prices, offers and the main call to action.

const leaf = Color(0xFF3F7A5E);
const tomato = Color(0xFFC4532E);
const stone = Color(0xFF4A3628);
const paper = Color(0xFFFCF5EA);

/// Pastel tile colours, each with the deeper tone for its icon.
const sage = (Color(0xFFD5E6DA), Color(0xFF6FA585));
const peach = (Color(0xFFFADCCB), Color(0xFFEA8A66));
const butter = (Color(0xFFFBE7B5), Color(0xFFDDAA3A));
const sky = (Color(0xFFD3E2EE), Color(0xFF6F9BC0));
const lilac = (Color(0xFFE6DCEE), Color(0xFFA088C0));

/// Every tone, for things coloured in turn (shops, chart bars).
const tones = [sage, peach, butter, sky, lilac];

/// Nunito throughout: rounded, friendly, and clear at small sizes.
const headingFont = 'Nunito';
const bodyFont = 'Nunito';

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Colours for a hairline, a quiet fill and muted text.
Color hairline(BuildContext c) => isDark(c) ? Colors.white10 : const Color(0xFFEFE3D2);
Color softFill(BuildContext c) => isDark(c) ? const Color(0xFF332A23) : const Color(0xFFF6EBDC);
Color muted(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;

/// Coral for prices and offers, lighter at night so it reads on cocoa.
Color priceInk(BuildContext c) => Theme.of(c).colorScheme.tertiary;

/// A pastel tile's fill: the pastel itself by day, a glaze of it by night.
Color tileFill(BuildContext c, (Color, Color) tone) =>
    isDark(c) ? Color.alphaBlend(tone.$2.withValues(alpha: 0.2), const Color(0xFF2A231D)) : tone.$1;

/// The soft drop shadow under clay cards and tiles.
List<BoxShadow> clayShadow(BuildContext c) => [
  BoxShadow(
    color: isDark(c) ? Colors.black38 : const Color(0xFF8A6A4A).withValues(alpha: 0.13),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
];

ThemeData bhojanaTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = buildTheme(b, seed: leaf, accent: tomato);
  final card = dark ? const Color(0xFF2A231D) : const Color(0xFFFFFAF3);
  final scheme = base.colorScheme.copyWith(
    primary: dark ? const Color(0xFF9CD1B3) : leaf,
    onPrimary: dark ? const Color(0xFF13261C) : Colors.white,
    secondaryContainer: dark ? const Color(0xFF3A4A40) : sage.$1,
    onSecondaryContainer: dark ? const Color(0xFFDCEBE1) : const Color(0xFF2E5A45),
    tertiary: dark ? const Color(0xFFF0A07F) : tomato,
    surface: dark ? const Color(0xFF221C17) : const Color(0xFFFFFAF3),
    surfaceContainerLow: card,
    surfaceContainerHighest: dark ? const Color(0xFF3A3029) : const Color(0xFFF3E7D6),
    onSurface: dark ? const Color(0xFFF2E8DD) : stone,
    onSurfaceVariant: dark ? const Color(0xFFBBAA99) : const Color(0xFF85705D),
  );
  final text = base.textTheme.apply(
    fontFamily: bodyFont,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  TextStyle? heading(TextStyle? s, FontWeight w, [double spacing = -0.3]) =>
      s?.copyWith(fontFamily: headingFont, fontWeight: w, letterSpacing: spacing);
  final type = text.copyWith(
    displaySmall: heading(text.displaySmall, FontWeight.w900, -0.6),
    headlineMedium: heading(text.headlineMedium, FontWeight.w900, -0.4),
    headlineSmall: heading(text.headlineSmall, FontWeight.w800, -0.2),
    titleLarge: heading(text.titleLarge, FontWeight.w800, -0.1),
    titleMedium: heading(text.titleMedium, FontWeight.w800, 0),
    titleSmall: heading(text.titleSmall, FontWeight.w700, 0),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: text.bodyLarge?.copyWith(height: 1.5, fontWeight: FontWeight.w500),
    bodyMedium: text.bodyMedium?.copyWith(height: 1.45, fontWeight: FontWeight.w500),
  );
  const stadium = StadiumBorder();
  final line = dark ? Colors.white10 : const Color(0xFFEFE3D2);
  final rail = dark ? const Color(0xFF26302A) : const Color(0xFFCFE2D5);
  final railInk = dark ? const Color(0xFFDCEBE1) : const Color(0xFF2E5A45);
  OutlineInputBorder field([Color? c, double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
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
      titleTextStyle: type.headlineMedium?.copyWith(fontSize: 26),
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      shadowColor: dark ? Colors.black : const Color(0xFF8A6A4A).withValues(alpha: 0.45),
      elevation: dark ? 2 : 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: dark ? BorderSide(color: line) : BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      side: BorderSide(color: scheme.onSurfaceVariant, width: 1.6),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: stadium,
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: type.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        side: BorderSide.none,
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: stadium)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide(color: line),
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: stadium,
      elevation: 3,
      highlightElevation: 4,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: card,
      border: field(),
      enabledBorder: field(),
      focusedBorder: field(scheme.primary, 1.6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: rail,
      surfaceTintColor: Colors.transparent,
      indicatorColor: card,
      indicatorShape: stadium,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : railInk),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: rail,
      indicatorColor: card,
      indicatorShape: stadium,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme: IconThemeData(color: railInk),
      selectedLabelTextStyle: type.labelLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: type.labelLarge?.copyWith(color: railInk),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      titleTextStyle: type.headlineSmall,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: dark ? const Color(0xFF3A3029) : stone,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    sliderTheme: base.sliderTheme.copyWith(trackHeight: 4),
  );
}

/// The canvas: warm cream (or cocoa at night) with soft pastel glows in two
/// corners.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    Widget glow(Color c, double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              c.withValues(alpha: dark ? 0.14 : 0.55),
              c.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? const [Color(0xFF1E1915), Color(0xFF16120F)] : const [paper, Color(0xFFF5EADB)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -180, right: -160, child: glow(peach.$2, 520)),
          Positioned(bottom: -200, left: -180, child: glow(sage.$2, 520)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// A rounded pastel tile with a clay icon chip, a big figure and a label:
/// the dashboard's at-a-glance numbers. [compact] puts the icon beside the
/// figure, for phones, where height is scarce.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.tone,
    required this.icon,
    required this.value,
    required this.label,
    this.compact = false,
  });
  final (Color, Color) tone;
  final IconData icon;
  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final figure = Text(
      value,
      style: text.headlineMedium?.copyWith(fontSize: compact ? 22 : 28, height: 1.1),
    );
    final caption = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.labelLarge?.copyWith(color: muted(context)),
    );
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: tileFill(context, tone),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        boxShadow: clayShadow(context),
      ),
      child: compact
          ? Row(
              children: [
                ClayIcon(icon, tone: tone, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [figure, caption]),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClayIcon(icon, tone: tone),
                const SizedBox(height: 14),
                figure,
                caption,
              ],
            ),
    );
  }
}

/// An icon on a glossy rounded square in [tone]'s deeper colour.
class ClayIcon extends StatelessWidget {
  const ClayIcon(this.icon, {super.key, required this.tone, this.size = 40});
  final IconData icon;
  final (Color, Color) tone;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.32),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(tone.$2, Colors.white, 0.25)!, tone.$2],
      ),
      boxShadow: [
        BoxShadow(color: tone.$2.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.55),
  );
}

/// The icon and tone an aisle is drawn with.
(IconData, (Color, Color)) aisleLook(Aisle a) => switch (a) {
  Aisle.fruitVeg => (Icons.eco_rounded, sage),
  Aisle.bakery => (Icons.bakery_dining_rounded, butter),
  Aisle.dairy => (Icons.water_drop_rounded, sky),
  Aisle.meat => (Icons.kebab_dining_rounded, peach),
  Aisle.fish => (Icons.set_meal_rounded, sky),
  Aisle.frozen => (Icons.ac_unit_rounded, sky),
  Aisle.cupboard => (Icons.rice_bowl_rounded, butter),
  Aisle.snacks => (Icons.cookie_rounded, peach),
  Aisle.drinks => (Icons.local_cafe_rounded, lilac),
  Aisle.household => (Icons.cleaning_services_rounded, lilac),
  Aisle.toiletries => (Icons.soap_rounded, lilac),
  Aisle.baby => (Icons.child_friendly_rounded, peach),
  Aisle.pets => (Icons.pets_rounded, butter),
  Aisle.other => (Icons.shopping_bag_rounded, sage),
};

/// A shop's tone, from its place in the catalogue so neighbours differ.
(Color, Color) shopTone(String shopId) =>
    tones[shops.indexWhere((s) => s.id == shopId).clamp(0, 99) % tones.length];

/// The coral filled button for a screen's main call to action.
ButtonStyle coralButton(BuildContext c) => FilledButton.styleFrom(
  backgroundColor: isDark(c) ? const Color(0xFFE88A66) : const Color(0xFFE5704B),
  foregroundColor: Colors.white,
  elevation: 2,
  shadowColor: const Color(0xFFE5704B).withValues(alpha: 0.5),
);

/// A round, raised button with a single icon (the reference's play button).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0xFF8A6A4A).withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.primary),
        ),
      ),
    ),
  );
}
