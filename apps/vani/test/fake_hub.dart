import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The fake hub's address and token.
const hubUrl = 'https://hub.example.test';
const hubToken = 'test-token';

typedef Json = Map<String, Object?>;

/// An in-memory social hub behind a [MockClient], answering the routes of
/// watch/SOCIAL.md. Seeded with made-up data dated relative to now; tests
/// never use real people's data and nothing leaves the machine.
class FakeHub {
  FakeHub({bool seeded = true, this.ai = true}) {
    if (seeded) _seed();
  }

  /// Whether the hub "has" an Anthropic key.
  bool ai;

  final accounts = <Json>[];
  final posts = <Json>[];
  final inbox = <Json>[];
  final content = <Json>[];
  final alerts = <Json>[];
  final media = <Json>[];
  var rules = <Json>[];
  var watches = <Json>[];
  final credentials = <String, Json>{};
  Json settings = {
    'timezone': 'Europe/London',
    'queue': [
      {'day': 0, 'time': '09:00'},
      {'day': 2, 'time': '18:30'},
      {'day': 4, 'time': '12:15'},
    ],
    'savedReplies': [
      {'id': 'r1', 'title': 'Opening hours', 'text': 'Hi {name}! We are open 9 to 5, Monday to Saturday.'},
    ],
    'model': 'claude-opus-5-5',
  };

  /// Every request seen, as "METHOD /path?query".
  final log = <String>[];

  /// Bodies of the requests seen, keyed like [log].
  final bodies = <String, Object?>{};

  late final http.Client client = MockClient(_handle);

  var _n = 100;
  String _id(String prefix) => '$prefix${_n++}';

  static String iso(DateTime t) => t.toUtc().toIso8601String();
  final now = DateTime.now();
  String ago(Duration d) => iso(now.subtract(d));
  String ahead(Duration d) => iso(now.add(d));

  Future<http.Response> _handle(http.Request req) async {
    final path = req.url.path;
    final key = '${req.method} $path${req.url.hasQuery ? '?${req.url.query}' : ''}';
    log.add(key);
    if (req.headers['authorization'] != 'Bearer $hubToken') return _json({'error': 'Unauthorized'}, 401);
    Object? body;
    if (req.headers['content-type'] == 'application/json' && req.body.isNotEmpty) {
      body = jsonDecode(req.body);
      bodies[key] = body;
    }
    final q = req.url.queryParameters;
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    final m = req.method;
    Json b() => body is Map ? body.cast<String, Object?>() : {};

    switch ((m, seg)) {
      case ('GET', ['social', 'overview']):
        return _json(_overview());
      case ('GET', ['social', 'meta']):
        return _json(_meta());
      case ('GET', ['social', 'credentials']):
        return _json([
          for (final p in ['meta', 'threads', 'google', 'linkedin', 'ebay', 'anthropic'])
            credentials[p] ?? {'provider': p, 'set': false, 'publicId': null, 'updatedAt': null},
        ]);
      case ('PUT', ['social', 'credentials', final p]):
        credentials[p] = {'provider': p, 'set': true, 'publicId': b()['publicId'], 'updatedAt': iso(now)};
        if (p == 'anthropic') ai = true;
        return _json({'ok': true});
      case ('DELETE', ['social', 'credentials', final p]):
        credentials.remove(p);
        return _json({'ok': true});
      case ('GET', ['social', 'accounts']):
        return _json(accounts);
      case ('POST', ['social', 'connect', final p]):
        if (credentials[p]?['set'] != true) {
          return _json({'error': 'Add the $p app credentials first.'}, 412);
        }
        return _json({'url': 'https://example.test/oauth/$p'});
      case ('POST', ['social', 'accounts', 'bluesky']):
        final handle = '${b()['handle']}';
        final a = _account(_id('a'), 'bluesky', handle.split('.').first, handle);
        accounts.add(a);
        return _json(a);
      case ('POST', ['social', 'accounts', 'mastodon']):
        final a = _account(_id('a'), 'mastodon', 'Mastodon', '@studio@${b()['instance']}');
        accounts.add(a);
        return _json(a);
      case ('POST', ['social', 'accounts', final id, 'check']):
        final a = accounts.firstWhere((a) => a['id'] == id);
        a['status'] = 'ok';
        a['statusMessage'] = null;
        a['checkedAt'] = iso(now);
        return _json(a);
      case ('DELETE', ['social', 'accounts', final id]):
        accounts.removeWhere((a) => a['id'] == id);
        return _json({'ok': true});
      case ('GET', ['social', 'media']):
        return _json(media);
      case ('POST', ['social', 'media']):
        final item = {
          'id': _id('m'),
          'filename': b()['filename'],
          'contentType': b()['contentType'],
          'size': b()['size'],
          'status': 'uploading',
          'createdAt': iso(now),
          'url': '',
        };
        media.add(item);
        return _json({'media': item, 'partSize': 4});
      case ('PUT', ['social', 'media', _, 'parts', final n]):
        return _json({'etag': 'etag-$n'});
      case ('POST', ['social', 'media', final id, 'complete']):
        final item = media.firstWhere((x) => x['id'] == id)..['status'] = 'ready';
        return _json(item);
      case ('DELETE', ['social', 'media', final id]):
        media.removeWhere((x) => x['id'] == id);
        return _json({'ok': true});
      case ('GET', ['social', 'posts']):
        return _json([
          for (final p in posts)
            if ((q['status'] == null || p['status'] == q['status']) && _inRange(p, q['from'], q['to'])) p,
        ]);
      case ('POST', ['social', 'posts']):
        final p = _post(_id('p'), b());
        posts.add(p);
        return _json(p);
      case ('PUT', ['social', 'posts', final id]):
        final i = posts.indexWhere((p) => p['id'] == id);
        if (i < 0) return _json({'error': 'No such post.'}, 404);
        posts[i] = _post(id, b(), createdAt: '${posts[i]['createdAt']}');
        return _json(posts[i]);
      case ('DELETE', ['social', 'posts', final id]):
        posts.removeWhere((p) => p['id'] == id);
        return _json({'ok': true});
      case ('POST', ['social', 'posts', final id, 'publish' || 'retry']):
        final p = posts.firstWhere((p) => p['id'] == id);
        _publish(p);
        return _json(p);
      case ('GET', ['social', 'inbox']):
        final items = [
          for (final i in inbox)
            if (_statusMatch(i, q['status'] ?? 'open') &&
                (q['platform'] == null || i['platform'] == q['platform']) &&
                (q['kind'] == null || i['kind'] == q['kind']))
              i,
        ];
        return _json({
          'items': items,
          'counts': {
            for (final s in ['new', 'read', 'done']) s: inbox.where((i) => i['status'] == s).length,
          },
        });
      case ('POST', ['social', 'inbox', 'bulk']):
        final ids = (b()['ids'] as List).cast<String>();
        for (final i in inbox) {
          if (ids.contains(i['id'])) i['status'] = b()['status'];
        }
        return _json({'ok': true});
      case ('POST', ['social', 'inbox', 'refresh']):
        return _json({'items': 0});
      case ('PATCH', ['social', 'inbox', final id]):
        final i = inbox.firstWhere((i) => i['id'] == id)..['status'] = b()['status'];
        return _json(i);
      case ('POST', ['social', 'inbox', final id, 'reply']):
        final i = inbox.firstWhere((i) => i['id'] == id)
          ..['status'] = 'done'
          ..['myReply'] = {'text': b()['text'], 'at': iso(now), 'private': b()['private'] == true};
        return _json(i);
      case ('POST', ['social', 'inbox', _, 'suggest']):
        if (!ai) return _json({'error': 'Add your Anthropic API key first.'}, 412);
        return _json({
          'suggestions': ['Thank you so much!', 'Glad you like it. More on Friday.'],
        });
      case ('GET', ['social', 'content']):
        return _json(content);
      case ('GET', ['social', 'rules']):
        return _json(rules);
      case ('PUT', ['social', 'rules']):
        rules = [for (final r in body! as List) (r as Map).cast<String, Object?>()];
        return _json(rules);
      case ('GET', ['social', 'discovery']):
        return _json(watches);
      case ('PUT', ['social', 'discovery']):
        watches = [for (final w in body! as List) (w as Map).cast<String, Object?>()];
        return _json(watches);
      case ('POST', ['social', 'discovery', 'suggest']):
        if (!ai) return _json({'error': 'Add your Anthropic API key first.'}, 412);
        return _json({
          'id': '',
          'name': 'Small automatic hatchbacks',
          'description': b()['description'],
          'sources': [
            {'type': 'ebay', 'query': 'automatic hatchback', 'postcode': b()['postcode'], 'maxPrice': 6000},
          ],
          'keywords': ['automatic'],
          'ai': true,
          'everyMinutes': 60,
          'paused': false,
        });
      case ('POST', ['social', 'discovery', _, 'run']):
        return _json({
          'finds': [
            {
              'id': 'f1',
              'source': 'ebay',
              'title': '2016 hatchback, automatic, 48k miles',
              'text': 'One owner, full service history.',
              'url': 'https://example.test/item/1',
              'image': null,
              'price': 5450,
              'currency': 'GBP',
              'location': 'Exampletown',
              'at': ago(const Duration(hours: 2)),
            },
          ],
          'alerts': <Json>[],
          'errors': ['DoneDeal: the site answered 503.'],
        });
      case ('GET', ['social', 'alerts']):
        return _json(alerts);
      case ('POST', ['social', 'alerts', 'read']):
        final ids = b()['ids'] as List?;
        for (final a in alerts) {
          if (ids == null || ids.contains(a['id'])) a['read'] = true;
        }
        return _json({'ok': true});
      case ('GET', ['social', 'stats']):
        return _json(_stats());
      case ('GET', ['social', 'settings']):
        return _json(settings);
      case ('PUT', ['social', 'settings']):
        settings = b();
        return _json(settings);
      case ('POST', ['social', 'ai', 'caption']):
        if (!ai) return _json({'error': 'Add your Anthropic API key first.'}, 412);
        return _json({
          'variants': {for (final p in b()['platforms'] as List) '$p': 'New glaze, new mugs. Out Friday.'},
          'hashtags': ['ceramics', 'handmade'],
        });
      case ('GET', ['social', 'ai', 'ideas']):
        return _json({'ideas': _ideas, 'generatedAt': iso(now)});
      case ('POST', ['test-notify']):
        return _json({'ok': true});
    }
    return _json({'error': 'Not found'}, 404);
  }

  http.Response _json(Object? v, [int status = 200]) =>
      http.Response(jsonEncode(v), status, headers: {'content-type': 'application/json'});

  bool _statusMatch(Json i, String status) =>
      status == 'open' ? i['status'] != 'done' : (status == 'all' || i['status'] == status);

  bool _inRange(Json p, String? from, String? to) {
    final at = p['scheduledAt'] as String?;
    if (from == null && to == null) return true;
    if (at == null) return false;
    return (from == null || at.compareTo(from) >= 0) && (to == null || at.compareTo(to) < 0);
  }

  Json _post(String id, Json input, {String? createdAt}) {
    final draft = input['draft'] == true;
    final queue = input['queue'] == true;
    var at = input['scheduledAt'] as String?;
    if (queue) at = ahead(const Duration(days: 1, hours: 2));
    final status = draft ? 'draft' : (at == null ? 'publishing' : 'scheduled');
    final p = {
      'id': id,
      'text': input['text'] ?? '',
      'media': input['media'] ?? [],
      'targets': [
        for (final t in (input['targets'] as List? ?? []).cast<Map>())
          {...t.cast<String, Object?>(), 'status': status, 'attempts': 0},
      ],
      'scheduledAt': at,
      'status': status,
      'recycleDays': input['recycleDays'],
      'tags': input['tags'] ?? [],
      'createdAt': createdAt ?? iso(now),
      'updatedAt': iso(now),
    };
    if (status == 'publishing') _publish(p);
    return p;
  }

  void _publish(Json p) {
    for (final t in (p['targets'] as List).cast<Json>()) {
      t
        ..['status'] = 'published'
        ..['error'] = null
        ..['publishedAt'] = iso(now)
        ..['permalink'] = 'https://example.test/p/${p['id']}';
    }
    p['status'] = 'published';
    p['scheduledAt'] ??= iso(now);
  }

  Json _account(String id, String platform, String name, String handle, {String status = 'ok'}) => {
    'id': id,
    'platform': platform,
    'name': name,
    'handle': handle,
    'avatar': null,
    'remoteId': 'remote-$id',
    'status': status,
    'statusMessage': status == 'ok' ? null : 'The token runs out in 3 days.',
    'expiresAt': status == 'ok' ? null : ahead(const Duration(days: 3)),
    'capabilities': [
      'publish',
      'comments',
      'mentions',
      'insights',
      if (platform == 'instagram' || platform == 'facebook') ...['messages', 'private_reply'],
      if (platform == 'youtube') 'live',
    ],
    'connectedAt': ago(const Duration(days: 40)),
    'checkedAt': ago(const Duration(hours: 1)),
  };

  Json _meta() => {
    'platforms': {
      'instagram': _info(
        'Instagram',
        2200,
        ['post', 'carousel', 'reel', 'story'],
        ['post', 'carousel', 'reel', 'story'],
      ),
      'facebook': _info('Facebook', 63206, ['post', 'reel', 'story'], ['reel', 'story']),
      'youtube': _info('YouTube', 5000, ['video', 'short'], ['video', 'short'], max: 1),
      'linkedin': _info('LinkedIn', 3000, ['post'], []),
      'threads': _info('Threads', 500, ['post', 'carousel'], ['carousel']),
      'bluesky': _info('Bluesky', 300, ['post'], [], max: 4),
      'mastodon': _info('Mastodon', 500, ['post'], [], max: 4),
    },
    'redirectUris': {
      for (final p in ['meta', 'threads', 'google', 'linkedin']) p: '$hubUrl/social/oauth/$p/callback',
    },
    'webhookUrl': '$hubUrl/social/webhook/meta',
    'threadsWebhookUrl': '$hubUrl/social/webhook/threads',
    'verifyToken': 'verify-example',
    'ai': ai,
  };

  Json _info(String name, int maxText, List<String> formats, List<String> mediaRequired, {int max = 10}) => {
    'name': name,
    'maxText': maxText,
    'formats': formats,
    'mediaRequired': mediaRequired,
    'maxMedia': max,
  };

  Json _stats() {
    final per = <Json>[];
    for (final (i, a) in accounts.indexed) {
      final base = 1200 + i * 2350;
      per.add({
        'accountId': a['id'],
        'followers': base + 280,
        'followersDelta7d': 18 + i * 9,
        'posts': 40 + i * 11,
        'views28d': 8000 + i * 5300,
        'series': [
          for (var d = 29; d >= 0; d--)
            {
              'day': iso(now.subtract(Duration(days: d))).substring(0, 10),
              'followers': base + (29 - d) * 9 + (d % 4) * 3,
            },
        ],
      });
    }
    return {
      'accounts': per,
      'bestTimes': [
        for (var day = 0; day < 7; day++)
          for (final hour in [8, 12, 17, 19])
            {'day': day, 'hour': hour, 'score': ((day * 7 + hour * 3) % 10) / 10, 'posts': (day + hour) % 4},
      ],
      'topContent': content.take(4).toList(),
    };
  }

  Json _overview() => {
    'accounts': accounts,
    'stats': _stats(),
    'inbox': {
      'new': inbox.where((i) => i['status'] == 'new').length,
      'read': inbox.where((i) => i['status'] == 'read').length,
    },
    'upcoming': [
      for (final p in posts)
        if (p['status'] == 'scheduled') p,
    ],
    'alerts': alerts.take(5).toList(),
    'recentInbox': inbox.take(6).toList(),
    'topContent': content.take(4).toList(),
    'ideas': {'ideas': _ideas, 'generatedAt': iso(now)},
  };

  static const _ideas = [
    {
      'kind': 'post',
      'title': 'Behind the kiln',
      'body': 'A short reel of a firing; your process videos get twice the saves.',
    },
    {
      'kind': 'timing',
      'title': 'Post on Wednesday evening',
      'body': 'Your audience is most active at 19:00.',
    },
    {
      'kind': 'reply',
      'title': 'Three questions about shipping',
      'body': 'Pin a comment with delivery times.',
    },
  ];

  void _seed() {
    accounts.addAll([
      _account('a1', 'instagram', 'Example Studio', '@example.studio'),
      _account('a2', 'facebook', 'Example Studio', 'Example Studio'),
      _account('a3', 'youtube', 'Example Studio TV', '@examplestudiotv', status: 'expiring'),
      _account('a4', 'linkedin', 'Sam Example', 'sam-example'),
      _account('a5', 'bluesky', 'Example Studio', 'example.bsky.social'),
    ]);
    for (final p in ['meta', 'google', 'linkedin']) {
      credentials[p] = {
        'provider': p,
        'set': true,
        'publicId': '1234567890',
        'updatedAt': ago(const Duration(days: 30)),
      };
    }
    if (ai) {
      credentials['anthropic'] = {
        'provider': 'anthropic',
        'set': true,
        'publicId': null,
        'updatedAt': iso(now),
      };
    }
    final captions = [
      'New speckled glaze mugs are out of the kiln.',
      'Studio tour: where the wheel lives.',
      'Five tips for caring for handmade ceramics.',
      'Live throwing session this Thursday!',
    ];
    final types = ['reel', 'post', 'video', 'post'];
    final platforms = ['instagram', 'facebook', 'youtube', 'linkedin'];
    for (var i = 0; i < 4; i++) {
      content.add({
        'id': 'c$i',
        'accountId': 'a${i + 1}',
        'platform': platforms[i],
        'remoteId': 'rc$i',
        'type': types[i],
        'caption': captions[i],
        'url': 'https://example.test/c/$i',
        'thumbnail': null,
        'at': ago(Duration(days: i * 3 + 1)),
        'likes': 1840 - i * 390,
        'comments': 96 - i * 21,
        'views': 25400 - i * 5200,
      });
    }
    final people = [
      'Riley Example',
      'Jordan Sample',
      'Casey Test',
      'Morgan Demo',
      'Taylor Placeholder',
      'Avery Mock',
    ];
    final texts = [
      'These are gorgeous! Do you ship to Ireland?',
      'What clay body do you use for the speckled ones?',
      'Hi, is the large blue bowl still available?',
      'Great video, the trimming part was so satisfying.',
      'Love this. Tagged you in my unboxing post!',
      'Will there be a restock before Christmas?',
    ];
    final kinds = ['comment', 'comment', 'message', 'comment', 'mention', 'reply'];
    final ctx = ['reel', 'post', 'dm', 'video', 'post', 'post'];
    final where = ['instagram', 'instagram', 'instagram', 'youtube', 'facebook', 'bluesky'];
    final acct = ['a1', 'a1', 'a1', 'a3', 'a2', 'a5'];
    for (var i = 0; i < 6; i++) {
      inbox.add({
        'id': 'i$i',
        'accountId': acct[i],
        'platform': where[i],
        'kind': kinds[i],
        'context': {
          'type': ctx[i],
          'id': 'c$i',
          'title': ctx[i] == 'dm' ? 'Direct message' : captions[i % 4],
          'url': null,
          'thumbnail': null,
        },
        'author': {
          'id': 'u$i',
          'name': people[i],
          'handle': '@${people[i].split(' ').first.toLowerCase()}',
          'avatar': null,
        },
        'text': texts[i],
        'at': ago(Duration(minutes: 12 + i * 47)),
        'remoteId': 'ri$i',
        'status': i < 4 ? 'new' : 'read',
        'labels': [if (i == 0 || i == 5) 'question'],
        'likes': i * 2,
      });
    }
    Json target(String account, String format, String status) => {
      'accountId': account,
      'format': format,
      'status': status,
      'attempts': 0,
    };
    final today = DateTime(now.year, now.month, now.day);
    String at(int days, int hour) => iso(today.add(Duration(days: days, hours: hour)));
    posts.addAll([
      {
        'id': 'p1',
        'text': 'Speckled mugs restock: Friday at noon.',
        'media': [],
        'targets': [target('a1', 'post', 'scheduled'), target('a2', 'post', 'scheduled')],
        'scheduledAt': at(1, 12),
        'status': 'scheduled',
        'tags': ['launch'],
        'createdAt': ago(const Duration(days: 2)),
        'updatedAt': ago(const Duration(days: 2)),
      },
      {
        'id': 'p2',
        'text': 'How we trim a foot ring, in 60 seconds.',
        'media': [],
        'targets': [
          {...target('a3', 'short', 'scheduled'), 'title': 'Trimming a foot ring'},
        ],
        'scheduledAt': at(3, 18),
        'status': 'scheduled',
        'tags': [],
        'createdAt': ago(const Duration(days: 1)),
        'updatedAt': ago(const Duration(days: 1)),
      },
      {
        'id': 'p3',
        'text': 'Our studio is hiring a part-time assistant.',
        'media': [],
        'targets': [
          {...target('a4', 'post', 'failed'), 'error': 'LinkedIn answered 503.', 'attempts': 3},
        ],
        'scheduledAt': at(-1, 10),
        'status': 'failed',
        'tags': [],
        'createdAt': ago(const Duration(days: 3)),
        'updatedAt': ago(const Duration(days: 1)),
      },
      {
        'id': 'p4',
        'text': 'Glaze test tiles, round two.',
        'media': [],
        'targets': [target('a1', 'carousel', 'draft')],
        'scheduledAt': null,
        'status': 'draft',
        'tags': [],
        'createdAt': ago(const Duration(hours: 5)),
        'updatedAt': ago(const Duration(hours: 5)),
      },
      {
        'id': 'p5',
        'text': 'Thank you for 5,000 followers!',
        'media': [],
        'targets': [
          {
            ...target('a1', 'post', 'published'),
            'publishedAt': at(-3, 9),
            'permalink': 'https://example.test/p/5',
          },
        ],
        'scheduledAt': at(-3, 9),
        'status': 'published',
        'tags': [],
        'createdAt': ago(const Duration(days: 4)),
        'updatedAt': ago(const Duration(days: 3)),
      },
    ]);
    alerts.addAll([
      {
        'id': 'al1',
        'at': ago(const Duration(minutes: 25)),
        'kind': 'discovery',
        'title': '2015 automatic hatchback, £5,200',
        'body': 'eBay · Exampletown · 52k miles',
        'url': 'https://example.test/item/9',
        'image': null,
        'ref': 'w1',
        'score': 0.86,
        'reason': 'Automatic, under budget and 12 km away.',
        'read': false,
      },
      {
        'id': 'al2',
        'at': ago(const Duration(hours: 3)),
        'kind': 'inbox',
        'title': 'Question about shipping',
        'body': 'Riley Example asked on Instagram.',
        'url': null,
        'image': null,
        'ref': 'r1',
        'score': null,
        'reason': null,
        'read': false,
      },
      {
        'id': 'al3',
        'at': ago(const Duration(days: 1)),
        'kind': 'publish',
        'title': 'A LinkedIn post failed',
        'body': 'LinkedIn answered 503. It will retry.',
        'url': null,
        'image': null,
        'ref': 'p3',
        'score': null,
        'reason': null,
        'read': true,
      },
    ]);
    rules = [
      {
        'id': 'r1',
        'name': 'Shipping questions',
        'enabled': true,
        'accountIds': null,
        'keywords': ['ship', 'delivery', 'post to'],
        'description': null,
        'reply': null,
        'privateReply': null,
        'alert': true,
      },
      {
        'id': 'r2',
        'name': 'Price requests',
        'enabled': false,
        'accountIds': ['a1'],
        'keywords': ['price', 'how much'],
        'description': null,
        'reply': 'Hi {name}, I have sent you the price list.',
        'privateReply': null,
        'alert': false,
      },
    ];
    watches = [
      {
        'id': 'w1',
        'name': 'Cheap automatic hatchbacks',
        'description': 'An automatic hatchback under £6,000 within 40 km of Exampletown.',
        'sources': [
          {'type': 'ebay', 'query': 'automatic hatchback', 'categoryId': '9801', 'maxPrice': 6000},
          {'type': 'donedeal', 'path': '/cars?transmission=Automatic', 'maxPrice': 6000},
        ],
        'keywords': ['automatic'],
        'ai': true,
        'everyMinutes': 30,
        'paused': false,
      },
      {
        'id': 'w2',
        'name': 'Handmade mug shops',
        'description': 'Instagram shops selling handmade ceramic mugs.',
        'sources': [
          {
            'type': 'instagram_hashtag',
            'accountId': 'a1',
            'hashtags': ['handmademugs', 'pottery'],
          },
        ],
        'keywords': [],
        'ai': true,
        'everyMinutes': 120,
        'paused': true,
      },
    ];
  }
}
