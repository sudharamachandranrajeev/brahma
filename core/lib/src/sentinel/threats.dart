import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../ui/widgets.dart' show Status;
import 'core_checks.dart' show releasesClientProvider;
import 'device_checks.dart';
import 'releases.dart' show CheckFailed;
import 'sentinel.dart';

/// Sentinel's threat watch: flaws that criminals or states are using right
/// now, from CISA's catalogue of known exploited vulnerabilities (KEV), held
/// against this device's last update. It follows the app's setup: a device
/// that syncs asks the user's own sync server (which fetches the catalogue
/// for every device, server/src/threats.ts); one that keeps its data on the
/// device only fetches it from CISA itself. Either way at most twice a day.

const kevUrl = 'https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json';

/// Days of the catalogue kept, as on the server.
const threatDays = 180;

/// How long a fetched list counts as fresh.
const threatsFresh = Duration(hours: 12);

/// Days a flaw counts as news when the device's last update is unknown.
const threatNewsDays = 30;

/// One flaw in use in real attacks.
class Threat {
  const Threat({
    required this.cve,
    required this.vendor,
    required this.product,
    required this.name,
    required this.added,
    this.ransomware = false,
  });

  final String cve, vendor, product, name;

  /// YYYY-MM-DD, when CISA added it.
  final String added;

  /// Known to be used by ransomware gangs.
  final bool ransomware;

  static Threat? fromJson(Object? j) {
    if (j is! Map) return null;
    String s(String k) => j[k] is String ? j[k] as String : '';
    final t = Threat(
      cve: s('cve'),
      vendor: s('vendor'),
      product: s('product'),
      name: s('name'),
      added: s('added'),
      ransomware: j['ransomware'] == true,
    );
    return t.cve.isEmpty || DateTime.tryParse(t.added) == null ? null : t;
  }

  Map<String, Object?> toJson() => {
    'cve': cve,
    'vendor': vendor,
    'product': product,
    'name': name,
    'added': added,
    'ransomware': ransomware,
  };

  /// Whether it hits [os] (`Platform.operatingSystem`), or, for `browser`,
  /// Chrome, Edge and Firefox.
  bool hits(String os) {
    final v = vendor.trim(), p = product.trim();
    final linuxKernel = v == 'Linux' && p == 'Kernel';
    return switch (os) {
      // Android's monthly patch covers its kernel and the phone chips.
      'android' =>
        v == 'Android' ||
            (v == 'Google' && (p.contains('Android') || p.contains('Pixel'))) ||
            v == 'Qualcomm' ||
            (v == 'Arm' && p.contains('Mali')) ||
            linuxKernel,
      'windows' =>
        v == 'Microsoft' && (p.contains('Windows') || p.contains('Win32k') || p.contains('Kernel')),
      'linux' => linuxKernel,
      'browser' =>
        (v == 'Google' && p.contains('Chromium')) ||
            (v == 'Microsoft' && p.contains('Edge')) ||
            (v == 'Mozilla' && p.contains('Firefox')),
      _ => false,
    };
  }
}

/// The catalogue's entries added in the last [threatDays] days, newest
/// first. The sync server trims the same way.
List<Threat> trimKev(Object? kev, DateTime now) {
  final list = kev is Map ? kev['vulnerabilities'] : null;
  if (list is! List) throw const FormatException('Not the KEV catalogue');
  final since = now.toUtc().subtract(const Duration(days: threatDays)).toIso8601String().substring(0, 10);
  return [
    for (final v in list)
      if (v is Map && v['dateAdded'] is String && (v['dateAdded'] as String).compareTo(since) >= 0)
        ?Threat.fromJson({
          'cve': v['cveID'],
          'vendor': v['vendorProject'],
          'product': v['product'],
          'name': v['vulnerabilityName'],
          'added': v['dateAdded'],
          'ransomware': v['knownRansomwareCampaignUse'] == 'Known',
        }),
  ]..sort((a, b) => b.added.compareTo(a.added));
}

class ThreatList {
  const ThreatList(this.fetched, this.threats, {this.fromServer = false});
  final DateTime fetched;
  final List<Threat> threats;

  /// Came through the user's sync server rather than from CISA directly.
  final bool fromServer;

  static ThreatList? fromJson(Object? j, {bool fromServer = false}) {
    if (j is! Map) return null;
    final fetched = DateTime.tryParse('${j['fetched']}');
    final list = j['threats'];
    if (fetched == null || list is! List) return null;
    return ThreatList(fetched, [for (final t in list) ?Threat.fromJson(t)], fromServer: fromServer);
  }

  Map<String, Object?> toJson() => {
    'fetched': fetched.toUtc().toIso8601String(),
    'threats': [for (final t in threats) t.toJson()],
  };
}

/// Fetches the list: from the sync server when this device syncs to one
/// that keeps it, else from CISA. Tests override it.
final threatFeedProvider = FutureProvider<ThreatList>((ref) async {
  if (ref.read(syncProvider).server != null) {
    try {
      final j = await (await ref.read(coreSessionProvider).account.api()).threats();
      final list = ThreatList.fromJson(j, fromServer: true);
      if (list != null) return list;
    } on Object {
      // The server is away or too old: CISA's own copy will do.
    }
  }
  final res = await ref
      .read(releasesClientProvider)
      .get(Uri.parse(kevUrl))
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) throw CheckFailed('CISA answered ${res.statusCode}');
  final now = DateTime.now();
  final body = res.body;
  // About 2 MB of JSON: parsed off the UI isolate.
  return ThreatList(now, await Isolate.run(() => trimKev(jsonDecode(body), now)));
}, retry: (_, _) => null);

/// Whether Sentinel watches for attacks under way (on unless turned off).
class ThreatWatch extends AsyncNotifier<bool> {
  static const _key = 'sentinel.threats';

  @override
  Future<bool> build() async => await ref.watch(coreSessionProvider).db.localSetting(_key) != 'off';

  Future<void> set(bool on) async {
    state = AsyncData(on);
    await ref.read(coreSessionProvider).db.setLocalSetting(_key, on ? 'on' : 'off');
  }
}

final threatWatchProvider = AsyncNotifierProvider<ThreatWatch, bool>(ThreatWatch.new);

/// The threat list: the kept copy while fresh, else a new one. Offline, the
/// kept copy serves however old it is. Null while the watch is off.
final threatsProvider = FutureProvider<ThreatList?>((ref) async {
  if (!await ref.watch(threatWatchProvider.future)) return null;
  const key = 'sentinel.threats.list';
  final db = ref.watch(coreSessionProvider).db;
  final kept = ThreatList.fromJson(jsonDecode(await db.localSetting(key) ?? 'null'));
  if (kept != null && DateTime.now().difference(kept.fetched) < threatsFresh) return kept;
  try {
    final fresh = await ref.read(threatFeedProvider.future);
    await db.setLocalSetting(key, jsonEncode(fresh.toJson()));
    return fresh;
  } on Object {
    if (kept != null) return kept;
    rethrow;
  }
}, retry: (_, _) => null);

/// What the [threats] mean for a device running [os] whose newest security
/// update is from [patched] (YYYY-MM-DD; null when unknown).
List<Finding> threatFindings(
  List<Threat> threats, {
  required String os,
  String? patched,
  required DateTime now,
}) {
  final osName = switch (os) {
    'android' => 'Android',
    'windows' => 'Windows',
    'linux' => 'Linux',
    _ => null,
  };
  final news = now.subtract(const Duration(days: threatNewsDays)).toIso8601String().substring(0, 10);
  final since = patched == null || DateTime.tryParse(patched) == null ? null : patched.substring(0, 10);
  final mine = osName == null
      ? const <Threat>[]
      : [
          for (final t in threats)
            if (t.hits(os) && (since == null ? t.added.compareTo(news) >= 0 : t.added.compareTo(since) > 0))
              t,
        ];
  final browsers = [
    for (final t in threats)
      if (t.hits('browser') && t.added.compareTo(news) >= 0) t,
  ];
  return [
    if (mine.isNotEmpty)
      Finding(
        // Per newest flaw, so snoozing hides these until another one comes.
        id: 'threat.os.${mine.first.cve}',
        status: since == null ? Status.info : Status.serious,
        title: since == null
            ? '${_count(mine.length, '$osName flaw')} under attack this month'
            : '${_count(mine.length, '$osName flaw')} under attack since your last update',
        why: since == null
            ? '${_listed(mine)} This app cannot tell when this device last updated.'
            : '${_listed(mine)} This device\'s newest security update is from $since, before CISA '
                  'listed ${mine.length == 1 ? 'it' : 'them'}.',
        steps: switch (os) {
          'android' =>
            'Settings > System > Software update, and Settings > Security > Google Play system update. '
                'If no update comes, the maker has stopped updating this phone.',
          'windows' => 'Settings > Windows Update > Check for updates, then restart.',
          _ => 'Install the system updates (for example sudo pacman -Syu or sudo apt upgrade), then restart.',
        },
      ),
    if (browsers.isNotEmpty)
      Finding(
        id: 'threat.browser.${browsers.first.cve}',
        status: Status.info,
        title: '${_count(browsers.length, 'browser flaw')} under attack this month',
        why: _listed(browsers),
        steps: switch (os) {
          'android' => 'Update Chrome and Android System WebView in the Play Store.',
          _ => 'Restart Chrome, Edge or Firefox: each installs its update on restart.',
        },
      ),
  ];
}

String _count(int n, String what) =>
    n > 1 ? '$n ${what}s' : '${'AEIOU'.contains(what[0]) ? 'An' : 'A'} $what';

String _listed(List<Threat> ts) {
  final names = [
    for (final t in ts.take(3)) '${t.name.isEmpty ? '${t.vendor} ${t.product}' : t.name} (${t.cve})',
  ];
  final more = ts.length > 3 ? ', and ${ts.length - 3} more' : '';
  final one = ts.length == 1;
  return 'CISA lists ${one ? 'it' : 'these'} as used in real attacks: ${names.join('; ')}$more.'
      '${ts.any((t) => t.ransomware) ? ' Ransomware gangs use ${one ? 'it' : 'at least one of them'}.' : ''}';
}

/// Attacks under way that concern this device or its browsers.
final threatCheck = SecurityCheck(
  id: 'threats',
  title: 'Attacks under way',
  findings: FutureProvider((ref) async {
    final list = await ref.watch(threatsProvider.future);
    if (list == null) return const [];
    final facts = await ref.watch(deviceFactsProvider.future);
    return threatFindings(
      list.threats,
      os: Platform.operatingSystem,
      patched: facts.patched,
      now: DateTime.now(),
    );
  }, retry: (_, _) => null),
);
