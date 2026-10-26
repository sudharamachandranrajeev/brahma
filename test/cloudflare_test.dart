import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vani/domain/cloudflare.dart';
import 'package:vani/domain/hub.dart';
import 'package:vani/domain/models.dart';

import 'fake_cloudflare.dart';

HubBundle bundle() {
  final dir = '${Directory.current.path}/assets/hub';
  return HubBundle(
    manifest: obj(jsonDecode(File('$dir/manifest.json').readAsStringSync())),
    code: 'export default {}',
  );
}

Future<Deployed> deploy(FakeCloudflare fake, {HubDeployment? previous}) => deployHub(
  cf: CloudflareClient('cf-key', client: fake.client),
  accountId: FakeCloudflare.account,
  subdomain: 'tester',
  bundle: bundle(),
  previous: previous,
  client: fake.client,
  wait: Duration.zero,
);

void main() {
  test('a first deploy makes everything, with fresh secrets', () async {
    final fake = FakeCloudflare();
    final steps = <DeployStep>[];
    final out = await deployHub(
      cf: CloudflareClient('cf-key', client: fake.client),
      accountId: FakeCloudflare.account,
      subdomain: 'tester',
      bundle: bundle(),
      client: fake.client,
      wait: Duration.zero,
      onStep: steps.add,
    );
    expect(steps, DeployStep.values);
    expect(fake.kv.keys, ['vani-hub-KV']);
    expect(fake.d1.keys, ['vani-hub']);
    expect(fake.buckets, {'vani-hub-media'});
    expect(fake.applied, bundle().migrations.map((m) => m.name));
    expect(fake.schedules, [
      {'cron': '* * * * *'},
    ]);
    expect(fake.workersDev, isTrue);

    final bindings = {for (final b in objs(fake.script!['bindings'])) str(b['name']): b};
    expect(
      bindings.keys,
      containsAll([
        'KV',
        'DB',
        'MEDIA',
        'SUBREQUEST_BUDGET',
        'API_TOKEN',
        'TOKEN_KEY',
        'NTFY_TOPIC',
        'PUBLIC_URL',
      ]),
    );
    expect(bindings['PUBLIC_URL']!['text'], 'https://vani-hub.tester.workers.dev');
    expect(base64.decode(str(bindings['TOKEN_KEY']!['text'])), hasLength(32));
    expect(fake.script!.containsKey('keep_bindings'), isFalse);

    expect(out.updated, isFalse);
    expect(out.link.url, 'https://vani-hub.tester.workers.dev');
    expect(out.link.token, hasLength(64));
    expect(out.deployment.tokenKey, bindings['TOKEN_KEY']!['text']);
    expect(out.deployment.ntfyTopic, startsWith('brahma-'));
  });

  test('an update keeps the secrets and applies only new migrations', () async {
    final fake = FakeCloudflare();
    final first = await deploy(fake);
    final made = fake.statements.length;
    fake.version = '0.3.0';
    final again = await deploy(fake, previous: first.deployment);
    expect(again.updated, isTrue);
    expect(fake.kv, hasLength(1));
    expect(fake.d1, hasLength(1));
    expect(fake.script!['keep_bindings'], ['secret_text']);
    expect(objs(fake.script!['bindings']).where((b) => b['type'] == 'secret_text'), isEmpty);
    // Only the bookkeeping table and the list of applied migrations again.
    expect(fake.statements.length - made, 2);
    expect(again.link.token, first.link.token);
    expect(again.deployment.tokenKey, first.deployment.tokenKey);
  });

  test('a hub from npm run setup is updated, and its token is asked for', () async {
    final fake = FakeCloudflare()..script = {};
    final out = await deploy(fake);
    expect(out.updated, isTrue);
    expect(out.link.ready, isFalse);
    expect(fake.script!['keep_bindings'], ['secret_text']);
  });

  test('R2 switched off is reported as such', () async {
    final fake = FakeCloudflare(r2Enabled: false);
    await expectLater(
      deploy(fake),
      throwsA(isA<CloudflareException>().having((e) => e.r2Disabled, 'r2Disabled', isTrue)),
    );
  });

  test('a wrong key is worded for the user', () async {
    final fake = FakeCloudflare();
    await expectLater(
      CloudflareClient('nope', client: fake.client).accounts(),
      throwsA(isA<CloudflareException>().having((e) => e.message, 'message', contains('refused the key'))),
    );
  });

  test('pairing links round-trip and reject anything else', () {
    const link = HubLink(url: 'https://vani-hub.tester.workers.dev', token: 'abc123');
    final back = HubLink.fromPairingLink(link.toPairingLink())!;
    expect((back.url, back.token), (link.url, link.token));
    expect(HubLink.fromPairingLink('vani://hub?u=http://evil.example&t=x'), isNull);
    expect(HubLink.fromPairingLink('vani://pair?s=x'), isNull);
  });
}
