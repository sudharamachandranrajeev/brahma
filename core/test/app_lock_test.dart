import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Device extends DeviceAuth {
  _Device(this.pass);
  bool pass;
  var asked = 0;
  @override
  Future<bool> available() async => true;
  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return pass;
  }
}

const _app = AppIdentity(id: 'brahma', name: 'Brahma', androidPackage: 'dev.brahma.app');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemorySecretStore store;
  late _Device device;

  setUp(() {
    store = MemorySecretStore();
    device = _Device(true);
  });

  /// A fresh start of the app over the same keychain.
  Future<ProviderContainer> start() async {
    final c = ProviderContainer(
      overrides: [
        appIdentityProvider.overrideWithValue(_app),
        keyVaultProvider.overrideWithValue(KeyVault(store, _app)),
        deviceAuthProvider.overrideWithValue(device),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    c.listen(appLockProvider, (_, _) {});
    await c.read(appLockProvider.future);
    return c;
  }

  AppLockState stateOf(ProviderContainer c) => c.read(appLockProvider).value!;

  Future<String> error(Future<void> f) async {
    try {
      await f;
    } on LockException catch (e) {
      return e.message;
    }
    fail('no error');
  }

  test('PINs are digits only, at least six, and check only against themselves', () async {
    final hash = await PinHash.make('123456');
    expect(hash, startsWith(r'argon2id$'));
    expect(await PinHash.check('123456', hash), isTrue);
    expect(await PinHash.check('123457', hash), isFalse);
    expect(await PinHash.check('123456', 'garbage'), isFalse);
    for (final bad in ['12345', '12345a', '']) {
      await expectLater(PinHash.make(bad), throwsA(isA<LockException>()), reason: bad);
    }
  });

  test('a lock that is on locks every start and opens with its PIN', () async {
    var c = await start();
    expect(stateOf(c).enabled, isFalse);
    expect(stateOf(c).locked, isFalse);
    await c.read(appLockProvider.notifier).enable('246810');
    expect(stateOf(c).enabled, isTrue);
    expect(stateOf(c).locked, isFalse);
    // The keychain keeps a hash, never the PIN.
    expect(store.values['brahma.lock'], isNot(contains('246810')));

    c = await start();
    expect(stateOf(c).locked, isTrue);
    expect(await error(c.read(appLockProvider.notifier).unlockWithPin('000000')), 'Wrong PIN');
    expect(stateOf(c).locked, isTrue);
    await c.read(appLockProvider.notifier).unlockWithPin('246810');
    expect(stateOf(c).locked, isFalse);
  });

  test('too many wrong PINs make the user wait, even across restarts', () async {
    var c = await start();
    await c.read(appLockProvider.notifier).enable('246810');
    c = await start();
    final lock = c.read(appLockProvider.notifier);
    for (var i = 1; i < AppLock.freeTries; i++) {
      expect(await error(lock.unlockWithPin('000000')), 'Wrong PIN');
    }
    expect(
      await error(lock.unlockWithPin('000000')),
      startsWith('Wrong PIN. Too many wrong PINs: try again in'),
    );
    expect(stateOf(c).waitUntil, isNotNull);

    c = await start();
    expect(await error(c.read(appLockProvider.notifier).unlockWithPin('246810')), startsWith('Too many'));

    // Once the wait is over, the right PIN opens and the count starts again.
    final saved = (await KeyVault(store, _app).appLock())!;
    await KeyVault(store, _app).setAppLock({...saved, 'waitUntil': '2000-01-01T00:00:00.000'});
    c = await start();
    await c.read(appLockProvider.notifier).unlockWithPin('246810');
    expect(stateOf(c).locked, isFalse);
    expect((await KeyVault(store, _app).appLock())!.containsKey('failures'), isFalse);
  });

  test('a minute away locks again, a moment away does not', () async {
    final c = await start();
    final lock = c.read(appLockProvider.notifier);
    await lock.enable('246810');
    final t = DateTime(2026, 10, 26, 9);
    lock.wentAway(t);
    lock.cameBack(t.add(const Duration(seconds: 20)));
    expect(stateOf(c).locked, isFalse);
    lock.wentAway(t);
    lock.cameBack(t.add(AppLock.lockAfter));
    expect(stateOf(c).locked, isTrue);
  });

  test('the device unlock opens only when allowed', () async {
    var c = await start();
    await c.read(appLockProvider.notifier).enable('246810');
    c = await start();
    await c.read(appLockProvider.notifier).unlockWithDevice();
    expect(device.asked, 0);
    expect(stateOf(c).locked, isTrue);

    await c.read(appLockProvider.notifier).setDevice(true);
    device.pass = false;
    await c.read(appLockProvider.notifier).unlockWithDevice();
    expect(stateOf(c).locked, isTrue);
    device.pass = true;
    await c.read(appLockProvider.notifier).unlockWithDevice();
    expect(stateOf(c).locked, isFalse);
  });

  test('a forgotten PIN is replaced after the sync password or device unlock', () async {
    const email = 'me@example.com', password = 'correct horse battery';
    final keys = await VaultCrypto.fromPassword(email, password);
    await KeyVault(store, _app).setSession({'email': email, 'secret': keys.authSecret});
    var c = await start();
    await c.read(appLockProvider.notifier).enable('246810');
    c = await start();
    final lock = c.read(appLockProvider.notifier);

    expect(await error(lock.replacePin('135790')), 'Prove it is you first');
    expect(await error(lock.proveWithPassword('wrong password here')), 'Wrong password');
    expect(await error(lock.proveWithPassword('short')), 'Wrong password');
    await lock.proveWithPassword(password);
    await lock.replacePin('135790');
    expect(stateOf(c).locked, isFalse);

    c = await start();
    expect(await error(c.read(appLockProvider.notifier).unlockWithPin('246810')), 'Wrong PIN');
    expect(await c.read(appLockProvider.notifier).proveWithDevice(), isTrue);
    await c.read(appLockProvider.notifier).replacePin('112233');
    c = await start();
    await c.read(appLockProvider.notifier).unlockWithPin('112233');
    expect(stateOf(c).locked, isFalse);
  });

  test('turning the lock off or changing the PIN needs the PIN', () async {
    final c = await start();
    final lock = c.read(appLockProvider.notifier);
    await lock.enable('246810');
    expect(await error(lock.changePin('000000', '135790')), 'Wrong PIN');
    await lock.changePin('246810', '135790');
    expect(await error(lock.disable('246810')), 'Wrong PIN');
    await lock.disable('135790');
    expect(stateOf(c).enabled, isFalse);
    expect(store.values.containsKey('brahma.lock'), isFalse);
  });

  test('Sentinel reports the lock while it is off', () async {
    final c = await start();
    expect((await c.read(lockCheck.findings.future)).single.id, 'lock.off');
    await c.read(appLockProvider.notifier).enable('246810');
    expect(await c.read(lockCheck.findings.future), isEmpty);
  });
}
