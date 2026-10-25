import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../ui/compare_page.dart';
import '../ui/list_page.dart';
import '../ui/shops_page.dart';
import 'settings_page.dart';

Destination _d(String id, String label, IconData icon, IconData selected, Widget page) =>
    Destination(id: id, label: label, icon: icon, selectedIcon: selected, primary: true, page: (_) => page);

final shoppingModule = AppModule(
  id: 'shopping',
  name: 'Shopping',
  destinations: [
    _d('list', 'List', Icons.checklist_outlined, Icons.checklist, const ListPage()),
    _d('compare', 'Compare', Icons.compare_arrows_outlined, Icons.compare_arrows, const ComparePage()),
    _d('shops', 'Shops', Icons.storefront_outlined, Icons.storefront, const ShopsPage()),
  ],
);

final modules = <AppModule>[shoppingModule];

/// Settings is app-wide, so it comes after every module's screens.
final settingsDestination = _d(
  'settings',
  'Settings',
  Icons.settings_outlined,
  Icons.settings,
  const SettingsPage(),
);

List<Destination> get allDestinations => [for (final m in modules) ...m.destinations, settingsDestination];
