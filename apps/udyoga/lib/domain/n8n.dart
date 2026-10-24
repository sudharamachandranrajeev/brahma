import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:http/http.dart' as http;

import '../db/database.dart';
import 'insights.dart';
import 'json.dart';
import 'profile.dart';
import 'pipeline.dart';

/// The user's own n8n lead workflow (docs/n8n): a webhook that takes a job
/// and answers with contacts in [LeadSuggestion]'s shape. n8n runs where the
/// user chooses, with their own search and AI keys, and can do more than the
/// app's built-in search (more sources, their own rules, a digest by e-mail).
class N8nLink {
  const N8nLink({this.url = '', this.secret = ''});
  final String url;

  /// Sent as the `X-Udyoga-Secret` header; the workflow's webhook checks it.
  final String secret;

  bool get isSet => url.isNotEmpty;

  factory N8nLink.fromJson(Json j) => N8nLink(url: str(j['url']), secret: str(j['secret']));

  Json toJson() => {'url': url, 'secret': secret};

  /// HTTPS, or plain HTTP to this machine or a private network only, as for
  /// the sync server.
  static Uri check(String url) {
    try {
      return validateServerUrl(url);
    } on SyncException {
      throw N8nException('Use an https:// webhook address, or http:// only on your own network.');
    }
  }
}

class N8nException implements Exception, UserFacingError {
  N8nException(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

/// What goes to the workflow: the job and the candidate's direction, never
/// their name or contact details.
Json n8nLeadRequest(CandidateProfile p, Job j) => {
  'job': {
    'title': j.title,
    'company': j.company,
    'location': j.location,
    'country': j.country,
    'url': j.url,
    'description': j.description.length > 4000 ? j.description.substring(0, 4000) : j.description,
  },
  'candidate': {
    'currentRole': p.currentRole,
    'targetRoles': p.targets.roles,
    'skills': p.skills.take(15).toList(),
    'country': p.country,
  },
};

/// Asks the workflow for contacts for [j].
Future<List<LeadSuggestion>> n8nLeads(http.Client client, N8nLink link, CandidateProfile p, Job j) async {
  final uri = N8nLink.check(link.url);
  final http.Response r;
  try {
    r = await client
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            if (link.secret.isNotEmpty) 'x-udyoga-secret': link.secret,
          },
          body: jsonEncode(n8nLeadRequest(p, j)),
        )
        // The workflow searches and asks an AI, which takes a while.
        .timeout(const Duration(minutes: 3));
  } on TimeoutException {
    throw N8nException('The n8n workflow did not answer in time.');
  } on SocketException {
    throw N8nException('Could not reach the n8n workflow. Is n8n running?');
  } on http.ClientException catch (e) {
    throw N8nException('Could not reach the n8n workflow: ${e.message}');
  }
  if (r.statusCode == 401 || r.statusCode == 403) throw N8nException('The n8n workflow refused the secret.');
  if (r.statusCode == 404) throw N8nException('No n8n workflow at that address. Is it active?');
  if (r.statusCode != 200) throw N8nException('The n8n workflow answered with error ${r.statusCode}.');
  final Object? body;
  try {
    body = jsonDecode(utf8.decode(r.bodyBytes));
  } on FormatException {
    throw N8nException('The n8n workflow did not answer with JSON.');
  }
  // n8n answers with one item or a list of items, depending on the
  // Respond to Webhook node's setting.
  final data = body is List && body.length == 1 ? body.first : body;
  if (data is! Map || data['leads'] is! List) {
    throw N8nException('The n8n workflow answered without a "leads" list.');
  }
  return [
    for (final l in objs(data['leads']))
      if (str(l['name']).isNotEmpty) LeadSuggestion(normaliseLead(l)),
  ];
}

/// Every field [LeadSuggestion] reads, as text, with unknown kinds as
/// "other"; a hand-built workflow need not fill them all.
Json normaliseLead(Json l) {
  const fields = ['name', 'title', 'company', 'linkedin', 'email', 'source', 'why', 'approach'];
  final kind = str(l['kind']);
  return {for (final f in fields) f: str(l[f]).trim(), 'kind': leadKinds.containsKey(kind) ? kind : 'other'};
}
