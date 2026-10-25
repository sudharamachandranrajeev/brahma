import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../ui/applications_page.dart';
import '../ui/career_page.dart';
import '../ui/contacts_page.dart';
import '../ui/growth_page.dart';
import '../ui/interview_page.dart';
import '../ui/jobs_page.dart';
import '../ui/linkedin_page.dart';
import '../ui/profile_page.dart';
import '../ui/today_page.dart';
import 'settings_page.dart';

final careerModule = AppModule(
  id: 'career',
  name: 'Career',
  destinations: [
    Destination(
      id: 'today',
      label: 'Today',
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
      primary: true,
      page: (_) => const TodayPage(),
    ),
    Destination(
      id: 'jobs',
      label: 'Jobs',
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      primary: true,
      page: (_) => const JobsPage(),
    ),
    Destination(
      id: 'applications',
      label: 'Applications',
      icon: Icons.send_outlined,
      selectedIcon: Icons.send,
      primary: true,
      page: (_) => const ApplicationsPage(),
    ),
    Destination(
      id: 'interview',
      label: 'Interview',
      icon: Icons.record_voice_over_outlined,
      selectedIcon: Icons.record_voice_over,
      primary: true,
      page: (_) => const InterviewPage(),
    ),
    Destination(
      id: 'career',
      label: 'Career',
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree,
      primary: true,
      page: (_) => const CareerPage(),
    ),
    Destination(
      id: 'contacts',
      label: 'Contacts',
      icon: Icons.contacts_outlined,
      selectedIcon: Icons.contacts,
      page: (_) => const ContactsPage(),
    ),
    Destination(
      id: 'linkedin',
      label: 'LinkedIn',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      page: (_) => const LinkedInPage(),
    ),
    Destination(
      id: 'growth',
      label: 'Growth',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      page: (_) => const GrowthPage(),
    ),
    Destination(
      id: 'profile',
      label: 'Profile',
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge,
      page: (_) => const ProfilePage(),
    ),
  ],
);

final modules = <AppModule>[careerModule];

/// Settings is app-wide, so it comes after every module's screens.
final settingsDestination = Destination(
  id: 'settings',
  label: 'Settings',
  icon: Icons.settings_outlined,
  selectedIcon: Icons.settings,
  page: (_) => const SettingsPage(),
);

List<Destination> get allDestinations => [for (final m in modules) ...m.destinations, settingsDestination];
