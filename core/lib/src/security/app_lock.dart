import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../app/providers.dart';
import 'crypto.dart';
import 'key_vault.dart';

/// The app lock: a screen over the app at start and after a minute away,
/// opened with a PIN or, where the platform has it, the device's own unlock
/// (fingerprint, face, device PIN, Windows Hello). It guards the screens,
/// not the data: the database key stays in the system keychain, so a
/// forgotten PIN loses nothing.

/// A failed unlock or PIN change, worded for the user.
class LockException implements Exception, UserFacingError {
  LockException(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

/// Shortest PIN accepted, in digits.
const minPinLength = 6;

/// Hashes and checks PINs: Argon2id with a random salt, the same profile as
/// the sync password (19 MiB, 2 passes), off the UI isolate.
class PinHash {
  static Future<List<int>> _derive(String pin, List<int> salt) => Isolate.run(() async {
    final k = await Argon2id(
      parallelism: 1,
      memory: 19456,
      iterations: 2,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    return k.extractBytes();
  });

  /// "argon2id$salt$hash", both base64.
  static Future<String> make(String pin) async {
    if (!RegExp('^[0-9]{$minPinLength,}\$').hasMatch(pin)) {
      throw LockException('Use a PIN of at least $minPinLength digits');
    }
    final salt = VaultCrypto.randomBytes(16);
    return 'argon2id\$${base64.encode(salt)}\$${base64.encode(await _derive(pin, salt))}';
  }

  static Future<bool> check(String pin, String stored) async {
    final parts = stored.split(r'$');
    if (parts.length != 3 || parts[0] != 'argon2id') return false;
    return _same(await _derive(pin, base64.decode(parts[1])), base64.decode(parts[2]));
  }
}

/// Compares in constant time.
bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// The device's own unlock, where local_auth has it (Android and Windows;
/// Linux has none).
class DeviceAuth {
  const DeviceAuth();

  Future<bool> available() async {
    if (!Platform.isAndroid && !Platform.isWindows) return false;
    try {
      return await LocalAuthentication().isDeviceSupported();
    } on Object {
      return false;
    }
  }

  /// True when the user passed; false when they cancelled.
  Future<bool> authenticate(String reason) async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => false,
        LocalAuthExceptionCode.noCredentialsSet => throw LockException(
          'This device has no screen lock set up. Set one in the system settings first.',
        ),
        _ => throw LockException(e.description ?? 'The device could not check it is you (${e.code.name}).'),
      };
    }
  }
}

final deviceAuthProvider = Provider<DeviceAuth>((ref) => const DeviceAuth());

/// Whether this device can unlock with its own lock.
final deviceAuthAvailableProvider = FutureProvider<bool>((ref) => ref.watch(deviceAuthProvider).available());

class AppLockState {
  const AppLockState({this.enabled = false, this.locked = false, this.device = false, this.waitUntil});
  final bool enabled;
  final bool locked;

  /// The device's own unlock may open the app too.
  final bool device;

  /// After too many wrong PINs, no PIN is tried before this.
  final DateTime? waitUntil;
}

class AppLock extends AsyncNotifier<AppLockState> {
  /// Time away (app hidden) after which the app locks again.
  static const lockAfter = Duration(minutes: 1);

  /// Wrong PINs allowed before each further one makes the user wait.
  static const freeTries = 5;

  DateTime? _awaySince;

  /// Set once the user proved who they are another way (sync password,
  /// device unlock), so a new PIN may replace the forgotten one.
  var _mayReplace = false;

  @override
  Future<AppLockState> build() async {
    final lifecycle = AppLifecycleListener(onHide: wentAway, onShow: cameBack);
    ref.onDispose(lifecycle.dispose);
    return _state(await _vault.appLock(), locked: true);
  }

  KeyVault get _vault => ref.read(keyVaultProvider);
  AppLockState get _now => state.value ?? const AppLockState();

  static AppLockState _state(Map<String, Object?>? saved, {required bool locked}) => saved == null
      ? const AppLockState()
      : AppLockState(
          enabled: true,
          locked: locked,
          device: saved['device'] == true,
          waitUntil: DateTime.tryParse('${saved['waitUntil']}'),
        );

  void wentAway([DateTime? at]) => _awaySince ??= at ?? DateTime.now();

  void cameBack([DateTime? at]) {
    final since = _awaySince;
    _awaySince = null;
    if (since != null && (at ?? DateTime.now()).difference(since) >= lockAfter) lock();
  }

  void lock() {
    final s = _now;
    if (s.enabled) {
      state = AsyncData(AppLockState(enabled: true, locked: true, device: s.device, waitUntil: s.waitUntil));
    }
  }

  Future<void> _unlocked(Map<String, Object?> saved) async {
    final clean = {...saved}
      ..remove('failures')
      ..remove('waitUntil');
    if (saved.containsKey('failures')) await _vault.setAppLock(clean);
    _mayReplace = false;
    state = AsyncData(_state(clean, locked: false));
  }

  Future<void> unlockWithPin(String pin) async {
    final saved = (await _vault.appLock())!;
    final wait = DateTime.tryParse('${saved['waitUntil']}');
    if (wait != null && wait.isAfter(DateTime.now())) throw LockException(_waitText(wait));
    if (await PinHash.check(pin, saved['pin']! as String)) return _unlocked(saved);
    final failures = (saved['failures'] as int? ?? 0) + 1;
    // Past the free tries: 30 s, doubling with each wrong PIN, at most an hour.
    final until = failures < freeTries
        ? null
        : DateTime.now().add(Duration(seconds: min(3600, 30 << min(failures - freeTries, 7))));
    final next = {...saved, 'failures': failures, 'waitUntil': ?until?.toIso8601String()};
    await _vault.setAppLock(next);
    state = AsyncData(_state(next, locked: true));
    throw LockException(until == null ? 'Wrong PIN' : 'Wrong PIN. ${_waitText(until)}');
  }

  static String _waitText(DateTime until) {
    final s = until.difference(DateTime.now()).inSeconds + 1;
    return 'Too many wrong PINs: try again in ${s < 90 ? '$s seconds' : '${(s / 60).ceil()} minutes'}.';
  }

  Future<bool> _device(String reason) => ref.read(deviceAuthProvider).authenticate(reason);

  /// Opens with the device's own unlock, when the user allowed it.
  Future<void> unlockWithDevice() async {
    if (!_now.device) return;
    if (await _device('Unlock ${ref.read(appIdentityProvider).name}')) {
      await _unlocked((await _vault.appLock())!);
    }
  }

  /// Forgot the PIN: the device's own unlock proves it is the owner. True
  /// when it did; then [replacePin] sets the new one.
  Future<bool> proveWithDevice() async =>
      _mayReplace = await _device('Set a new PIN for ${ref.read(appIdentityProvider).name}');

  /// Forgot the PIN: the sync account's password proves it is the owner,
  /// checked on this device against the signed-in account.
  Future<void> proveWithPassword(String password) async {
    final s = await _vault.session();
    if (s == null) throw LockException('This device is not signed in to sync');
    final PasswordKeys keys;
    try {
      keys = await VaultCrypto.fromPassword(s['email']! as String, password);
    } on CryptoException {
      throw LockException('Wrong password');
    }
    if (!_same(utf8.encode(keys.authSecret), utf8.encode(s['secret']! as String))) {
      throw LockException('Wrong password');
    }
    _mayReplace = true;
  }

  /// Sets a new PIN after [proveWithDevice] or [proveWithPassword], and opens.
  Future<void> replacePin(String pin) async {
    if (!_mayReplace) throw LockException('Prove it is you first');
    final saved = (await _vault.appLock())!;
    final next = {...saved, 'pin': await PinHash.make(pin)}
      ..remove('failures')
      ..remove('waitUntil');
    await _vault.setAppLock(next);
    _mayReplace = false;
    state = AsyncData(_state(next, locked: false));
  }

  /// Turns the lock on, with [device] allowing the device's own unlock.
  Future<void> enable(String pin, {bool device = false}) async {
    final saved = {'pin': await PinHash.make(pin), 'device': device};
    await _vault.setAppLock(saved);
    state = AsyncData(_state(saved, locked: false));
  }

  Future<void> _checkPin(String pin) async {
    if (!await PinHash.check(pin, (await _vault.appLock())!['pin']! as String)) {
      throw LockException('Wrong PIN');
    }
  }

  Future<void> disable(String pin) async {
    await _checkPin(pin);
    await _vault.setAppLock(null);
    state = const AsyncData(AppLockState());
  }

  Future<void> changePin(String oldPin, String newPin) async {
    await _checkPin(oldPin);
    final saved = (await _vault.appLock())!;
    await _vault.setAppLock({...saved, 'pin': await PinHash.make(newPin)});
  }

  Future<void> setDevice(bool on) async {
    final saved = (await _vault.appLock())!;
    final next = {...saved, 'device': on};
    await _vault.setAppLock(next);
    state = AsyncData(_state(next, locked: _now.locked));
  }
}

final appLockProvider = AsyncNotifierProvider<AppLock, AppLockState>(AppLock.new);
