import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Destination _screen(String id, String label) => Destination(
  id: id,
  label: label,
  icon: Icons.circle,
  selectedIcon: Icons.circle,
  page: (_) => const SizedBox(),
);

void main() {
  final screens = [_screen('hunt', 'Hunt'), _screen('searches', 'Searches'), _screen('settings', 'Settings')];
  const hints = {
    'page.hunt': 'Homes you are looking at, from first sight to keys.',
    'hunt.compare': 'Shortlisted homes side by side.',
    'searches.test': 'Send a test alert to your phone.',
    'settings.hints': 'Show these tips at the top of each page.',
    'sync.code': 'Pair another device with a code.',
  };

  test('finds the entry and the screen it belongs to', () {
    final hits = searchHelp('how do I compare shortlisted homes', hints, screens);
    expect(hits.first.id, 'hunt.compare');
    expect(hits.first.screen?.id, 'hunt');
  });

  test('stems words and matches screen names', () {
    expect(searchHelp('alerts', hints, screens).first.id, 'searches.test');
    expect(searchHelp('searches', hints, screens).map((h) => h.id), contains('searches.test'));
  });

  test('an entry for no screen still answers, without a place to go', () {
    final hit = searchHelp('pair device', hints, screens).single;
    expect(hit.id, 'sync.code');
    expect(hit.screen, isNull);
  });

  test('stop words alone and unknown words find nothing', () {
    expect(searchHelp('how do I', hints, screens), isEmpty);
    expect(searchHelp('zebra', hints, screens), isEmpty);
  });
}
