// The social hub's data, as Dart. Mirrors watch/src/social/types.ts in the
// brahma repository field for field; the hub's JSON is read leniently (a
// missing field takes its default) so an older or newer hub still loads.

typedef Json = Map<String, Object?>;

String str(Object? v, [String fallback = '']) => v is String ? v : (v == null ? fallback : '$v');
String? strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;
int integer(Object? v, [int fallback = 0]) => v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);
int? intOrNull(Object? v) => v is num ? v.toInt() : null;
double? numOrNull(Object? v) => v is num ? v.toDouble() : null;
bool flag(Object? v) => v == true;
Json obj(Object? v) => v is Map ? v.cast<String, Object?>() : const {};
List<Json> objs(Object? v) => v is List ? [for (final e in v) obj(e)] : const [];
List<String> strs(Object? v) => v is List ? [for (final e in v) str(e)] : const [];

enum Platform {
  instagram('Instagram'),
  facebook('Facebook'),
  youtube('YouTube'),
  linkedin('LinkedIn'),
  threads('Threads'),
  bluesky('Bluesky'),
  mastodon('Mastodon');

  const Platform(this.label);
  final String label;

  static Platform parse(Object? v) =>
      Platform.values.firstWhere((p) => p.name == v, orElse: () => Platform.instagram);
}

/// OAuth sign-in providers; one can bring several accounts.
enum OAuthProvider {
  meta('Meta', 'Facebook Pages and their Instagram accounts'),
  threads('Threads', 'Threads profile'),
  google('Google', 'YouTube channels'),
  linkedin('LinkedIn', 'LinkedIn profile');

  const OAuthProvider(this.label, this.brings);
  final String label;
  final String brings;
}

/// Providers whose app credentials the hub stores.
enum CredentialProvider { meta, threads, google, linkedin, ebay, anthropic }

const formats = ['post', 'carousel', 'reel', 'story', 'video', 'short'];

String formatLabel(String f) => switch (f) {
  'post' => 'Post',
  'carousel' => 'Carousel',
  'reel' => 'Reel',
  'story' => 'Story',
  'video' => 'Video',
  'short' => 'Short',
  _ => f,
};

class Account {
  const Account({
    required this.id,
    required this.platform,
    required this.name,
    this.handle = '',
    this.avatar,
    this.remoteId = '',
    this.status = 'ok',
    this.statusMessage,
    this.expiresAt,
    this.capabilities = const [],
    this.connectedAt = '',
    this.checkedAt,
  });

  final String id;
  final Platform platform;
  final String name, handle, remoteId, connectedAt;
  final String? avatar, statusMessage, expiresAt, checkedAt;

  /// ok | expiring | broken
  final String status;
  final List<String> capabilities;

  bool can(String capability) => capabilities.contains(capability);

  factory Account.fromJson(Json j) => Account(
    id: str(j['id']),
    platform: Platform.parse(j['platform']),
    name: str(j['name']),
    handle: str(j['handle']),
    avatar: strOrNull(j['avatar']),
    remoteId: str(j['remoteId']),
    status: str(j['status'], 'ok'),
    statusMessage: strOrNull(j['statusMessage']),
    expiresAt: strOrNull(j['expiresAt']),
    capabilities: strs(j['capabilities']),
    connectedAt: str(j['connectedAt']),
    checkedAt: strOrNull(j['checkedAt']),
  );

  Json toJson() => {
    'id': id,
    'platform': platform.name,
    'name': name,
    'handle': handle,
    'avatar': avatar,
    'remoteId': remoteId,
    'status': status,
    'statusMessage': statusMessage,
    'expiresAt': expiresAt,
    'capabilities': capabilities,
    'connectedAt': connectedAt,
    'checkedAt': checkedAt,
  };
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.filename,
    required this.contentType,
    this.size = 0,
    this.status = 'ready',
    this.createdAt = '',
    this.url = '',
  });

  final String id, filename, contentType, status, createdAt, url;
  final int size;

  bool get isVideo => contentType.startsWith('video/');
  bool get isImage => contentType.startsWith('image/');

  factory MediaItem.fromJson(Json j) => MediaItem(
    id: str(j['id']),
    filename: str(j['filename']),
    contentType: str(j['contentType']),
    size: integer(j['size']),
    status: str(j['status'], 'ready'),
    createdAt: str(j['createdAt']),
    url: str(j['url']),
  );

  Json toJson() => {
    'id': id,
    'filename': filename,
    'contentType': contentType,
    'size': size,
    'status': status,
    'createdAt': createdAt,
    'url': url,
  };
}

class Target {
  const Target({
    required this.accountId,
    required this.format,
    this.text,
    this.title,
    this.firstComment,
    this.status = 'draft',
    this.remoteId,
    this.permalink,
    this.error,
    this.maybePosted = false,
    this.attempts = 0,
    this.publishedAt,
  });

  final String accountId, format;
  final String? text, title, firstComment;

  /// draft | scheduled | publishing | published | failed
  final String status;
  final String? remoteId, permalink, error, publishedAt;
  final bool maybePosted;
  final int attempts;

  factory Target.fromJson(Json j) => Target(
    accountId: str(j['accountId']),
    format: str(j['format'], 'post'),
    text: strOrNull(j['text']),
    title: strOrNull(j['title']),
    firstComment: strOrNull(j['firstComment']),
    status: str(j['status'], 'draft'),
    remoteId: strOrNull(j['remoteId']),
    permalink: strOrNull(j['permalink']),
    error: strOrNull(j['error']),
    maybePosted: flag(j['maybePosted']),
    attempts: integer(j['attempts']),
    publishedAt: strOrNull(j['publishedAt']),
  );

  /// The writable part, as PostInput takes it.
  Json toInput() => {
    'accountId': accountId,
    'format': format,
    if (text != null && text!.isNotEmpty) 'text': text,
    if (title != null && title!.isNotEmpty) 'title': title,
    if (firstComment != null && firstComment!.isNotEmpty) 'firstComment': firstComment,
  };

  Json toJson() => {
    ...toInput(),
    'status': status,
    'remoteId': ?remoteId,
    'permalink': ?permalink,
    'error': ?error,
    if (maybePosted) 'maybePosted': true,
    'attempts': attempts,
    'publishedAt': ?publishedAt,
  };
}

class Post {
  const Post({
    required this.id,
    required this.text,
    this.media = const [],
    this.targets = const [],
    this.scheduledAt,
    this.status = 'draft',
    this.recycleDays,
    this.tags = const [],
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id, text, status, createdAt, updatedAt;
  final List<String> media, tags;
  final List<Target> targets;
  final String? scheduledAt;
  final int? recycleDays;

  /// Drafts and scheduled posts can still be edited and moved.
  bool get editable => status == 'draft' || status == 'scheduled';
  bool get maybePosted => targets.any((t) => t.maybePosted);

  /// When it went out, or is due to; drafts have neither.
  String? get when => scheduledAt ?? targets.map((t) => t.publishedAt).nonNulls.firstOrNull;

  factory Post.fromJson(Json j) => Post(
    id: str(j['id']),
    text: str(j['text']),
    media: strs(j['media']),
    targets: [for (final t in objs(j['targets'])) Target.fromJson(t)],
    scheduledAt: strOrNull(j['scheduledAt']),
    status: str(j['status'], 'draft'),
    recycleDays: intOrNull(j['recycleDays']),
    tags: strs(j['tags']),
    createdAt: str(j['createdAt']),
    updatedAt: str(j['updatedAt']),
  );

  Json toJson() => {
    'id': id,
    'text': text,
    'media': media,
    'targets': [for (final t in targets) t.toJson()],
    'scheduledAt': scheduledAt,
    'status': status,
    'recycleDays': ?recycleDays,
    'tags': tags,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// What POST/PUT /social/posts take.
class PostInput {
  const PostInput({
    required this.text,
    this.media = const [],
    required this.targets,
    this.scheduledAt,
    this.queue = false,
    this.draft = false,
    this.recycleDays,
    this.tags = const [],
  });

  final String text;
  final List<String> media, tags;
  final List<Target> targets;
  final String? scheduledAt;
  final bool queue, draft;
  final int? recycleDays;

  factory PostInput.of(Post p, {String? scheduledAt, bool draft = false}) => PostInput(
    text: p.text,
    media: p.media,
    targets: p.targets,
    scheduledAt: scheduledAt ?? p.scheduledAt,
    draft: draft,
    recycleDays: p.recycleDays,
    tags: p.tags,
  );

  Json toJson() => {
    'text': text,
    'media': media,
    'targets': [for (final t in targets) t.toInput()],
    'scheduledAt': scheduledAt,
    if (queue) 'queue': true,
    if (draft) 'draft': true,
    'recycleDays': ?recycleDays,
    'tags': tags,
  };
}

class InboxContext {
  const InboxContext({required this.type, this.id = '', this.title = '', this.url, this.thumbnail});
  final String type, id, title;
  final String? url, thumbnail;

  factory InboxContext.fromJson(Json j) => InboxContext(
    type: str(j['type'], 'post'),
    id: str(j['id']),
    title: str(j['title']),
    url: strOrNull(j['url']),
    thumbnail: strOrNull(j['thumbnail']),
  );

  Json toJson() => {'type': type, 'id': id, 'title': title, 'url': url, 'thumbnail': thumbnail};
}

class Author {
  const Author({this.id = '', required this.name, this.handle = '', this.avatar});
  final String id, name, handle;
  final String? avatar;

  factory Author.fromJson(Json j) => Author(
    id: str(j['id']),
    name: str(j['name']),
    handle: str(j['handle']),
    avatar: strOrNull(j['avatar']),
  );

  Json toJson() => {'id': id, 'name': name, 'handle': handle, 'avatar': avatar};
}

class MyReply {
  const MyReply({required this.text, required this.at, this.private = false});
  final String text, at;
  final bool private;

  factory MyReply.fromJson(Json j) =>
      MyReply(text: str(j['text']), at: str(j['at']), private: flag(j['private']));

  Json toJson() => {'text': text, 'at': at, 'private': private};
}

class InboxItem {
  const InboxItem({
    required this.id,
    required this.accountId,
    required this.platform,
    required this.kind,
    required this.context,
    required this.author,
    required this.text,
    required this.at,
    this.remoteId = '',
    this.parentRemoteId,
    this.status = 'new',
    this.myReply,
    this.labels = const [],
    this.likes,
  });

  final String id, accountId, text, at, remoteId;

  /// comment | reply | message | mention | live_chat
  final String kind;
  final Platform platform;
  final InboxContext context;
  final Author author;
  final String? parentRemoteId;

  /// new | read | done
  final String status;
  final MyReply? myReply;
  final List<String> labels;
  final int? likes;

  factory InboxItem.fromJson(Json j) => InboxItem(
    id: str(j['id']),
    accountId: str(j['accountId']),
    platform: Platform.parse(j['platform']),
    kind: str(j['kind'], 'comment'),
    context: InboxContext.fromJson(obj(j['context'])),
    author: Author.fromJson(obj(j['author'])),
    text: str(j['text']),
    at: str(j['at']),
    remoteId: str(j['remoteId']),
    parentRemoteId: strOrNull(j['parentRemoteId']),
    status: str(j['status'], 'new'),
    myReply: j['myReply'] is Map ? MyReply.fromJson(obj(j['myReply'])) : null,
    labels: strs(j['labels']),
    likes: intOrNull(j['likes']),
  );

  InboxItem copyWith({String? status, MyReply? myReply}) => InboxItem(
    id: id,
    accountId: accountId,
    platform: platform,
    kind: kind,
    context: context,
    author: author,
    text: text,
    at: at,
    remoteId: remoteId,
    parentRemoteId: parentRemoteId,
    status: status ?? this.status,
    myReply: myReply ?? this.myReply,
    labels: labels,
    likes: likes,
  );

  Json toJson() => {
    'id': id,
    'accountId': accountId,
    'platform': platform.name,
    'kind': kind,
    'context': context.toJson(),
    'author': author.toJson(),
    'text': text,
    'at': at,
    'remoteId': remoteId,
    'parentRemoteId': parentRemoteId,
    'status': status,
    'myReply': ?myReply?.toJson(),
    'labels': labels,
    'likes': ?likes,
  };
}

String kindLabel(String kind) => switch (kind) {
  'comment' => 'Comment',
  'reply' => 'Reply',
  'message' => 'Message',
  'mention' => 'Mention',
  'live_chat' => 'Live chat',
  _ => kind,
};

String contextLabel(String type) => switch (type) {
  'post' => 'Post',
  'reel' => 'Reel',
  'story' => 'Story',
  'live' => 'Live',
  'video' => 'Video',
  'short' => 'Short',
  'dm' => 'DM',
  'thread' => 'Thread',
  _ => type,
};

class InboxCounts {
  const InboxCounts({this.fresh = 0, this.read = 0, this.done = 0});
  final int fresh, read, done;
  factory InboxCounts.fromJson(Json j) =>
      InboxCounts(fresh: integer(j['new']), read: integer(j['read']), done: integer(j['done']));
}

class InboxPage {
  const InboxPage(this.items, this.counts);
  final List<InboxItem> items;
  final InboxCounts counts;
}

class Content {
  const Content({
    required this.id,
    required this.accountId,
    required this.platform,
    this.remoteId = '',
    this.type = 'post',
    this.caption = '',
    this.url,
    this.thumbnail,
    this.at = '',
    this.likes = 0,
    this.comments = 0,
    this.views,
  });

  final String id, accountId, remoteId, type, caption, at;
  final Platform platform;
  final String? url, thumbnail;
  final int likes, comments;
  final int? views;

  factory Content.fromJson(Json j) => Content(
    id: str(j['id']),
    accountId: str(j['accountId']),
    platform: Platform.parse(j['platform']),
    remoteId: str(j['remoteId']),
    type: str(j['type'], 'post'),
    caption: str(j['caption']),
    url: strOrNull(j['url']),
    thumbnail: strOrNull(j['thumbnail']),
    at: str(j['at']),
    likes: integer(j['likes']),
    comments: integer(j['comments']),
    views: intOrNull(j['views']),
  );

  Json toJson() => {
    'id': id,
    'accountId': accountId,
    'platform': platform.name,
    'remoteId': remoteId,
    'type': type,
    'caption': caption,
    'url': url,
    'thumbnail': thumbnail,
    'at': at,
    'likes': likes,
    'comments': comments,
    'views': views,
  };
}

class InboxRule {
  const InboxRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.accountIds,
    this.keywords = const [],
    this.description,
    this.reply,
    this.privateReply,
    this.alert = true,
  });

  final String id, name;
  final bool enabled, alert;
  final List<String>? accountIds;
  final List<String> keywords;
  final String? description, reply, privateReply;

  factory InboxRule.fromJson(Json j) => InboxRule(
    id: str(j['id']),
    name: str(j['name']),
    enabled: j['enabled'] != false,
    accountIds: j['accountIds'] is List ? strs(j['accountIds']) : null,
    keywords: strs(j['keywords']),
    description: strOrNull(j['description']),
    reply: strOrNull(j['reply']),
    privateReply: strOrNull(j['privateReply']),
    alert: j['alert'] != false,
  );

  InboxRule copyWith({bool? enabled}) => InboxRule(
    id: id,
    name: name,
    enabled: enabled ?? this.enabled,
    accountIds: accountIds,
    keywords: keywords,
    description: description,
    reply: reply,
    privateReply: privateReply,
    alert: alert,
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'accountIds': accountIds,
    'keywords': keywords,
    'description': ?description,
    'reply': ?reply,
    'privateReply': ?privateReply,
    'alert': alert,
  };
}

/// One field of a discovery source, for the generic source editor.
class SourceField {
  const SourceField(this.key, this.label, this.kind, {this.required = false, this.hint = ''});
  final String key, label, hint;

  /// text, number, list, or `account:<platform>`
  final String kind;
  final bool required;
}

/// A discovery source: its type and fields as the hub's JSON has them.
class DiscoverySource {
  const DiscoverySource(this.type, this.data);
  final String type;
  final Json data;

  static const types = ['ebay', 'donedeal', 'instagram_hashtag', 'instagram_business', 'bluesky', 'youtube'];

  static String label(String type) => switch (type) {
    'ebay' => 'eBay listings',
    'donedeal' => 'DoneDeal search',
    'instagram_hashtag' => 'Instagram hashtags',
    'instagram_business' => 'Instagram businesses',
    'bluesky' => 'Bluesky posts',
    'youtube' => 'YouTube videos',
    _ => type,
  };

  static List<SourceField> fields(String type) => switch (type) {
    'ebay' => const [
      SourceField('query', 'Search words', 'text', required: true, hint: 'e.g. toyota yaris automatic'),
      SourceField('categoryId', 'Category id', 'text', hint: '9801 = Cars on eBay UK'),
      SourceField('postcode', 'Near postcode', 'text'),
      SourceField('radiusKm', 'Within km', 'number'),
      SourceField('maxPrice', 'Max price', 'number'),
    ],
    'donedeal' => const [
      SourceField('path', 'Search path', 'text', required: true, hint: '/cars?area=Fermanagh'),
      SourceField('maxPrice', 'Max price', 'number'),
    ],
    'instagram_hashtag' => const [
      SourceField('accountId', 'Search with account', 'account:instagram', required: true),
      SourceField('hashtags', 'Hashtags', 'list', required: true, hint: 'without #, comma separated'),
    ],
    'instagram_business' => const [
      SourceField('accountId', 'Search with account', 'account:instagram', required: true),
      SourceField('usernames', 'Usernames', 'list', required: true, hint: 'business or creator accounts'),
    ],
    'bluesky' => const [SourceField('query', 'Search words', 'text', required: true)],
    'youtube' => const [
      SourceField('accountId', 'Search with account', 'account:youtube', required: true),
      SourceField('query', 'Search words', 'text', required: true),
    ],
    _ => const [],
  };

  /// What a required field still lacks, or null when complete.
  String? problem() {
    for (final f in fields(type)) {
      final v = data[f.key];
      final empty = v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);
      if (f.required && empty) return '${label(type)}: ${f.label} is required.';
    }
    if (type == 'donedeal' && !str(data['path']).startsWith('/')) {
      return 'DoneDeal: the search path starts with "/", e.g. /cars?area=Fermanagh.';
    }
    return null;
  }

  factory DiscoverySource.fromJson(Json j) => DiscoverySource(str(j['type']), {
    for (final e in j.entries)
      if (e.key != 'type') e.key: e.value,
  });

  Json toJson() => {
    'type': type,
    for (final e in data.entries)
      if (e.value != null && !(e.value is String && (e.value as String).isEmpty)) e.key: e.value,
  };
}

class DiscoveryWatch {
  const DiscoveryWatch({
    required this.id,
    required this.name,
    this.description = '',
    this.sources = const [],
    this.keywords = const [],
    this.ai = true,
    this.everyMinutes = 30,
    this.paused = false,
  });

  final String id, name, description;
  final List<DiscoverySource> sources;
  final List<String> keywords;
  final bool ai, paused;
  final int everyMinutes;

  factory DiscoveryWatch.fromJson(Json j) => DiscoveryWatch(
    id: str(j['id']),
    name: str(j['name']),
    description: str(j['description']),
    sources: [for (final s in objs(j['sources'])) DiscoverySource.fromJson(s)],
    keywords: strs(j['keywords']),
    ai: j['ai'] != false,
    everyMinutes: integer(j['everyMinutes'], 30),
    paused: flag(j['paused']),
  );

  DiscoveryWatch copyWith({bool? paused, String? id}) => DiscoveryWatch(
    id: id ?? this.id,
    name: name,
    description: description,
    sources: sources,
    keywords: keywords,
    ai: ai,
    everyMinutes: everyMinutes,
    paused: paused ?? this.paused,
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sources': [for (final s in sources) s.toJson()],
    'keywords': keywords,
    'ai': ai,
    'everyMinutes': everyMinutes,
    'paused': paused,
  };
}

class Find {
  const Find({
    required this.id,
    required this.source,
    required this.title,
    this.text = '',
    this.url = '',
    this.image,
    this.price,
    this.currency,
    this.location,
    this.at,
  });

  final String id, source, title, text, url;
  final String? image, currency, location, at;
  final double? price;

  factory Find.fromJson(Json j) => Find(
    id: str(j['id']),
    source: str(j['source']),
    title: str(j['title']),
    text: str(j['text']),
    url: str(j['url']),
    image: strOrNull(j['image']),
    price: numOrNull(j['price']),
    currency: strOrNull(j['currency']),
    location: strOrNull(j['location']),
    at: strOrNull(j['at']),
  );
}

class Alert {
  const Alert({
    required this.id,
    required this.at,
    required this.kind,
    required this.title,
    this.body = '',
    this.url,
    this.image,
    this.ref,
    this.score,
    this.reason,
    this.read = false,
  });

  final String id, at, title, body;

  /// discovery | inbox | publish | account | system
  final String kind;
  final String? url, image, ref, reason;
  final double? score;
  final bool read;

  factory Alert.fromJson(Json j) => Alert(
    id: str(j['id']),
    at: str(j['at']),
    kind: str(j['kind'], 'system'),
    title: str(j['title']),
    body: str(j['body']),
    url: strOrNull(j['url']),
    image: strOrNull(j['image']),
    ref: strOrNull(j['ref']),
    score: numOrNull(j['score']),
    reason: strOrNull(j['reason']),
    read: flag(j['read']),
  );

  Json toJson() => {
    'id': id,
    'at': at,
    'kind': kind,
    'title': title,
    'body': body,
    'url': url,
    'image': image,
    'ref': ref,
    'score': ?score,
    'reason': ?reason,
    'read': read,
  };
}

class StatPoint {
  const StatPoint(this.day, this.followers);
  final String day;
  final int followers;
}

class AccountStats {
  const AccountStats({
    required this.accountId,
    this.followers,
    this.followersDelta7d,
    this.posts,
    this.views28d,
    this.series = const [],
  });

  final String accountId;
  final int? followers, followersDelta7d, posts, views28d;
  final List<StatPoint> series;

  factory AccountStats.fromJson(Json j) => AccountStats(
    accountId: str(j['accountId']),
    followers: intOrNull(j['followers']),
    followersDelta7d: intOrNull(j['followersDelta7d']),
    posts: intOrNull(j['posts']),
    views28d: intOrNull(j['views28d']),
    series: [for (final p in objs(j['series'])) StatPoint(str(p['day']), integer(p['followers']))],
  );
}

class BestTime {
  const BestTime(this.day, this.hour, this.score, this.posts);

  /// 0 = Monday; hour in UTC.
  final int day, hour, posts;
  final double score;
}

class Stats {
  const Stats({this.accounts = const [], this.bestTimes = const [], this.topContent = const []});
  final List<AccountStats> accounts;
  final List<BestTime> bestTimes;
  final List<Content> topContent;

  int get followers => accounts.fold(0, (s, a) => s + (a.followers ?? 0));
  int get followersDelta => accounts.fold(0, (s, a) => s + (a.followersDelta7d ?? 0));
  int get views28d => accounts.fold(0, (s, a) => s + (a.views28d ?? 0));

  /// Total followers per day across accounts, oldest first.
  List<StatPoint> get totalSeries {
    final byDay = <String, int>{};
    for (final a in accounts) {
      for (final p in a.series) {
        byDay[p.day] = (byDay[p.day] ?? 0) + p.followers;
      }
    }
    final days = byDay.keys.toList()..sort();
    return [for (final d in days) StatPoint(d, byDay[d]!)];
  }

  /// The best-scoring slot with at least one post, or null.
  BestTime? get bestSlot {
    final tried = bestTimes.where((b) => b.posts > 0).toList()..sort((a, b) => b.score.compareTo(a.score));
    return tried.firstOrNull;
  }

  factory Stats.fromJson(Json j) => Stats(
    accounts: [for (final a in objs(j['accounts'])) AccountStats.fromJson(a)],
    bestTimes: [
      for (final b in objs(j['bestTimes']))
        BestTime(integer(b['day']), integer(b['hour']), numOrNull(b['score']) ?? 0, integer(b['posts'])),
    ],
    topContent: [for (final c in objs(j['topContent'])) Content.fromJson(c)],
  );
}

class QueueSlot {
  const QueueSlot(this.day, this.time);

  /// 0 = Monday; "HH:MM" local to the hub's timezone setting.
  final int day;
  final String time;

  Json toJson() => {'day': day, 'time': time};
}

class SavedReply {
  const SavedReply({required this.id, required this.title, required this.text});
  final String id, title, text;
  Json toJson() => {'id': id, 'title': title, 'text': text};
}

const aiModels = {
  'claude-opus-5-5': 'Claude Opus 5.5 (best)',
  'claude-sonnet-5-5': 'Claude Sonnet 5.5 (faster)',
  'claude-haiku-5-5': 'Claude Haiku 5.5 (cheapest)',
};

class HubSettings {
  const HubSettings({
    this.timezone = 'Europe/London',
    this.queue = const [],
    this.savedReplies = const [],
    this.model = 'claude-opus-5-5',
  });

  final String timezone, model;
  final List<QueueSlot> queue;
  final List<SavedReply> savedReplies;

  factory HubSettings.fromJson(Json j) => HubSettings(
    timezone: str(j['timezone'], 'Europe/London'),
    queue: [for (final q in objs(j['queue'])) QueueSlot(integer(q['day']), str(q['time']))],
    savedReplies: [
      for (final r in objs(j['savedReplies']))
        SavedReply(id: str(r['id']), title: str(r['title']), text: str(r['text'])),
    ],
    model: str(j['model'], 'claude-opus-5-5'),
  );

  HubSettings copyWith({
    String? timezone,
    List<QueueSlot>? queue,
    List<SavedReply>? savedReplies,
    String? model,
  }) => HubSettings(
    timezone: timezone ?? this.timezone,
    queue: queue ?? this.queue,
    savedReplies: savedReplies ?? this.savedReplies,
    model: model ?? this.model,
  );

  Json toJson() => {
    'timezone': timezone,
    'queue': [for (final q in queue) q.toJson()],
    'savedReplies': [for (final r in savedReplies) r.toJson()],
    'model': model,
  };
}

class PlatformInfo {
  const PlatformInfo({
    required this.name,
    this.maxText = 2200,
    this.formats = const ['post'],
    this.mediaRequired = const [],
    this.maxMedia = 10,
  });

  final String name;
  final int maxText, maxMedia;
  final List<String> formats, mediaRequired;

  factory PlatformInfo.fromJson(Json j) => PlatformInfo(
    name: str(j['name']),
    maxText: integer(j['maxText'], 2200),
    formats: strs(j['formats']),
    mediaRequired: strs(j['mediaRequired']),
    maxMedia: integer(j['maxMedia'], 10),
  );
}

class HubMeta {
  const HubMeta({
    this.platforms = const {},
    this.redirectUris = const {},
    this.webhookUrl = '',
    this.threadsWebhookUrl = '',
    this.verifyToken = '',
    this.ai = false,
  });

  final Map<Platform, PlatformInfo> platforms;
  final Map<String, String> redirectUris;
  final String webhookUrl, threadsWebhookUrl, verifyToken;

  /// Whether the hub has an Anthropic key, so the AI features work.
  final bool ai;

  PlatformInfo info(Platform p) => platforms[p] ?? PlatformInfo(name: p.label);

  factory HubMeta.fromJson(Json j) => HubMeta(
    platforms: {
      for (final e in obj(j['platforms']).entries)
        if (Platform.values.any((p) => p.name == e.key))
          Platform.parse(e.key): PlatformInfo.fromJson(obj(e.value)),
    },
    redirectUris: {for (final e in obj(j['redirectUris']).entries) e.key: str(e.value)},
    webhookUrl: str(j['webhookUrl']),
    threadsWebhookUrl: str(j['threadsWebhookUrl']),
    verifyToken: str(j['verifyToken']),
    ai: flag(j['ai']),
  );
}

class CredentialStatus {
  const CredentialStatus({required this.provider, this.set = false, this.publicId, this.updatedAt});
  final String provider;
  final bool set;
  final String? publicId, updatedAt;

  factory CredentialStatus.fromJson(Json j) => CredentialStatus(
    provider: str(j['provider']),
    set: flag(j['set']),
    publicId: strOrNull(j['publicId']),
    updatedAt: strOrNull(j['updatedAt']),
  );
}

class Idea {
  const Idea({required this.kind, required this.title, required this.body});
  final String kind, title, body;
  factory Idea.fromJson(Json j) => Idea(kind: str(j['kind']), title: str(j['title']), body: str(j['body']));
}

/// Ideas arrive as `{ideas, generatedAt}` or as a bare list.
List<Idea> parseIdeas(Object? v) => [for (final i in objs(v is Map ? v['ideas'] : v)) Idea.fromJson(i)];

class CaptionResult {
  const CaptionResult(this.variants, this.hashtags);
  final Map<Platform, String> variants;
  final List<String> hashtags;
}

class Overview {
  const Overview({
    this.accounts = const [],
    this.stats = const Stats(),
    this.inboxNew = 0,
    this.inboxRead = 0,
    this.upcoming = const [],
    this.alerts = const [],
    this.recentInbox = const [],
    this.topContent = const [],
    this.ideas = const [],
  });

  final List<Account> accounts;
  final Stats stats;
  final int inboxNew, inboxRead;
  final List<Post> upcoming;
  final List<Alert> alerts;
  final List<InboxItem> recentInbox;
  final List<Content> topContent;
  final List<Idea> ideas;

  factory Overview.fromJson(Json j) {
    final inbox = obj(j['inbox']);
    return Overview(
      accounts: [for (final a in objs(j['accounts'])) Account.fromJson(a)],
      stats: Stats.fromJson(obj(j['stats'])),
      inboxNew: integer(inbox['new']),
      inboxRead: integer(inbox['read']),
      upcoming: [for (final p in objs(j['upcoming'])) Post.fromJson(p)],
      alerts: [for (final a in objs(j['alerts'])) Alert.fromJson(a)],
      recentInbox: [for (final i in objs(j['recentInbox'])) InboxItem.fromJson(i)],
      topContent: [for (final c in objs(j['topContent'])) Content.fromJson(c)],
      ideas: parseIdeas(j['ideas']),
    );
  }
}
