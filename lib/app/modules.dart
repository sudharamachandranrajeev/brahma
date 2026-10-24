import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../ui/cars_page.dart';
import 'settings_page.dart';

final carsModule = AppModule(
  id: 'cars',
  name: 'Cars',
  destinations: [
    Destination(
      id: 'search',
      label: 'Search',
      icon: Icons.search,
      selectedIcon: Icons.search,
      primary: true,
      page: (_) => const CarsPage(tab: CarsTab.search),
    ),
    Destination(
      id: 'garage',
      label: 'Garage',
      icon: Icons.directions_car_outlined,
      selectedIcon: Icons.directions_car,
      primary: true,
      page: (_) => const CarsPage(tab: CarsTab.garage),
    ),
    Destination(
      id: 'finance',
      label: 'Finance',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      primary: true,
      page: (_) => const CarsPage(tab: CarsTab.finance),
    ),
    Destination(
      id: 'guide',
      label: 'Guide',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
      primary: true,
      page: (_) => const CarsPage(tab: CarsTab.guide),
    ),
  ],
);

final modules = <AppModule>[carsModule];

/// Settings is app-wide, so it comes after every module's screens.
final settingsDestination = Destination(
  id: 'settings',
  label: 'Settings',
  icon: Icons.settings_outlined,
  selectedIcon: Icons.settings,
  page: (_) => const SettingsPage(),
);

List<Destination> get allDestinations => [for (final m in modules) ...m.destinations, settingsDestination];
