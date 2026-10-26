import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';

Threat _t(String cve, String vendor, String product, String added, {bool ransomware = false}) => Threat(
  cve: cve,
  vendor: vendor,
  product: product,
  name: '$vendor $product flaw',
  added: added,
  ransomware: ransomware,
);

void main() {
  final now = DateTime(2026, 10, 26);

  test('the catalogue is trimmed to the last half year, newest first', () {
    final kev = {
      'vulnerabilities': [
        {
          'cveID': 'CVE-2026-2',
          'vendorProject': 'Microsoft',
          'product': 'Win32k',
          'vulnerabilityName': 'Win32k EoP',
          'dateAdded': '2026-10-20',
          'knownRansomwareCampaignUse': 'Known',
        },
        {'cveID': 'CVE-2025-1', 'vendorProject': 'Linux', 'product': 'Kernel', 'dateAdded': '2025-01-02'},
        {'cveID': 'CVE-2026-1', 'vendorProject': 'Linux', 'product': 'Kernel', 'dateAdded': '2026-09-01'},
        {'cveID': 'CVE-2026-3', 'vendorProject': 'Odd', 'product': 'Date', 'dateAdded': 'soon'},
        'junk',
      ],
    };
    final t = trimKev(kev, now);
    expect([for (final x in t) x.cve], ['CVE-2026-2', 'CVE-2026-1']);
    expect(t.first.ransomware, isTrue);
    expect(t.first.name, 'Win32k EoP');
    expect(() => trimKev({'nope': 1}, now), throwsFormatException);

    final list = ThreatList(now, t, fromServer: true);
    final back = ThreatList.fromJson(list.toJson())!;
    expect(back.fetched, now.toUtc());
    expect([for (final x in back.threats) x.toJson()], [for (final x in t) x.toJson()]);
  });

  test('flaws are matched to the platforms they hit', () {
    expect(_t('a', 'Android', 'Framework', '').hits('android'), isTrue);
    expect(_t('a', 'Qualcomm', 'Multiple Chipsets ', '').hits('android'), isTrue);
    expect(_t('a', 'Arm', 'Mali GPU Kernel Driver', '').hits('android'), isTrue);
    expect(_t('a', 'Linux', 'Kernel', '').hits('android'), isTrue);
    expect(_t('a', 'Linux', 'Kernel', '').hits('linux'), isTrue);
    expect(_t('a', 'Linux', 'Kernel', '').hits('windows'), isFalse);
    expect(_t('a', 'Microsoft', 'Win32k', '').hits('windows'), isTrue);
    expect(_t('a', 'Microsoft', 'SharePoint', '').hits('windows'), isFalse);
    expect(_t('a', 'Microsoft', 'Edge', '').hits('browser'), isTrue);
    expect(_t('a', 'Google', 'Chromium V8', '').hits('browser'), isTrue);
    expect(_t('a', 'Google', 'Chromium V8', '').hits('android'), isFalse);
  });

  group('findings', () {
    final threats = [
      _t('CVE-3', 'Google', 'Chromium V8', '2026-10-20'),
      _t('CVE-2', 'Android', 'Framework', '2026-10-15', ransomware: true),
      _t('CVE-1', 'Qualcomm', 'Multiple Chipsets', '2026-08-01'),
    ];

    test('flaws listed after the last update are serious', () {
      final f = threatFindings(threats, os: 'android', patched: '2026-07-05', now: now);
      expect([for (final x in f) x.id], ['threat.os.CVE-2', 'threat.browser.CVE-3']);
      expect(f.first.status, Status.serious);
      expect(f.first.title, '2 Android flaws under attack since your last update');
      expect(f.first.why, contains('Ransomware gangs'));
      expect(f.first.why, contains('from 2026-07-05'));
      expect(f.last.status, Status.info);
      expect(f.last.title, 'A browser flaw under attack this month');
    });

    test('an update newer than every flaw leaves only the browser news', () {
      final f = threatFindings(threats, os: 'android', patched: '2026-10-05', now: now);
      expect([for (final x in f) x.id], ['threat.os.CVE-2', 'threat.browser.CVE-3']);
      expect(f.first.title, startsWith('An Android flaw')); // CVE-2 came after the 5th.
      expect(threatFindings(threats, os: 'android', patched: '2026-10-16', now: now).map((x) => x.id), [
        'threat.browser.CVE-3',
      ]);
    });

    test('without an update date, only this month\'s flaws, as news', () {
      final f = threatFindings(threats, os: 'android', now: now);
      expect(f.first.status, Status.info);
      expect(f.first.title, 'An Android flaw under attack this month');
      expect(f.first.why, contains('cannot tell'));
    });

    test('other platforms see only what hits them', () {
      expect(threatFindings(threats, os: 'windows', patched: '2026-01-01', now: now).map((x) => x.id), [
        'threat.browser.CVE-3',
      ]);
      expect(threatFindings(threats, os: 'macos', now: now).map((x) => x.id), ['threat.browser.CVE-3']);
      expect(threatFindings(const [], os: 'linux', now: now), isEmpty);
    });
  });
}
