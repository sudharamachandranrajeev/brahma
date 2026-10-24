import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dates.dart';
import '../db/store.dart';
import '../identity.dart';
import '../security/crypto.dart';
import '../sync/sync_engine.dart';
import '../ui/hints.dart';
import 'session.dart';

/// The running app; the app's root overrides this.
final appIdentityProvider = Provider<AppIdentity>((ref) => throw StateError('No app identity'));

/// The open session; main() overrides this before the first frame. Apps keep
/// their own typed session provider next to it.
final coreSessionProvider = Provider<CoreSession>((ref) => throw StateError('No session'));

/// Every database sync keeps in step, all under the core session's account.
/// An app has one; the suite app adds each hosted app's database.
final syncStoresProvider = Provider<List<Store>>((ref) => [ref.watch(coreSessionProvider).store]);

/// Every hint text by id: the app's own plus [coreHints].
final hintTextsProvider = Provider<Map<String, String>>((ref) => coreHints);

/// Bumped after every write so screens reading the database load again.
class Revision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final revisionProvider = NotifierProvider<Revision, int>(Revision.new);

extension AfterWrite on WidgetRef {
  /// Refreshes the screens and queues a sync. Apps call this after each write
  /// (their `mutate` helper wraps it).
  void changed() {
    read(revisionProvider.notifier).bump();
    read(syncProvider.notifier).soon();
  }
}

/// An error whose message is written for the user.
abstract interface class UserFacingError {
  String get message;
}

/// A message fit to show the user.
String describeError(Object e) => switch (e) {
  UserFacingError(:final message) ||
  SyncException(:final message) ||
  CryptoException(:final message) => message,
  _ => 'Something went wrong: $e',
};

final todayProvider = Provider<String>((ref) {
  ref.watch(revisionProvider);
  return today();
});

/// Device-only UI preferences.
class HintsState {
  const HintsState({this.enabled = true, this.dismissed = const {}});
  final bool enabled;
  final Set<String> dismissed;
  bool shows(String id) => enabled && !dismissed.contains(id);
}

class Hints extends AsyncNotifier<HintsState> {
  static const _on = 'ui.hints', _dismissed = 'ui.hints.dismissed';

  @override
  Future<HintsState> build() async {
    final db = ref.watch(coreSessionProvider).db;
    final dismissed = await db.localSetting(_dismissed);
    return HintsState(
      enabled: await db.localSetting(_on) != 'off',
      dismissed: dismissed == null ? {} : {...(jsonDecode(dismissed) as List).cast<String>()},
    );
  }

  Future<void> _save(HintsState s) async {
    state = AsyncData(s);
    final db = ref.read(coreSessionProvider).db;
    await db.setLocalSetting(_on, s.enabled ? 'on' : 'off');
    await db.setLocalSetting(_dismissed, jsonEncode(s.dismissed.toList()));
  }

  HintsState get _now => state.value ?? const HintsState();

  Future<void> setEnabled(bool on) => _save(HintsState(enabled: on, dismissed: _now.dismissed));
  Future<void> dismiss(String id) =>
      _save(HintsState(enabled: _now.enabled, dismissed: {..._now.dismissed, id}));

  /// Turns hints back on and shows every dismissed one again.
  Future<void> restore() => _save(const HintsState());
}

final hintsProvider = AsyncNotifierProvider<Hints, HintsState>(Hints.new);

enum SyncPhase { signedOut, idle, running, failed }

class SyncState {
  const SyncState(this.phase, {this.lastSync, this.error, this.email, this.server});
  final SyncPhase phase;
  final String? lastSync;
  final String? error;
  final String? email;
  final String? server;
}

/// Runs sync on start, a few seconds after each change and every 15 minutes.
class SyncController extends Notifier<SyncState> {
  Timer? _debounce, _periodic;
  bool _again = false;
  DateTime _lastRun = DateTime.now();

  @override
  SyncState build() {
    // Back in the app: fetch what other devices did, at most once a minute
    // (desktops resume on every focus). Leaving it: send what is queued now,
    // since a phone may not run again for hours.
    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (DateTime.now().difference(_lastRun) > const Duration(minutes: 1)) run();
      },
      onHide: () {
        if (_debounce?.isActive ?? false) {
          _debounce!.cancel();
          run();
        }
      },
    );
    ref.onDispose(() {
      lifecycle.dispose();
      _debounce?.cancel();
      _periodic?.cancel();
    });
    _periodic = Timer.periodic(const Duration(minutes: 15), (_) => run());
    Future.microtask(run);
    return const SyncState(SyncPhase.idle);
  }

  void soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), run);
  }

  Future<void> run() async {
    if (state.phase == SyncPhase.running) {
      _again = true;
      return;
    }
    _lastRun = DateTime.now();
    final s = ref.read(coreSessionProvider);
    final session = await s.keys.session();
    if (session == null) {
      state = const SyncState(SyncPhase.signedOut);
      return;
    }
    final email = session['email'] as String?, server = session['server'] as String?;
    final last = await s.db.localSetting('sync.last');
    state = SyncState(SyncPhase.running, lastSync: last, email: email, server: server);
    try {
      var pulled = 0;
      for (final store in ref.read(syncStoresProvider)) {
        final engine = await s.account.engine(store);
        if (engine == null) {
          state = const SyncState(SyncPhase.signedOut);
          return;
        }
        pulled += (await engine.run()).pulled;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await s.db.setLocalSetting('sync.last', now);
      state = SyncState(SyncPhase.idle, lastSync: now, email: email, server: server);
      if (pulled > 0) ref.read(revisionProvider.notifier).bump();
    } catch (e) {
      state = SyncState(
        SyncPhase.failed,
        lastSync: last,
        error: describeError(e),
        email: email,
        server: server,
      );
    }
    if (_again) {
      _again = false;
      await run();
    }
  }

  Future<void> signOut() async {
    await ref.read(coreSessionProvider).account.signOut();
    state = const SyncState(SyncPhase.signedOut);
  }
}

final syncProvider = NotifierProvider<SyncController, SyncState>(SyncController.new);
