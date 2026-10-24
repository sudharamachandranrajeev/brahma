import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:http/http.dart' as http;

import 'json.dart';
import 'schema.dart';

/// A failure talking to Claude, worded for the user.
class AiException implements Exception, UserFacingError {
  AiException(this.message, {this.retryable = false});
  @override
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

/// Models the user can choose in Settings, best first.
const aiModels = {
  'claude-opus-5-5': 'Claude Opus 5.5 (most thorough)',
  'claude-sonnet-5-5': 'Claude Sonnet 5.5 (faster, half the price)',
  'claude-haiku-5-5': 'Claude Haiku 5.5 (quickest, cheapest)',
};
const defaultModel = 'claude-opus-5-5';

/// US dollars per million input and output tokens, and per web search.
const _prices = {
  'claude-opus-5-5': (4.0, 20.0),
  'claude-sonnet-5-5': (2.0, 10.0),
  'claude-haiku-5-5': (0.10, 0.50),
};
const _perSearch = 0.01;

/// What a request used, and roughly what it cost.
class AiUsage {
  const AiUsage({this.input = 0, this.output = 0, this.searches = 0, this.dollars = 0});
  final int input, output, searches;
  final double dollars;

  AiUsage operator +(AiUsage o) => AiUsage(
    input: input + o.input,
    output: output + o.output,
    searches: searches + o.searches,
    dollars: dollars + o.dollars,
  );
}

typedef Source = ({String title, String url});

class AiResult {
  const AiResult(this.data, {this.sources = const [], this.usage = const AiUsage()});
  final Json data;

  /// Pages the answer drew on: those Claude listed, then those it read.
  final List<Source> sources;
  final AiUsage usage;

  /// The answer with every source in it, for storing.
  Json get withSources => {
    ...data,
    'sources': [
      for (final s in sources) {'title': s.title, 'url': s.url},
    ],
  };
}

/// Calls the Claude Messages API over HTTP (Dart has no official SDK) with
/// the user's own API key. Every answer is JSON in a given schema: plain
/// requests use structured outputs; requests that research the web first
/// hand their answer to a `submit` tool, which the client validates.
class Claude {
  Claude({required this.apiKey, this.model = defaultModel, http.Client? client, this.onUsage})
    : _http = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  /// Told about every request's usage (the spend counter in Settings).
  final void Function(AiUsage usage)? onUsage;

  static final endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
  static const _version = '2026-10-21';

  /// Haiku has no server-side refusal fallback; the others fall back to the
  /// model Anthropic recommends for the refusal's category.
  bool get _fallbacks => !_haiku;

  /// Haiku also lacks the web tools' dynamic filtering, so it gets their
  /// basic versions.
  bool get _haiku => model.startsWith('claude-haiku');

  /// Asks Claude for JSON matching [schema].
  ///
  /// [content] is the user turn's content blocks (text, a PDF document...).
  /// With [web], Claude may search and read up to [searches] web pages
  /// first. [onProgress] hears what it is doing ("Searching: ...").
  Future<AiResult> ask({
    required String system,
    required List<Json> content,
    required Json schema,
    bool web = false,
    int searches = 8,
    String effort = 'high',
    int maxTokens = 32000,
    void Function(String status)? onProgress,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw AiException('Add your Claude API key in Settings to use the AI features.');
    }
    final messages = <Json>[
      {'role': 'user', 'content': content},
    ];
    final body = <String, Object?>{
      'model': model,
      'max_tokens': maxTokens,
      'system': web
          ? '$system\n\nResearch with the web tools as needed, then call the submit tool exactly once with '
                'your complete answer. Do not write the answer as text.'
          : system,
      'output_config': {
        'effort': effort,
        if (!web) 'format': {'type': 'json_schema', 'schema': schema},
      },
      if (web)
        'tools': [
          {
            'type': _haiku ? 'web_search_20250305' : 'web_search_20260209',
            'name': 'web_search',
            'max_uses': searches,
          },
          {
            'type': _haiku ? 'web_fetch_20250910' : 'web_fetch_20260209',
            'name': 'web_fetch',
            'max_uses': searches,
          },
          {
            'name': 'submit',
            'description': 'Hand in the finished answer. Call once, at the end.',
            'input_schema': schema,
            'eager_input_streaming': true,
          },
        ],
      if (_fallbacks) 'fallbacks': 'default',
    };

    var usage = const AiUsage();
    final read = <Source>[];
    // pause_turn (the server's tool loop hit its limit) and a missing or
    // malformed submit each take another round; a few is plenty.
    for (var round = 0; round < 6; round++) {
      final reply = await _send({...body, 'messages': messages}, onProgress);
      usage += reply.usage;
      read.addAll(reply.fetched);
      switch (reply.stopReason) {
        case 'refusal':
          onUsage?.call(usage);
          throw AiException('Claude declined this request. Rephrase it or remove anything sensitive.');
        case 'max_tokens':
          onUsage?.call(usage);
          throw AiException('The answer was longer than allowed. Try again with less to cover.');
      }
      if (!web) {
        onUsage?.call(usage);
        final text = reply.content.where((b) => b['type'] == 'text').map((b) => str(b['text'])).join();
        final data = _parse(text, schema);
        return AiResult(data, sources: _sources(data, read), usage: usage);
      }
      messages.add({'role': 'assistant', 'content': reply.content});
      if (reply.stopReason == 'pause_turn') continue;
      final submit = reply.content.where((b) => b['type'] == 'tool_use' && b['name'] == 'submit').firstOrNull;
      if (submit == null) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Call the submit tool now with your complete answer.'},
          ],
        });
        continue;
      }
      final input = submit['input'];
      final problem = reply.broken.contains(submit['id'])
          ? 'the answer was cut off or not valid JSON'
          : violation(schema, obj(input));
      if (problem == null) {
        onUsage?.call(usage);
        final data = obj(input);
        return AiResult(data, sources: _sources(data, read), usage: usage);
      }
      messages.add({
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': submit['id'],
            'is_error': true,
            'content': 'Not accepted: $problem. Call submit again with the complete answer in the schema.',
          },
        ],
      });
    }
    onUsage?.call(usage);
    throw AiException('Claude did not finish the answer. Try again.', retryable: true);
  }

  Json _parse(String text, Json schema) {
    try {
      final v = jsonDecode(text);
      final problem = violation(schema, v);
      if (problem == null && v is Map) return v.cast<String, Object?>();
    } on FormatException {
      // Reported below.
    }
    throw AiException('Claude answered in an unexpected form. Try again.', retryable: true);
  }

  List<Source> _sources(Json data, List<Source> read) {
    final seen = <String>{};
    return [
      for (final s in [
        for (final o in objs(data['sources'])) (title: str(o['title']), url: str(o['url'])),
        ...read,
      ])
        if (s.url.startsWith('http') && seen.add(s.url)) s,
    ];
  }

  /// One streamed request, retried on rate limits, overload and dropped
  /// connections.
  Future<_Reply> _send(Json body, void Function(String)? onProgress) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _stream(body, onProgress);
      } on AiException catch (e) {
        if (!e.retryable || attempt >= 3) rethrow;
        onProgress?.call('Busy, trying again…');
        await Future<void>.delayed(Duration(seconds: 2 << attempt));
      }
    }
  }

  Future<_Reply> _stream(Json body, void Function(String)? onProgress) async {
    final request = http.Request('POST', endpoint)
      ..headers.addAll({
        'content-type': 'application/json',
        'x-api-key': apiKey.trim(),
        'anthropic-version': _version,
        if (_fallbacks) 'anthropic-beta': 'server-side-fallback-2026-07-01',
      })
      ..body = jsonEncode({...body, 'stream': true});
    final http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw AiException('Claude did not answer in time.', retryable: true);
    } on SocketException {
      throw AiException('No connection to Claude. Check the internet connection.', retryable: true);
    } on http.ClientException catch (e) {
      throw AiException('No connection to Claude: ${e.message}', retryable: true);
    }
    if (response.statusCode != 200) {
      final text = await response.stream.bytesToString();
      throw _httpError(response.statusCode, text);
    }

    final reply = _Reply();
    final blocks = <int, Json>{};
    final partial = <int, StringBuffer>{};
    String? event;
    final data = StringBuffer();

    void dispatch() {
      if (data.isEmpty) return;
      final e = obj(jsonDecode(data.toString()));
      data.clear();
      switch (event ?? e['type']) {
        case 'message_start':
          reply.addUsage(obj(obj(e['message'])['usage']), model);
        case 'content_block_start':
          final i = intOf(e['index']) ?? 0;
          blocks[i] = {...obj(e['content_block'])};
          final b = blocks[i]!;
          if (b['type'] == 'web_fetch_tool_result') {
            final r = obj(b['content']);
            final url = str(r['url']);
            if (url.isNotEmpty) reply.fetched.add((title: str(obj(r['content'])['title']), url: url));
          }
          if (b['type'] == 'text' && onProgress != null) onProgress('Writing…');
        case 'content_block_delta':
          final i = intOf(e['index']) ?? 0;
          final b = blocks[i];
          if (b == null) return;
          final d = obj(e['delta']);
          switch (d['type']) {
            case 'text_delta':
              b['text'] = '${b['text'] ?? ''}${d['text'] ?? ''}';
            case 'input_json_delta':
              (partial[i] ??= StringBuffer()).write(d['partial_json'] ?? '');
            case 'thinking_delta':
              b['thinking'] = '${b['thinking'] ?? ''}${d['thinking'] ?? ''}';
            case 'signature_delta':
              b['signature'] = d['signature'];
            case 'citations_delta':
              b['citations'] = [...?(b['citations'] as List?), d['citation']];
          }
        case 'content_block_stop':
          final i = intOf(e['index']) ?? 0;
          final b = blocks[i];
          final json = partial.remove(i)?.toString();
          if (b == null || json == null) return;
          try {
            b['input'] = json.trim().isEmpty ? <String, Object?>{} : jsonDecode(json);
          } on FormatException {
            // Streamed input is not checked by the API and can be cut off.
            // The block goes back as {} so the next request stays valid.
            b['input'] = <String, Object?>{};
            reply.broken.add(str(b['id']));
          }
          if (onProgress != null && b['type'] == 'server_tool_use') {
            final input = obj(b['input']);
            if (b['name'] == 'web_search') onProgress('Searching: ${str(input['query'])}');
            if (b['name'] == 'web_fetch') {
              onProgress('Reading ${Uri.tryParse(str(input['url']))?.host ?? 'a page'}');
            }
          }
          if (onProgress != null && b['type'] == 'tool_use') onProgress('Writing up…');
        case 'message_delta':
          final d = obj(e['delta']);
          reply.stopReason = str(d['stop_reason']);
          reply.addUsage(obj(e['usage']), model);
        case 'error':
          final err = obj(e['error']);
          final type = str(err['type']);
          throw AiException(
            type == 'overloaded_error' ? 'Claude is busy.' : 'Claude stopped: ${str(err['message'])}',
            retryable: type == 'overloaded_error' || type == 'api_error',
          );
      }
    }

    try {
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              // Pings arrive every few seconds; this long without one is a dead line.
              .timeout(const Duration(seconds: 150))) {
        if (line.isEmpty) {
          dispatch();
          event = null;
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trimLeft());
        }
      }
      dispatch();
    } on TimeoutException {
      throw AiException('The connection to Claude went quiet.', retryable: true);
    } on SocketException {
      throw AiException('The connection to Claude dropped.', retryable: true);
    } on http.ClientException {
      throw AiException('The connection to Claude dropped.', retryable: true);
    }
    reply.content = [for (final i in blocks.keys.toList()..sort()) blocks[i]!];
    return reply;
  }

  AiException _httpError(int status, String body) {
    final err = obj(decodeObject(body)['error']);
    final detail = str(err['message']);
    return switch (status) {
      401 => AiException('Claude rejected the API key. Check it in Settings.'),
      403 => AiException('This API key may not use $model. $detail'),
      400 when detail.toLowerCase().contains('credit') => AiException(
        'The Claude account is out of credit. Top it up in the Claude Console.',
      ),
      400 => AiException('Claude could not take this request: $detail'),
      404 => AiException('Model $model is not available to this key. Choose another in Settings.'),
      413 => AiException('That is too much to send at once. Try a shorter CV or description.'),
      429 => AiException('Too many requests to Claude just now.', retryable: true),
      529 || >= 500 => AiException('Claude is busy.', retryable: true),
      _ => AiException('Claude answered with error $status. $detail'),
    };
  }
}

class _Reply {
  List<Json> content = const [];
  String stopReason = '';
  final fetched = <Source>[];

  /// Ids of tool calls whose streamed input was not valid JSON.
  final broken = <String>{};
  var usage = const AiUsage();

  /// Streamed usage counts are cumulative, so the latest of each wins.
  int _in = 0, _out = 0, _searches = 0;

  void addUsage(Json u, String model) {
    if (u.isEmpty) return;
    _in = [
      _in,
      (intOf(u['input_tokens']) ?? 0) +
          (intOf(u['cache_read_input_tokens']) ?? 0) +
          (intOf(u['cache_creation_input_tokens']) ?? 0),
    ].reduce((a, b) => a > b ? a : b);
    _out = [_out, intOf(u['output_tokens']) ?? 0].reduce((a, b) => a > b ? a : b);
    _searches = [
      _searches,
      intOf(obj(u['server_tool_use'])['web_search_requests']) ?? 0,
    ].reduce((a, b) => a > b ? a : b);
    final (pin, pout) = _prices[model] ?? _prices[defaultModel]!;
    usage = AiUsage(
      input: _in,
      output: _out,
      searches: _searches,
      dollars: _in / 1e6 * pin + _out / 1e6 * pout + _searches * _perSearch,
    );
  }
}
