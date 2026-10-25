import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

/// The suite's own settings. Each app keeps its own under its Settings page.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageScaffold(
    title: 'Settings',
    children: [
      SyncCard(),
      AppLockCard(),
      HintsCard(),
      SecurityCard(
        network:
            'Brahma itself talks only to your sync server, if you sign in, and to GitHub to look for '
            'new versions (you can turn that off under Sentinel). Each app reaches the online services '
            'its own Settings page lists.',
      ),
      AboutCard(
        description:
            'Every Brahma app in one place: money, career, property, learning and social media. '
            'One sign-in and one sync account for all of them; each app keeps its own encrypted '
            'database.',
      ),
    ],
  );
}
