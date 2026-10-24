import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const PageScaffold(
    title: 'Settings',
    children: [
      HintsCard(),
      SyncCard(),
      SecurityCard(
        network:
            'Nothing leaves the device unless you sign in to sync, open a search link in your browser or '
            'paste an advert link for the app to read.',
      ),
      AboutCard(
        description: 'Buying, owning and selling cars: search, finance, running costs and the paperwork.',
      ),
    ],
  );
}
