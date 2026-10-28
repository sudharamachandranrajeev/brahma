import 'package:anveshana/suite.dart';
import 'package:artha/suite.dart';
import 'package:bhojana/suite.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:udyoga/suite.dart';
import 'package:vahana/suite.dart';
import 'package:vani/suite.dart';
import 'package:vidya/suite.dart';

/// The apps the suite hosts, in home-screen order. A new app joins with its
/// subtree in ../apps, a path dependency in pubspec.yaml and a line here.
final suiteApps = <SuiteApp>[
  arthaSuite,
  udyogaSuite,
  anveshanaSuite,
  vahanaSuite,
  vidyaSuite,
  bhojanaSuite,
  vaniSuite,
];

/// A Brahma app that runs on its own rather than inside the suite (it is not
/// a Flutter app on brahma_core yet). Its home-screen card opens [page],
/// where it can be downloaded.
class LinkedApp {
  const LinkedApp({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.page,
  });

  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
  final Uri page;
}

const _owner = 'https://github.com/sudharamachandranrajeev';

/// The linked apps, in home-screen order after [suiteApps].
final linkedApps = <LinkedApp>[
  LinkedApp(
    name: 'Vastra',
    tagline: 'Fashion and personal care',
    icon: Icons.checkroom_outlined,
    color: const Color(0xFFB0507A),
    page: Uri.parse('$_owner/vastra/releases'),
  ),
  LinkedApp(
    name: 'Arogya',
    tagline: 'Health records',
    icon: Icons.medical_services_outlined,
    color: const Color(0xFF2E8B7A),
    page: Uri.parse('$_owner/arogya/releases'),
  ),
  LinkedApp(
    name: 'Bhandara',
    tagline: 'Storage and disk health',
    icon: Icons.storage_outlined,
    color: const Color(0xFF5B6BB0),
    page: Uri.parse('$_owner/bhandara/releases'),
  ),
  // No release yet, so the card opens the repository.
  LinkedApp(
    name: 'Ganana',
    tagline: 'AI tokens, costs and limits',
    icon: Icons.data_usage_outlined,
    color: const Color(0xFFB07A2E),
    page: Uri.parse('$_owner/ganana'),
  ),
];
