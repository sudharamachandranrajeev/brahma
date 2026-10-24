import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vani/domain/hub.dart';
import 'package:vani/domain/models.dart';

import 'fake_hub.dart';

void main() {
  test('sends the token and parses the overview', () async {
    final fake = FakeHub();
    final hub = HubClient('$hubUrl/', hubToken, client: fake.client);
    final o = await hub.overview();
    expect(o.accounts, hasLength(5));
    expect(o.inboxNew, 4);
    expect(o.ideas, hasLength(3));
    expect(o.stats.followers, greaterThan(0));
    expect(fake.log.single, 'GET /social/overview');
  });

  test('a refused token is a HubException worded for the user', () async {
    final hub = HubClient(hubUrl, 'wrong', client: FakeHub().client);
    await expectLater(hub.meta(), throwsA(isA<HubException>().having((e) => e.status, 'status', 401)));
  });

  test('errors carry the hub\'s problems', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': 'The post does not fit.',
          'problems': ['Bluesky: 412 of 300 characters.', 'YouTube needs a title.'],
        }),
        422,
      ),
    );
    final hub = HubClient(hubUrl, hubToken, client: client);
    try {
      await hub.createPost(const PostInput(text: 'x', targets: []));
      fail('expected a HubException');
    } on HubException catch (e) {
      expect(e.status, 422);
      expect(e.problems, hasLength(2));
      expect(
        e.message,
        'The post does not fit.\n• Bluesky: 412 of 300 characters.\n• YouTube needs a title.',
      );
    }
  });

  test('a 412 without a body still explains itself', () async {
    final hub = HubClient(hubUrl, hubToken, client: FakeHub().client);
    await expectLater(
      hub.connect(OAuthProvider.threads),
      throwsA(isA<HubException>().having((e) => e.status, 'status', 412)),
    );
    final empty = HubClient(hubUrl, hubToken, client: MockClient((_) async => http.Response('', 503)));
    await expectLater(
      empty.meta(),
      throwsA(isA<HubException>().having((e) => e.message, 'message', 'The hub answered 503.')),
    );
  });

  test('uploads in parts and completes with their etags', () async {
    final fake = FakeHub();
    final hub = HubClient(hubUrl, hubToken, client: fake.client);
    final progress = <double>[];
    final m = await hub.uploadBytes(
      'tile.png',
      'image/png',
      Uint8List.fromList(List.filled(10, 7)),
      onProgress: progress.add,
    );
    expect(m.status, 'ready');
    // The fake hub asks for 4-byte parts: 4 + 4 + 2.
    expect(fake.log.where((l) => l.contains('/parts/')), hasLength(3));
    final done = fake.bodies.entries.firstWhere((e) => e.key.endsWith('/complete')).value! as Map;
    expect((done['parts'] as List).map((p) => p['etag']), ['etag-1', 'etag-2', 'etag-3']);
    expect(progress.last, 1);
  });

  test('builds query strings and skips empty values', () async {
    final fake = FakeHub();
    final hub = HubClient(hubUrl, hubToken, client: fake.client);
    await hub.inbox(status: 'new', platform: Platform.instagram, limit: 100);
    await hub.posts(status: 'draft');
    await hub.alerts(unread: true);
    expect(fake.log, [
      'GET /social/inbox?status=new&platform=instagram&limit=100',
      'GET /social/posts?status=draft',
      'GET /social/alerts?unread=true',
    ]);
  });

  test('parses captions, discovery suggestions and runs', () async {
    final fake = FakeHub();
    final hub = HubClient(hubUrl, hubToken, client: fake.client);
    final c = await hub.caption('new mugs', [Platform.instagram, Platform.bluesky]);
    expect(c.variants.keys, [Platform.instagram, Platform.bluesky]);
    expect(c.hashtags, contains('ceramics'));

    final w = await hub.suggestDiscovery('an automatic car', postcode: 'EX1 1AA');
    expect(fake.bodies['POST /social/discovery/suggest'], {
      'description': 'an automatic car',
      'postcode': 'EX1 1AA',
    });
    expect(w.sources.single.type, 'ebay');
    expect(w.sources.single.data['postcode'], 'EX1 1AA');

    final run = await hub.runDiscovery('w1');
    expect(run.finds.single.price, 5450);
    expect(run.errors, ['DoneDeal: the site answered 503.']);
  });

  test('meta reports the Threads webhook and whether AI works', () async {
    final meta = await HubClient(hubUrl, hubToken, client: FakeHub(ai: false).client).meta();
    expect(meta.threadsWebhookUrl, '$hubUrl/social/webhook/threads');
    expect(meta.ai, isFalse);
    expect(meta.info(Platform.bluesky).maxText, 300);
  });

  test('checkUrl allows https and plain http only on local networks', () {
    expect(HubLink.checkUrl('https://watch.example.workers.dev'), isNull);
    expect(HubLink.checkUrl('http://192.168.1.20:8787'), isNull);
    expect(HubLink.checkUrl('http://hub.tail1234.ts.net'), isNull);
    expect(HubLink.checkUrl('http://example.com'), isNotNull);
    expect(HubLink.checkUrl('watch'), isNotNull);
  });
}
