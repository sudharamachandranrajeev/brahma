import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai.dart';
import 'json.dart';
import 'schema.dart';

/// US dollars per million input and output tokens on a paid key. The free
/// tier costs nothing, and the first 5,000 searches a month are free on
/// either, so searches are not priced.
const _prices = {'gemini-3.8-flash': (0.75, 3.75), 'gemini-3.5-flash-lite': (0.30, 2.50)};

/// Where the user creates a free key: sign in with a Google account and
/// press Create API key.
const geminiKeyPage = 'https://aistudio.google.com/apikey';

/// Calls the Gemini Interactions API over HTTP with the user's own key from
/// Google AI Studio. Every answer is JSON in the given schema, also when it
/// researches with Google Search and URL context first (structured outputs
/// with tools need a Gemini 3 or newer model). Nothing is stored on Google's
/// side between requests.
class Gemini implements Ai {
  Gemini({required this.apiKey, required this.model, http.Client? client, this.onUsage})
    : _http = client ?? http.Client();

  final String apiKey;
  @override
  final String model;
  final http.Client _http;

  /// Told about every request's usage (the spend counter in Settings).
  final void Function(AiUsage usage)? onUsage;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  static final endpoint = Uri.parse('$_base/interactions');

  /// Checks the key works, with a free request (the model list). Throws an [AiException] saying what is wrong.
  Future<void> check() async {
    final http.Response response;
    try {
      response = await _http
          .get(Uri.parse('$_base/models?pageSize=1'), headers: {'x-goog-api-key': apiKey.trim()})
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw AiException('Gemini did not answer in time.');
    } on SocketException {
      throw AiException('No connection to Gemini. Check the internet connection.');
    } on http.ClientException catch (e) {
      throw AiException('No connection to Gemini: ${e.message}');
    }
    if (response.statusCode != 200) throw _httpError(response.statusCode, response.body);
  }

  /// Gemini has no limit on searches per request, so [searches] is unused.
  @override
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
    if (apiKey.trim().isEmpty) throw AiException(needsAiKey);
    final body = <String, Object?>{
      'model': model,
      'system_instruction': web
          ? '$system\n\nResearch with Google Search and read the pages you need before you answer.'
          : system,
      'input': [for (final b in content) _content(b)],
      'response_format': {'type': 'text', 'mime_type': 'application/json', 'schema': schema},
      if (web)
        'tools': [
          {'type': 'google_search'},
          {'type': 'url_context'},
        ],
      'generation_config': {'thinking_level': effort, 'max_output_tokens': maxTokens},
      'store': false,
    };

    var usage = const AiUsage();
    // The schema is enforced while decoding, but a reply can still come back
    // empty or cut off; a few rounds is plenty.
    for (var round = 0; round < 3; round++) {
      onProgress?.call(web ? 'Researching with Google Search…' : 'Thinking…');
      final reply = obj(await _send(body, onProgress));
      usage += _usage(obj(reply['usage']));
      final errors = objs(reply['errors']);
      if (str(reply['status']) == 'failed') {
        onUsage?.call(usage);
        throw AiException(
          'Gemini stopped: ${errors.map((e) => str(e['message'])).where((m) => m.isNotEmpty).join(' ')}',
        );
      }
      if (str(reply['status']) == 'incomplete') {
        onUsage?.call(usage);
        throw AiException('The answer was longer than allowed. Try again with less to cover.');
      }
      final texts = [
        for (final step in objs(reply['steps']))
          if (step['type'] == 'model_output')
            for (final c in objs(step['content']))
              if (c['type'] == 'text') c,
      ];
      final read = <Source>[
        for (final t in texts)
          for (final a in objs(t['annotations']))
            if (a['type'] == 'url_citation') (title: str(a['title']), url: str(a['url'])),
      ];
      try {
        final data = jsonDecode(texts.map((t) => str(t['text'])).join());
        if (data is Map && violation(schema, data) == null) {
          onUsage?.call(usage);
          final json = data.cast<String, Object?>();
          return AiResult(json, sources: mergeSources(json, read), usage: usage);
        }
      } on FormatException {
        // Asked again below.
      }
    }
    onUsage?.call(usage);
    throw AiException('Gemini answered in an unexpected form. Try again.', retryable: true);
  }

  /// A Claude-format content block as an Interactions content object.
  static Json _content(Json block) => switch (block['type']) {
    'document' => {
      'type': 'document',
      'data': str(obj(block['source'])['data']),
      'mime_type': str(obj(block['source'])['media_type']),
    },
    _ => {'type': 'text', 'text': str(block['text'])},
  };

  AiUsage _usage(Json u) {
    if (u.isEmpty) return const AiUsage();
    // Tool output (pages read through URL context) is billed as input and
    // thinking as output.
    final input = (intOf(u['total_input_tokens']) ?? 0) + (intOf(u['total_tool_use_tokens']) ?? 0);
    final output = (intOf(u['total_output_tokens']) ?? 0) + (intOf(u['total_thought_tokens']) ?? 0);
    final searches = objs(u['grounding_tool_count'])
        .where((g) => str(g['type']).contains('search'))
        .fold(0, (n, g) => n + (intOf(g['count']) ?? 0));
    final (pin, pout) = _prices[model] ?? _prices[AiProvider.gemini.defaultModel]!;
    return AiUsage(
      input: input,
      output: output,
      searches: searches,
      dollars: input / 1e6 * pin + output / 1e6 * pout,
    );
  }

  /// One request, retried on rate limits, overload and dropped connections.
  Future<Object?> _send(Json body, void Function(String)? onProgress) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _post(body);
      } on AiException catch (e) {
        if (!e.retryable || attempt >= 3) rethrow;
        onProgress?.call('Busy, trying again…');
        await Future<void>.delayed(Duration(seconds: 2 << attempt));
      }
    }
  }

  Future<Object?> _post(Json body) async {
    final http.Response response;
    try {
      // Research with thinking can take minutes, and nothing streams back
      // in the meantime.
      response = await _http
          .post(
            endpoint,
            headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey.trim()},
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw AiException('Gemini did not answer in time.', retryable: true);
    } on SocketException {
      throw AiException('No connection to Gemini. Check the internet connection.', retryable: true);
    } on http.ClientException catch (e) {
      throw AiException('No connection to Gemini: ${e.message}', retryable: true);
    }
    if (response.statusCode != 200) throw _httpError(response.statusCode, response.body);
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw AiException('Gemini sent a reply that could not be read.', retryable: true);
    }
  }

  AiException _httpError(int status, String body) {
    final err = obj(decodeObject(body)['error']);
    final detail = str(err['message']);
    final all = body.toLowerCase();
    return switch (status) {
      400 when all.contains('api_key_invalid') || all.contains('api key not valid') => AiException(
        'Google rejected the Gemini key. Check it in Settings.',
      ),
      400 when all.contains('location is not supported') => AiException(
        'Gemini\'s free tier is not offered in your country. Turn on billing for the key in Google AI '
        'Studio, or use a Claude key.',
      ),
      400 => AiException('Gemini could not take this request: $detail'),
      401 || 403 => AiException('This Gemini key may not be used here. $detail'),
      404 => AiException('Model $model is not available to this key. Choose another in Settings.'),
      413 => AiException('That is too much to send at once. Try a shorter CV or description.'),
      429 when all.contains('perday') => AiException(
        'The key\'s daily Gemini limit is used up. It resets at midnight Pacific time, or turn on '
        'billing for the key in Google AI Studio.',
      ),
      429 => AiException('Too many requests to Gemini just now.', retryable: true),
      >= 500 => AiException('Gemini is busy.', retryable: true),
      _ => AiException('Gemini answered with error $status. $detail'),
    };
  }
}
