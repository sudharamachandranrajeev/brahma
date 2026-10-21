import 'package:flutter/material.dart';

/// One screen reachable from the navigation.
class Destination {
  const Destination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.primary = false,
  });
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder page;

  /// Shown in the phone bottom bar; the rest sit under "More".
  final bool primary;

  /// Hint id for the navigation item.
  String get hint => 'nav.$id';
}

/// A part of an app (finance; renting, investing...). Each module brings its
/// own screens; the shell lists them in order.
class AppModule {
  const AppModule({required this.id, required this.name, required this.destinations});
  final String id;
  final String name;
  final List<Destination> destinations;
}
