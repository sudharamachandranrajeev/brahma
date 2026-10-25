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
            'Bhojana loads shop websites only when you search, compare or open a shop, and talks to your '
            'sync server only if you sign in. Shop logins stay in the shop\'s own pages: Bhojana never sees '
            'or stores your passwords or card details, and never checks out for you.',
      ),
      AboutCard(
        description:
            'Grocery and shopping: lists, UK price comparison, live prices through your own shop logins and '
            'basket filling.',
      ),
    ],
  );
}
