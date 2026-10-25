import 'dart:async';
import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../domain/cloudflare.dart';
import '../domain/device_ai.dart';
import '../domain/hub.dart';
import '../domain/models.dart';
import '../ui/hints.dart';
import 'session.dart';

/// The open session; main() overrides this before the first frame.
final sessionProvider = Provider<AppSession>((ref) => throw StateError('No session'));

/// HTTP for the hub; tests override it with a fake hub.
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

/// What main() and the tests override: the session, under both its Vani and
/// its shared type, and the app's identity and hints.
List<Override> vaniOverrides(AppSession session, {http.Client? client}) => [
  sessionProvider.overrideWithValue(session),
  coreSessionProvider.overrideWithValue(session),
  appIdentityProvider.overrideWithValue(vaniIdentity),
  hintTextsProvider.overrideWithValue({...coreHints, ...vaniHints}),
  if (client != null) httpClientProvider.overrideWithValue(client),
];

extension Mutate on WidgetRef {
  /// Runs a local write, refreshes the screens and queues a sync.
  Future<T> mutate<T>(Future<T> Function(AppSession s) write) async {
    final result = await write(read(sessionProvider));
    changed();
    return result;
  }

  /// Calls the hub; after a change ([refresh]) every hub screen reloads.
  Future<T> hub<T>(Future<T> Function(HubClient hub) call, {bool refresh = true}) async {
    final hub = await read(hubProvider.future);
    if (hub == null) throw NoHubException();
    final result = await call(hub);
    if (refresh) read(hubRevisionProvider.notifier).bump();
    return result;
  }
}

/// The hub's address and token (a synced pref).
final hubLinkProvider = FutureProvider<HubLink>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).prefs.hub();
});

/// The hub profile this device works in; device-only, so two people on two
/// phones can each be in their own.
class ProfileChoice extends AsyncNotifier<String> {
  static const _key = 'vani.profile';

  @override
  Future<String> build() async {
    final v = await ref.watch(sessionProvider).db.localSetting(_key);
    return v == null || v.isEmpty ? Profile.main : v;
  }

  Future<void> set(String id) async {
    state = AsyncData(id);
    await ref.read(sessionProvider).db.setLocalSetting(_key, id);
  }
}

final profileProvider = AsyncNotifierProvider<ProfileChoice, String>(ProfileChoice.new);

/// A client for the hub in the current profile, or null until one is
/// connected. Switching profiles makes a new client, so every hub screen reloads.
final hubProvider = FutureProvider<HubClient?>((ref) async {
  final link = await ref.watch(hubLinkProvider.future);
  if (!link.ready) return null;
  final profile = await ref.watch(profileProvider.future);
  final ai = await ref.watch(deviceAiProvider.future);
  return HubClient(
    link.url,
    link.token,
    profile: profile,
    deviceAi: ai?.answer,
    client: ref.watch(httpClientProvider),
  );
});

/// This computer's AI (the user's own CLI or Ollama), or null when the hub's
/// key does the AI work; device-only.
class DeviceAiNotifier extends AsyncNotifier<DeviceAi?> {
  @override
  Future<DeviceAi?> build() async {
    if (!deviceAiSupported) return null;
    final v = await ref.watch(sessionProvider).db.localSetting(DeviceAiChoice.localKey);
    final choice = v == null || v.isEmpty ? null : DeviceAiChoice.fromJson(obj(jsonDecode(v)));
    return choice == null ? null : ref.watch(deviceAiFactoryProvider)(choice);
  }

  Future<void> set(DeviceAiChoice? choice) async {
    await ref
        .read(sessionProvider)
        .db
        .setLocalSetting(DeviceAiChoice.localKey, choice == null ? '' : jsonEncode(choice.toJson()));
    state = AsyncData(choice == null ? null : ref.read(deviceAiFactoryProvider)(choice));
  }
}

final deviceAiProvider = AsyncNotifierProvider<DeviceAiNotifier, DeviceAi?>(DeviceAiNotifier.new);

/// Makes the [DeviceAi] for a choice; tests swap in a fake.
final deviceAiFactoryProvider = Provider<DeviceAi Function(DeviceAiChoice)>(
  (ref) => (choice) => DeviceAi(choice, client: ref.watch(httpClientProvider)),
);

/// The hub build this version of Vani ships (assets/hub).
final hubBundleProvider = FutureProvider<HubBundle>((ref) async {
  final manifest = obj(jsonDecode(await rootBundle.loadString('assets/hub/manifest.json')));
  return HubBundle(manifest: manifest, code: await rootBundle.loadString('assets/hub/worker.js'));
});

/// The hub this device deployed (its Cloudflare key and a copy of the hub's
/// secrets), or null; device-only.
class HubDeploymentNotifier extends AsyncNotifier<HubDeployment?> {
  @override
  Future<HubDeployment?> build() async {
    final v = await ref.watch(sessionProvider).db.localSetting(HubDeployment.localKey);
    return v == null || v.isEmpty ? null : HubDeployment.fromJson(obj(jsonDecode(v)));
  }

  Future<void> save(HubDeployment d) async {
    await ref.read(sessionProvider).db.setLocalSetting(HubDeployment.localKey, jsonEncode(d.toJson()));
    state = AsyncData(d);
  }
}

final hubDeploymentProvider = AsyncNotifierProvider<HubDeploymentNotifier, HubDeployment?>(
  HubDeploymentNotifier.new,
);

/// The connected hub's version: null for one from before versions.
final hubVersionProvider = FutureProvider<String?>((ref) async {
  final hub = await ref.watch(hubProvider.future);
  return hub?.version();
});

/// Bumped after every hub change and every minute, so hub screens reload.
class HubRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final hubRevisionProvider = NotifierProvider<HubRevision, int>(HubRevision.new);

/// Reloads the hub screens every minute while the app is open, so new
/// replies and published posts show up. Read once by the shell.
final hubTickerProvider = Provider<void>((ref) {
  final timer = Timer.periodic(
    const Duration(minutes: 1),
    (_) => ref.read(hubRevisionProvider.notifier).bump(),
  );
  ref.onDispose(timer.cancel);
});

/// A hub read that reloads with [hubRevisionProvider].
FutureProvider<T> _fromHub<T>(Future<T> Function(HubClient hub) read) => FutureProvider<T>((ref) async {
  ref.watch(hubRevisionProvider);
  final hub = await ref.watch(hubProvider.future);
  if (hub == null) throw NoHubException();
  return read(hub);
});

final profilesProvider = _fromHub((h) => h.profiles());
final overviewProvider = _fromHub((h) => h.overview());
final metaProvider = _fromHub((h) => h.meta());
final accountsProvider = _fromHub((h) => h.accounts());
final credentialsProvider = _fromHub((h) => h.credentials());
final mediaProvider = _fromHub((h) => h.media());
final draftsProvider = _fromHub((h) => h.posts(status: 'draft'));
final failedProvider = _fromHub((h) => h.posts(status: 'failed'));
final rulesProvider = _fromHub((h) => h.rules());
final discoveryProvider = _fromHub((h) => h.discovery());
final alertsProvider = _fromHub((h) => h.alerts());
final statsProvider = _fromHub((h) => h.stats());
final hubSettingsProvider = _fromHub((h) => h.settings());
final contentProvider = _fromHub((h) => h.content(limit: 30));

/// Posts scheduled between two ISO times.
final postsProvider = FutureProvider.family<List<Post>, (String, String)>((ref, range) async {
  ref.watch(hubRevisionProvider);
  final hub = await ref.watch(hubProvider.future);
  if (hub == null) throw NoHubException();
  return hub.posts(from: range.$1, to: range.$2);
});

/// What the inbox shows: status (open, new, read, done), platform and kind.
/// [triage]: a mood, or urgent (high priority).
typedef InboxFilter = ({String status, Platform? platform, String? kind, String? triage});

class InboxFilterNotifier extends Notifier<InboxFilter> {
  @override
  InboxFilter build() {
    // Each profile starts from the plain open inbox.
    ref.watch(profileProvider);
    return (status: 'open', platform: null, kind: null, triage: null);
  }

  void set(InboxFilter f) => state = f;
}

final inboxFilterProvider = NotifierProvider<InboxFilterNotifier, InboxFilter>(InboxFilterNotifier.new);

final inboxProvider = FutureProvider<InboxPage>((ref) async {
  ref.watch(hubRevisionProvider);
  final f = ref.watch(inboxFilterProvider);
  final hub = await ref.watch(hubProvider.future);
  if (hub == null) throw NoHubException();
  return hub.inbox(status: f.status, platform: f.platform, kind: f.kind, triage: f.triage, limit: 100);
});

/// The name the greeting uses (a synced pref).
final nameProvider = FutureProvider<String>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).prefs.name();
});

/// Dark (the default), light or system; device-only.
class ThemeChoice extends AsyncNotifier<ThemeMode> {
  static const _key = 'vani.theme';

  @override
  Future<ThemeMode> build() async {
    final v = await ref.watch(sessionProvider).db.localSetting(_key);
    return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.dark);
  }

  Future<void> set(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(sessionProvider).db.setLocalSetting(_key, mode.name);
  }
}

final themeProvider = AsyncNotifierProvider<ThemeChoice, ThemeMode>(ThemeChoice.new);

/// The app's top-level pages, in rail order.
enum VaniTab {
  home('Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  calendar('Calendar', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  inbox('Inbox', Icons.forum_outlined, Icons.forum_rounded),
  alerts('Alerts', Icons.notifications_none_rounded, Icons.notifications_rounded),
  analytics('Analytics', Icons.insights_outlined, Icons.insights_rounded),
  accounts('Accounts', Icons.people_outline_rounded, Icons.people_rounded),
  settings('Settings', Icons.settings_outlined, Icons.settings_rounded);

  const VaniTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon, selectedIcon;
}

class TabNotifier extends Notifier<VaniTab> {
  @override
  VaniTab build() => VaniTab.home;
  void go(VaniTab tab) => state = tab;
}

final tabProvider = NotifierProvider<TabNotifier, VaniTab>(TabNotifier.new);
