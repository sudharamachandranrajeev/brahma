import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../ui/achievements_page.dart';
import '../ui/home_page.dart';
import '../ui/learn_page.dart';
import '../ui/notes_page.dart';
import '../ui/portfolio_page.dart';
import '../ui/progress_page.dart';
import '../ui/review_page.dart';
import '../ui/skills_page.dart';
import 'settings_page.dart';

Destination _d(
  String id,
  String label,
  IconData icon,
  IconData selected,
  Widget page, {
  bool primary = false,
}) => Destination(
  id: id,
  label: label,
  icon: icon,
  selectedIcon: selected,
  primary: primary,
  page: (_) => page,
);

final learningModule = AppModule(
  id: 'learning',
  name: 'Learning',
  destinations: [
    _d('home', 'Home', Icons.spa_outlined, Icons.spa, const HomePage(), primary: true),
    _d('learn', 'Learn', Icons.menu_book_outlined, Icons.menu_book, const LearnPage(), primary: true),
    _d('progress', 'Progress', Icons.insights_outlined, Icons.insights, const ProgressPage(), primary: true),
    _d(
      'achievements',
      'Achievements',
      Icons.emoji_events_outlined,
      Icons.emoji_events,
      const AchievementsPage(),
      primary: true,
    ),
    _d('review', 'Review', Icons.style_outlined, Icons.style, const ReviewPage()),
    _d('skills', 'Skills', Icons.track_changes, Icons.track_changes, const SkillsPage()),
    _d('portfolio', 'Portfolio', Icons.folder_special_outlined, Icons.folder_special, const PortfolioPage()),
    _d('notes', 'Notes', Icons.edit_note, Icons.edit_note, const NotesPage()),
  ],
);

final modules = <AppModule>[learningModule];

/// Settings is app-wide, so it comes after every module's screens.
final settingsDestination = _d(
  'settings',
  'Settings',
  Icons.settings_outlined,
  Icons.settings,
  const SettingsPage(),
);

List<Destination> get allDestinations => [for (final m in modules) ...m.destinations, settingsDestination];
