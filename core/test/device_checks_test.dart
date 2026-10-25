import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _lsblk(String rootType, {bool lvm = false}) => jsonEncode({
  'blockdevices': [
    {
      'name': 'nvme0n1',
      'type': 'disk',
      'mountpoints': [null],
      'children': [
        {
          'name': 'nvme0n1p1',
          'type': 'part',
          'mountpoints': ['/boot'],
        },
        {
          'name': 'nvme0n1p2',
          'type': 'part',
          'mountpoints': [null],
          'children': [
            {
              'name': 'root',
              'type': rootType,
              'mountpoints': lvm ? [null] : ['/'],
              if (lvm)
                'children': [
                  {
                    'name': 'vg-root',
                    'type': 'lvm',
                    'mountpoints': ['/'],
                  },
                ],
            },
          ],
        },
      ],
    },
  ],
});

Future<List<Finding>> _findings(DeviceFacts facts) {
  final c = ProviderContainer(overrides: [deviceFactsProvider.overrideWith((_) async => facts)]);
  addTearDown(c.dispose);
  return c.read(deviceCheck.findings.future);
}

void main() {
  test('root is encrypted only when it sits on a crypt device', () {
    expect(rootEncrypted(_lsblk('crypt')), isTrue);
    expect(rootEncrypted(_lsblk('crypt', lvm: true)), isTrue);
    expect(rootEncrypted(_lsblk('part')), isFalse);
    expect(rootEncrypted('{"blockdevices": []}'), isNull);
    expect(rootEncrypted('not json'), isNull);
  });

  test('a firewall counts when any unit is active', () {
    expect(firewallActive('inactive\nactive\ninactive\n'), isTrue);
    expect(firewallActive('inactive\ninactive\nfailed\n'), isFalse);
    expect(firewallActive(''), isFalse);
  });

  test('what the device does not say is not reported', () async {
    expect(await _findings(const DeviceFacts()), isEmpty);
    final fine = DateTime.now().subtract(const Duration(days: 10)).toIso8601String().substring(0, 10);
    expect(
      await _findings(
        DeviceFacts(diskEncrypted: true, firewall: true, screenLock: true, antivirus: true, patched: fine),
      ),
      isEmpty,
    );
  });

  test('every weakness is reported with its severity', () async {
    final old = DateTime.now().subtract(const Duration(days: 200)).toIso8601String().substring(0, 10);
    final found = await _findings(
      DeviceFacts(diskEncrypted: false, firewall: false, screenLock: false, antivirus: false, patched: old),
    );
    expect(found.map((f) => f.id), [
      'device.disk',
      'device.screenlock',
      'device.patch',
      'device.antivirus',
      'device.firewall',
    ]);
    expect(found.firstWhere((f) => f.id == 'device.patch').title, 'Security updates are 200 days old');
    expect(found.firstWhere((f) => f.id == 'device.screenlock').status, Status.serious);
    expect(found.last.status, Status.info);
  });
}
