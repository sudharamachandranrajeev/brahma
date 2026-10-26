import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_lock_ui.dart';
import '../app/providers.dart';
import '../security/app_lock.dart';
import '../ui/widgets.dart' show Status;
import 'device_checks.dart';
import 'releases.dart';
import 'sentinel.dart';

/// The checks every Brahma app runs. An app that puts its screens under an
/// [AppLockGate] adds [lockCheck] as well.
final coreChecks = [syncCheck, updateCheck, deviceCheck];

/// Days without a finished sync before Sentinel says so.
const staleSyncDays = 7;

/// Whether the sync server is reached without encryption on the way: plain
/// http to anything but this machine or a Tailscale address (WireGuard
/// encrypts those). The data is end-to-end encrypted either way; the sign-in
/// token is not.
bool sentInClear(Uri server) {
  if (server.scheme != 'http' || server.host == 'localhost') return false;
  // Tailscale's MagicDNS names.
  if (server.host.endsWith('.ts.net')) return false;
  final ip = InternetAddress.tryParse(server.host);
  if (ip == null) return true;
  if (ip.isLoopback) return false;
  final b = ip.rawAddress;
  final tailscale = ip.type == InternetAddressType.IPv4
      ? b[0] == 100 && b[1] >= 64 && b[1] < 128
      // fd7a:115c:a1e0::/48
      : b[0] == 0xfd && b[1] == 0x7a && b[2] == 0x11 && b[3] == 0x5c && b[4] == 0xa1 && b[5] == 0xe0;
  return !tailscale;
}

/// A service an app reaches with its own token (a Worker, a webhook),
/// reported when [url] is reached in clear. [where] says where the user
/// changes the address.
Finding? linkInClear({required String id, required String name, required String url, required String where}) {
  final u = Uri.tryParse(url);
  if (u == null || !sentInClear(u)) return null;
  return Finding(
    id: id,
    status: Status.warning,
    title: '$name is reached without https',
    why:
        'The token that lets this app into $name crosses the network in clear. Anyone on that network '
        'could copy it and use $name as you.',
    steps: 'Give $name an https address, or reach it over Tailscale, then change the address in $where.',
  );
}

/// Sync: the server reached in clear, or this device not synced for days.
final syncCheck = SecurityCheck(
  id: 'sync',
  title: 'Sync',
  findings: FutureProvider((ref) async {
    final s = ref.watch(syncProvider);
    final server = s.server == null ? null : Uri.tryParse(s.server!);
    if (server == null) return const [];
    final last = s.lastSync == null ? null : DateTime.tryParse(s.lastSync!);
    final days = last == null ? null : DateTime.now().toUtc().difference(last).inDays;
    final stale =
        s.phase != SyncPhase.running && (days == null ? s.phase == SyncPhase.failed : days >= staleSyncDays);
    return [
      if (sentInClear(server))
        Finding(
          id: 'sync.http',
          status: Status.warning,
          title: 'Sync reaches your server without https',
          why:
              'Your data stays end-to-end encrypted, but the sign-in token crosses the network in clear. '
              'Anyone on that network could use it to delete or replace your synced data.',
          steps:
              'Put the server behind https, or reach it over Tailscale, then sign in again with the new '
              'address.',
        ),
      if (stale)
        Finding(
          id: 'sync.stale',
          status: Status.warning,
          title: days == null ? 'This device has never finished a sync' : 'Not synced for $days days',
          why:
              'Changes made here are only on this device until sync runs, so losing it loses them.'
              '${s.error == null ? '' : ' Last error: ${s.error}'}',
          fix: QuickFix('Sync now', (_, ref) => ref.read(syncProvider.notifier).run()),
        ),
    ];
  }),
);

/// HTTP for the update check; tests override it.
final releasesClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Whether Sentinel may ask GitHub for new versions (on unless turned off).
class UpdateChecks extends AsyncNotifier<bool> {
  static const _key = 'sentinel.updates';

  @override
  Future<bool> build() async => await ref.watch(coreSessionProvider).db.localSetting(_key) != 'off';

  Future<void> set(bool on) async {
    state = AsyncData(on);
    await ref.read(coreSessionProvider).db.setLocalSetting(_key, on ? 'on' : 'off');
  }
}

final updateChecksProvider = AsyncNotifierProvider<UpdateChecks, bool>(UpdateChecks.new);

/// Updates: a newer release of the app on GitHub, looked for once a run.
final updateCheck = SecurityCheck(
  id: 'update',
  title: 'Updates',
  findings: FutureProvider((ref) async {
    final app = ref.watch(appIdentityProvider);
    final repo = app.releases;
    if (repo == null || !await ref.watch(updateChecksProvider.future)) return const [];
    final current = (await PackageInfo.fromPlatform()).version;
    final newest = await fetchNewestRelease(ref.watch(releasesClientProvider), repo);
    if (newest == null || !isNewerVersion(newest.version, current)) return const [];
    return [
      Finding(
        // Per version, so snoozing one release does not hide the next.
        id: 'update.${newest.version}',
        status: Status.warning,
        title: '${app.name} ${newest.version} is out',
        why: 'You have $current. New versions fix security problems as well as bugs.',
        fix: QuickFix('Download', (_, _) async {
          if (!await launchUrl(newest.page, mode: LaunchMode.externalApplication)) {
            throw CheckFailed('Could not open ${newest.page}');
          }
        }),
      ),
    ];
    // Offline is no reason to ask GitHub again and again; "Check again" does.
  }, retry: (_, _) => null),
);

/// App lock: off, so anyone holding the unlocked device can open the app.
final lockCheck = SecurityCheck(
  id: 'lock',
  title: 'App lock',
  findings: FutureProvider((ref) async {
    if ((await ref.watch(appLockProvider.future)).enabled) return const [];
    final app = ref.watch(appIdentityProvider);
    return [
      Finding(
        id: 'lock.off',
        status: Status.warning,
        title: 'App lock is off',
        why:
            'Anyone who picks up this device while it is unlocked can open ${app.name} and read '
            'everything in it.',
        fix: QuickFix('Turn on app lock', (context, ref) => showSetPin(context, ref)),
      ),
    ];
  }),
);
