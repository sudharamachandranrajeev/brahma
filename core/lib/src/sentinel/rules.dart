import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app/providers.dart';
import '../ui/widgets.dart' show Status;
import 'core_checks.dart' show releasesClientProvider;
import 'releases.dart' show CheckFailed, isNewerVersion;
import 'sentinel.dart';

/// Sentinel's rules file: advisories the Brahma maintainers publish between
/// releases ("Artha below 0.2.0 sends ... : update"), in sentinel/rules.json
/// of the brahma repository, signed with an Ed25519 key that never leaves
/// the maintainer's machine (scripts/sign-rules.ts). A device trusts only
/// what verifies against [rulesPublicKey], so neither GitHub nor the user's
/// sync server, which relays the file for synced devices, can change it.

/// The public half of the rules signing key.
const rulesPublicKey = 'ta/VHytnMj2bUMTwDHpP5i0NGy2PYXle1MOGE2krkdc=';

const rulesUrl = 'https://raw.githubusercontent.com/sudharamachandranrajeev/brahma/main/sentinel/rules.json';

/// How long a fetched rules file counts as fresh.
const rulesFresh = Duration(hours: 12);

/// One maintainer advisory.
class Advisory {
  const Advisory({
    required this.id,
    required this.status,
    required this.title,
    required this.why,
    this.apps = const [],
    this.below,
    this.steps,
  });

  final String id;

  /// App ids it concerns ([AppIdentity.id]); empty for every app.
  final List<String> apps;

  /// Only versions older than this; null for every version.
  final String? below;
  final Status status;
  final String title, why;
  final String? steps;

  static Advisory? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], title = j['title'], why = j['why'];
    if (id is! String || id.isEmpty || title is! String || why is! String) return null;
    return Advisory(
      id: id,
      apps: [for (final a in j['apps'] is List ? j['apps'] as List : const []) '$a'],
      below: j['below'] is String ? j['below'] as String : null,
      status: Status.values.firstWhere((s) => s.name == j['status'], orElse: () => Status.warning),
      title: title,
      why: why,
      steps: j['steps'] is String ? j['steps'] as String : null,
    );
  }

  bool concerns(String app, String version) =>
      (apps.isEmpty || apps.contains(app)) && (below == null || isNewerVersion(below!, version));
}

/// A rules file that verified.
class SentinelRules {
  const SentinelRules(this.issued, this.expires, this.advisories);
  final DateTime issued;
  final DateTime? expires;
  final List<Advisory> advisories;
}

/// Checks [sig] (base64 Ed25519 over the exact bytes of [text]) and reads
/// the file. Throws [CheckFailed] when it is not the maintainers' own, has
/// expired, or is older than [notBefore] (an old file replayed).
Future<SentinelRules> verifyRules(
  String text,
  String sig, {
  required DateTime now,
  DateTime? notBefore,
  String publicKey = rulesPublicKey,
}) async {
  final bool ok;
  try {
    ok = await Ed25519().verify(
      utf8.encode(text),
      signature: Signature(
        base64.decode(sig.trim()),
        publicKey: SimplePublicKey(base64.decode(publicKey), type: KeyPairType.ed25519),
      ),
    );
  } on FormatException {
    throw CheckFailed('The rules file\'s signature is not readable');
  }
  if (!ok) throw CheckFailed('The rules file is not signed by Brahma\'s maintainers');
  final j = jsonDecode(text);
  final issued = j is Map ? DateTime.tryParse('${j['issued']}') : null;
  if (j is! Map || issued == null || j['advisories'] is! List) {
    throw CheckFailed('The rules file is malformed');
  }
  final expires = DateTime.tryParse('${j['expires']}');
  if (expires != null && expires.isBefore(now)) throw CheckFailed('The rules file has expired');
  if (notBefore != null && issued.isBefore(notBefore)) {
    throw CheckFailed('The rules file is older than one seen');
  }
  return SentinelRules(issued, expires, [for (final a in j['advisories'] as List) ?Advisory.fromJson(a)]);
}

/// The signed file as fetched: its text and signature. From the sync server
/// when this device syncs to one that relays it, else from GitHub. Tests
/// override it.
final sentinelRulesFeedProvider = FutureProvider<({String text, String sig})>((ref) async {
  if (ref.read(syncProvider).server != null) {
    try {
      final j = await (await ref.read(coreSessionProvider).account.api()).rules();
      if (j != null && j['rules'] is String && j['sig'] is String) {
        return (text: j['rules']! as String, sig: j['sig']! as String);
      }
    } on Object {
      // The server is away or too old: GitHub's copy is just as good.
    }
  }
  final http = ref.read(releasesClientProvider);
  Future<String> get(String url) async {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw CheckFailed('GitHub answered ${r.statusCode}');
    return r.body;
  }

  final both = await Future.wait([get(rulesUrl), get('$rulesUrl.sig')]);
  return (text: both[0], sig: both[1]);
}, retry: (_, _) => null);

/// The verified rules: the kept copy while fresh, else a new one; offline,
/// the kept copy however old (until it expires). A new file must not be
/// older than the newest one this device has seen.
final sentinelRulesProvider = FutureProvider<SentinelRules>((ref) async {
  const key = 'sentinel.rules';
  final db = ref.watch(coreSessionProvider).db;
  final now = DateTime.now();
  final kept = jsonDecode(await db.localSetting(key) ?? 'null');
  SentinelRules? old;
  if (kept is Map && kept['text'] is String && kept['sig'] is String) {
    try {
      old = await verifyRules(kept['text'] as String, kept['sig'] as String, now: now);
    } on CheckFailed {
      old = null;
    }
    final at = DateTime.tryParse('${kept['at']}');
    if (old != null && at != null && now.difference(at) < rulesFresh) return old;
  }
  try {
    final f = await ref.read(sentinelRulesFeedProvider.future);
    final fresh = await verifyRules(f.text, f.sig, now: now, notBefore: old?.issued);
    await db.setLocalSetting(key, jsonEncode({'text': f.text, 'sig': f.sig, 'at': now.toIso8601String()}));
    return fresh;
  } on Object {
    if (old != null) return old;
    rethrow;
  }
}, retry: (_, _) => null);

/// Advisories from Brahma's maintainers for this app and version.
final advisoryCheck = SecurityCheck(
  id: 'rules',
  title: 'Advisories',
  findings: FutureProvider((ref) async {
    final rules = await ref.watch(sentinelRulesProvider.future);
    final app = ref.watch(appIdentityProvider).id;
    final version = (await PackageInfo.fromPlatform()).version;
    return [
      for (final a in rules.advisories)
        if (a.concerns(app, version))
          Finding(id: 'rule.${a.id}', status: a.status, title: a.title, why: a.why, steps: a.steps),
    ];
  }, retry: (_, _) => null),
);
