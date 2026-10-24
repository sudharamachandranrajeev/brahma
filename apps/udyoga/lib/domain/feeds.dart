import 'dart:convert';

import 'package:http/http.dart' as http;

import 'countries.dart';
import 'json.dart';

/// An opening as a job feed gives it, before it is saved.
class Posting {
  const Posting({
    required this.source,
    required this.sourceId,
    required this.title,
    this.company = '',
    this.location = '',
    this.country = '',
    this.remote = false,
    this.salaryMin,
    this.salaryMax,
    this.currency = '',
    this.salaryText = '',
    this.url = '',
    this.description = '',
    this.posted,
    this.closing,
  });
  final String source, sourceId, title, company, location, country;
  final bool remote;
  final int? salaryMin, salaryMax;
  final String currency, salaryText, url, description;
  final String? posted, closing;
}

/// What to look for: search terms, where, and whether remote work counts.
class FeedQuery {
  const FeedQuery({required this.terms, required this.country, this.place = '', this.remote = false});
  final List<String> terms;

  /// ISO alpha-2.
  final String country;
  final String place;
  final bool remote;
}

/// Free job-search APIs. Each says which countries it covers; keys (where
/// needed) are the user's own, free from the provider.
abstract class JobFeed {
  String get id;
  String get name;

  /// Where to get a key, or null when none is needed.
  String? get keyUrl => null;
  bool covers(FeedQuery q);
  Future<List<Posting>> search(FeedQuery q);
}

class FeedException implements Exception {
  FeedException(this.message);
  final String message;
  @override
  String toString() => message;
}

String? _date(Object? v) {
  final s = str(v);
  if (s.isEmpty) return null;
  final uk = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s);
  if (uk != null) return '${uk[3]}-${uk[2]}-${uk[1]}';
  return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s) ? s.substring(0, 10) : null;
}

Future<Object?> _getJson(http.Client client, Uri uri, {Map<String, String> headers = const {}}) async {
  final r = await client
      .get(uri, headers: {'accept': 'application/json', ...headers})
      .timeout(const Duration(seconds: 30));
  if (r.statusCode == 401 || r.statusCode == 403) throw FeedException('the key was rejected');
  if (r.statusCode != 200) throw FeedException('error ${r.statusCode}');
  return jsonDecode(utf8.decode(r.bodyBytes));
}

bool _mentions(String text, List<String> terms) {
  final t = text.toLowerCase();
  return terms.any((term) => term.toLowerCase().split(RegExp(r'\s+')).every(t.contains));
}

/// Adzuna: many countries, needs a free app id and key.
class AdzunaFeed extends JobFeed {
  AdzunaFeed(this.client, {required this.appId, required this.appKey});
  final http.Client client;
  final String appId, appKey;

  @override
  String get id => 'adzuna';
  @override
  String get name => 'Adzuna';
  @override
  String get keyUrl => 'https://developer.adzuna.com/signup';

  @override
  bool covers(FeedQuery q) => appId.isNotEmpty && Country.of(q.country)?.adzuna != null;

  @override
  Future<List<Posting>> search(FeedQuery q) async {
    final cc = Country.of(q.country)!.adzuna!;
    final out = <Posting>[];
    for (final term in q.terms.take(4)) {
      final uri = Uri.https('api.adzuna.com', '/v1/api/jobs/$cc/search/1', {
        'app_id': appId,
        'app_key': appKey,
        'what': term,
        if (q.place.isNotEmpty) 'where': q.place,
        'results_per_page': '30',
        'max_days_old': '21',
        'sort_by': 'date',
      });
      for (final r in objs(obj(await _getJson(client, uri))['results'])) {
        final min = intOf(r['salary_min']), max = intOf(r['salary_max']);
        final predicted = str(r['salary_is_predicted']) == '1';
        out.add(
          Posting(
            source: id,
            sourceId: str(r['id']),
            title: htmlToText(str(r['title'])),
            company: str(obj(r['company'])['display_name']),
            location: str(obj(r['location'])['display_name']),
            country: q.country,
            salaryMin: predicted ? null : min,
            salaryMax: predicted ? null : max,
            currency: predicted ? '' : Country.of(q.country)!.currency,
            salaryText: predicted && min != null
                ? 'Estimated ${Country.of(q.country)!.currency} $min–$max'
                : '',
            url: str(r['redirect_url']),
            description: htmlToText(str(r['description'])),
            posted: _date(r['created']),
          ),
        );
      }
    }
    return out;
  }
}

/// Reed: the UK, needs a free API key.
class ReedFeed extends JobFeed {
  ReedFeed(this.client, {required this.key});
  final http.Client client;
  final String key;

  @override
  String get id => 'reed';
  @override
  String get name => 'Reed';
  @override
  String get keyUrl => 'https://www.reed.co.uk/developers/jobseeker';

  @override
  bool covers(FeedQuery q) => key.isNotEmpty && q.country == 'GB';

  @override
  Future<List<Posting>> search(FeedQuery q) async {
    final auth = 'Basic ${base64Encode(utf8.encode('$key:'))}';
    final out = <Posting>[];
    for (final term in q.terms.take(4)) {
      final uri = Uri.https('www.reed.co.uk', '/api/1.0/search', {
        'keywords': term,
        if (q.place.isNotEmpty) 'locationName': q.place,
        if (q.place.isNotEmpty) 'distanceFromLocation': '25',
        'resultsToTake': '40',
      });
      for (final r in objs(obj(await _getJson(client, uri, headers: {'authorization': auth}))['results'])) {
        out.add(
          Posting(
            source: id,
            sourceId: str(r['jobId']),
            title: str(r['jobTitle']),
            company: str(r['employerName']),
            location: str(r['locationName']),
            country: 'GB',
            salaryMin: intOf(r['minimumSalary']),
            salaryMax: intOf(r['maximumSalary']),
            currency: str(r['currency']).isEmpty ? 'GBP' : str(r['currency']),
            url: str(r['jobUrl']),
            description: htmlToText(str(r['jobDescription'])),
            posted: _date(r['date']),
            closing: _date(r['expirationDate']),
          ),
        );
      }
    }
    return out;
  }
}

/// Remotive: remote jobs worldwide, no key. Its terms ask for a link back
/// (each job opens on Remotive) and at most a few calls a day.
class RemotiveFeed extends JobFeed {
  RemotiveFeed(this.client);
  final http.Client client;

  @override
  String get id => 'remotive';
  @override
  String get name => 'Remotive';

  /// Worldwide, so it answers only the country-less remote query.
  @override
  bool covers(FeedQuery q) => q.remote && q.country.isEmpty;

  @override
  Future<List<Posting>> search(FeedQuery q) async {
    final out = <Posting>[];
    for (final term in q.terms.take(3)) {
      final uri = Uri.https('remotive.com', '/api/remote-jobs', {'search': term, 'limit': '30'});
      for (final r in objs(obj(await _getJson(client, uri))['jobs'])) {
        out.add(
          Posting(
            source: id,
            sourceId: str(r['id']),
            title: str(r['title']),
            company: str(r['company_name']),
            location: str(r['candidate_required_location']),
            remote: true,
            salaryText: str(r['salary']),
            url: str(r['url']),
            description: htmlToText(str(r['description'])),
            posted: _date(r['publication_date']),
          ),
        );
      }
    }
    return out;
  }
}

/// Jobicy: remote jobs by region, no key.
class JobicyFeed extends JobFeed {
  JobicyFeed(this.client);
  final http.Client client;

  @override
  String get id => 'jobicy';
  @override
  String get name => 'Jobicy';

  static const _geo = {
    'GB': 'uk',
    'IE': 'ireland',
    'US': 'usa',
    'CA': 'canada',
    'DE': 'germany',
    'FR': 'france',
    'ES': 'spain',
    'NL': 'netherlands',
    'AU': 'australia',
    'IN': 'apac',
  };

  @override
  bool covers(FeedQuery q) => q.remote && _geo.containsKey(q.country);

  @override
  Future<List<Posting>> search(FeedQuery q) async {
    final out = <Posting>[];
    for (final term in q.terms.take(3)) {
      final uri = Uri.https('jobicy.com', '/api/v2/remote-jobs', {
        'count': '30',
        'geo': _geo[q.country]!,
        'tag': term,
      });
      for (final r in objs(obj(await _getJson(client, uri))['jobs'])) {
        out.add(
          Posting(
            source: id,
            sourceId: str(r['id']),
            title: htmlToText(str(r['jobTitle'])),
            company: str(r['companyName']),
            location: str(r['jobGeo']),
            remote: true,
            salaryMin: intOf(r['annualSalaryMin']),
            salaryMax: intOf(r['annualSalaryMax']),
            currency: str(r['salaryCurrency']),
            url: str(r['url']),
            description: htmlToText(str(r['jobDescription'])),
            posted: _date(r['pubDate']),
          ),
        );
      }
    }
    return out;
  }
}

/// Arbeitnow: jobs in Germany and nearby, no key and no search, so the
/// newest page is filtered here.
class ArbeitnowFeed extends JobFeed {
  ArbeitnowFeed(this.client);
  final http.Client client;

  @override
  String get id => 'arbeitnow';
  @override
  String get name => 'Arbeitnow';

  @override
  bool covers(FeedQuery q) => const {'DE', 'AT', 'CH'}.contains(q.country);

  @override
  Future<List<Posting>> search(FeedQuery q) async {
    final data = obj(await _getJson(client, Uri.https('www.arbeitnow.com', '/api/job-board-api')));
    return [
      for (final r in objs(data['data']))
        if (_mentions('${r['title']} ${strs(r['tags']).join(' ')}', q.terms))
          Posting(
            source: id,
            sourceId: str(r['slug']),
            title: str(r['title']),
            company: str(r['company_name']),
            location: str(r['location']),
            country: q.country,
            remote: r['remote'] == true,
            url: str(r['url']),
            description: htmlToText(str(r['description'])),
            posted: switch (intOf(r['created_at'])) {
              final t? => DateTime.fromMillisecondsSinceEpoch(
                t * 1000,
                isUtc: true,
              ).toIso8601String().substring(0, 10),
              null => null,
            },
          ),
    ];
  }
}

/// The user's job-feed keys (synced, end-to-end encrypted).
class FeedKeys {
  const FeedKeys({this.adzunaId = '', this.adzunaKey = '', this.reed = ''});
  final String adzunaId, adzunaKey, reed;

  factory FeedKeys.fromJson(Json j) =>
      FeedKeys(adzunaId: str(j['adzunaId']), adzunaKey: str(j['adzunaKey']), reed: str(j['reed']));
  Json toJson() => {'adzunaId': adzunaId, 'adzunaKey': adzunaKey, 'reed': reed};
}

List<JobFeed> allFeeds(http.Client client, FeedKeys keys) => [
  AdzunaFeed(client, appId: keys.adzunaId, appKey: keys.adzunaKey),
  ReedFeed(client, key: keys.reed),
  RemotiveFeed(client),
  JobicyFeed(client),
  ArbeitnowFeed(client),
];
