import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vani/domain/models.dart';

/// An in-memory Cloudflare account, plus the deployed hub's /version.
class FakeCloudflare {
  FakeCloudflare({this.r2Enabled = true});
  bool r2Enabled;
  final kv = <String, String>{}, d1 = <String, String>{}, buckets = <String>{};
  final applied = <String>[], statements = <String>[];
  Json? script;
  var schedules = <Object?>[];
  var workersDev = false;
  String? hubToken;
  String version = '0.3.0';

  static const account = 'acc1';

  http.Response ok(Object? result) => http.Response(jsonEncode({'success': true, 'errors': [], 'result': result}), 200);
  http.Response fail(int status, int code, String message) => http.Response(
    jsonEncode({
      'success': false,
      'errors': [
        {'code': code, 'message': message},
      ],
      'result': null,
    }),
    status,
  );

  late final client = MockClient((req) async {
    if (req.url.host.endsWith('workers.dev')) {
      if (req.headers['authorization'] != 'Bearer $hubToken') return http.Response('{"error":"unauthorised"}', 401);
      return http.Response(jsonEncode({'version': version, 'social': true}), 200);
    }
    if (req.headers['authorization'] != 'Bearer cf-key') return fail(403, 10000, 'Authentication error');
    final p = req.url.path.replaceFirst('/client/v4', '');
    const a = '/accounts/$account';
    final body = req.method == 'GET' || req.headers['content-type']?.startsWith('multipart') == true
        ? null
        : jsonDecode(req.body);
    switch ((req.method, p)) {
      case ('GET', '/accounts'):
        return ok([
          {'id': account, 'name': 'Test account'},
        ]);
      case ('GET', '$a/workers/subdomain'):
        return ok({'subdomain': 'tester'});
      case ('GET', '$a/storage/kv/namespaces'):
        return ok([
          for (final e in kv.entries) {'id': e.value, 'title': e.key},
        ]);
      case ('POST', '$a/storage/kv/namespaces'):
        final title = (body as Map)['title'] as String;
        return ok({'id': kv[title] = 'kv-${kv.length + 1}', 'title': title});
      case ('GET', '$a/d1/database'):
        return ok([
          for (final e in d1.entries)
            if (e.key == req.url.queryParameters['name']) {'uuid': e.value, 'name': e.key},
        ]);
      case ('POST', '$a/d1/database'):
        final name = (body as Map)['name'] as String;
        return ok({'uuid': d1[name] = 'db-${d1.length + 1}', 'name': name});
      case ('GET', '$a/workers/scripts/vani-hub/settings'):
        return script == null ? fail(404, 10007, 'workers.api.error.script_not_found') : ok({});
      case ('PUT', '$a/workers/scripts/vani-hub'):
        final text = req.body;
        final start = text.indexOf('{"main_module"');
        script = jsonDecode(text.substring(start, text.indexOf('\r\n', start))) as Json;
        final bindings = objs(script!['bindings']);
        hubToken ??= bindings.where((b) => b['name'] == 'API_TOKEN').map((b) => str(b['text'])).firstOrNull;
        return ok({});
      case ('PUT', '$a/workers/scripts/vani-hub/schedules'):
        schedules = body as List;
        return ok({'schedules': body});
      case ('POST', '$a/workers/scripts/vani-hub/subdomain'):
        workersDev = true;
        return ok({'enabled': true});
    }
    if (req.method == 'POST' && p.startsWith('$a/d1/database/') && p.endsWith('/query')) {
      final sql = (body as Map)['sql'] as String;
      statements.add(sql);
      if (sql.startsWith('SELECT name FROM d1_migrations')) {
        return ok([
          {
            'results': [
              for (final n in applied) {'name': n},
            ],
          },
        ]);
      }
      if (sql.startsWith('INSERT INTO d1_migrations')) applied.add((body['params'] as List).single as String);
      return ok([
        {'results': []},
      ]);
    }
    if (p.startsWith('$a/r2/buckets')) {
      if (!r2Enabled) return fail(403, 10042, 'Please enable R2 through the Cloudflare Dashboard.');
      final name = p.split('/').last;
      if (req.method == 'GET') return buckets.contains(name) ? ok({'name': name}) : fail(404, 10006, 'no bucket');
      buckets.add((body as Map)['name'] as String);
      return ok({});
    }
    return fail(404, 7003, 'No route for ${req.method} $p');
  });
}
