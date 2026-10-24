import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageScaffold(
    title: 'Settings',
    children: [
      HintsCard(),
      SyncCard(),
      SecurityCard(
        network:
            'Vidya makes no network requests of its own. It talks to your sync server only if you sign in.',
      ),
      AboutCard(
        description:
            'Learning and knowledge management: programs, courses, skills, portfolio, notes and progress.',
      ),
    ],
  );
}
