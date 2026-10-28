import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai.dart';
import 'json.dart';
import 'schema.dart';
import 'subscription.dart';

const claudeCodeInstallPage = 'https://code.claude.com/docs/en/setup';

/// The user's own Claude Code, which Udyoga runs to use their Claude
/// subscription.
class ClaudeCodeCli extends SubscriptionCli {
  const ClaudeCodeCli();

  @override
  String get app => 'Claude Code';
  @override
  String get plan => 'Claude';
  @override
  String get maker => 'Anthropic';
  @override
  String get plans => 'Claude Pro or Max';
  @override
  String get installPage => claudeCodeInstallPage;
  @override
  String get command => 'claude';
  @override
  List<String> get signInArgs => const ['auth', 'login', '--claudeai'];

  /// Runs `claude auth status`.
  @override
  Future<CliAuth> status(String exe, {StartProcess start = startProcess}) async {
    final p = await start(exe, const ['auth', 'status'], runInShell: runsInShell(exe));
    p.stdin.close().ignore();
    final out = p.stdout.transform(utf8.decoder).join();
    final err = p.stderr.transform(utf8.decoder).join();
    final code = await p.exitCode.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        p.kill();
        throw AiException('Claude Code did not answer in time.');
      },
    );
    final j = decodeObject(await out);
    if (j.isEmpty) {
      if (code != 0) throw AiException('Claude Code could not check its sign-in: ${lastLine(await err)}');
      return (loggedIn: false, subscription: false, account: '');
    }
    return (
      loggedIn: j['loggedIn'] == true,
      subscription: str(j['authMethod']) == 'claude.ai',
      account: str(j['email']).ifEmpty(str(j['orgName'])),
    );
  }
}

/// Asks Claude through the user's Claude Code in print mode (`claude -p`),
/// so requests count against their own subscription. Every answer is JSON
/// checked against the schema. Claude Code runs in an empty folder with only
/// the tools a request needs, without the user's settings, hooks or MCP
/// servers, and keeps no session.
class ClaudeCode implements Ai {
  ClaudeCode({required this.grant, required this.model, StartProcess? start, DateTime Function()? now})
    : _start = start ?? startProcess,
      _now = now ?? DateTime.now;

  final SubscriptionGrant grant;

  /// With [ClaudeCodeModels.prefix].
  @override
  final String model;
  final StartProcess _start;
  final DateTime Function() _now;

  static const _limit = Duration(minutes: 15);

  /// The arguments for one request.
  List<String> arguments({
    required String system,
    required Json schema,
    required List<String> tools,
    required String effort,
  }) => [
    '-p',
    '--output-format',
    'stream-json',
    '--verbose',
    '--model',
    model.replaceFirst(ClaudeCodeModels.prefix, ''),
    '--effort',
    effort,
    '--system-prompt',
    system,
    '--json-schema',
    jsonEncode(schema),
    '--tools',
    tools.isEmpty ? '' : tools.join(','),
    if (tools.isNotEmpty) ...['--allowedTools', ...tools],
    '--no-session-persistence',
    '--strict-mcp-config',
    // Project settings only, and the folder is empty: none of the user's
    // own hooks, plugins or permissions apply.
    '--setting-sources',
    'project',
  ];

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
    if (!grant.activeAt(_now())) throw AiException(subscriptionExpired('Claude'));
    final dir = await Directory.systemTemp.createTemp('udyoga-claude-');
    try {
      final prompt = StringBuffer();
      var documents = 0;
      for (final b in content) {
        switch (b['type']) {
          case 'text':
            prompt.writeln(str(b['text']));
          case 'document':
            final name = 'document-${++documents}.pdf';
            await File('${dir.path}${Platform.pathSeparator}$name')
                .writeAsBytes(base64Decode(str(obj(b['source'])['data'])));
            prompt.writeln('<document file="$name">Read this PDF with the Read tool.</document>');
        }
      }
      final tools = [
        if (documents > 0) 'Read',
        if (web) ...['WebSearch', 'WebFetch'],
      ];
      final p = await _start(
        grant.exe,
        arguments(
          system: web
              ? '$system\n\nResearch with WebSearch and WebFetch as needed (about $searches searches at most), '
                    'then give your complete answer in the required structured form.'
              : system,
          schema: schema,
          tools: tools,
          effort: effort,
        ),
        workingDirectory: dir.path,
        runInShell: runsInShell(grant.exe),
      );
      p.stdin.write(prompt.toString());
      await p.stdin.close();
      final err = p.stderr.transform(utf8.decoder).join();
      final read = <Source>[];
      Json? result;
      await for (final line
          in p.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(
                _limit,
                onTimeout: (sink) {
                  p.kill();
                  sink.addError(AiException('Claude Code took too long. Try again.', retryable: true));
                  sink.close();
                },
              )) {
        final e = decodeObject(line);
        switch (e['type']) {
          case 'assistant':
            for (final b in objs(obj(e['message'])['content'])) {
              if (b['type'] == 'text') onProgress?.call('Writing…');
              if (b['type'] != 'tool_use') continue;
              final input = obj(b['input']);
              switch (b['name']) {
                case 'WebSearch':
                  onProgress?.call('Searching: ${str(input['query'])}');
                case 'WebFetch':
                  final url = str(input['url']);
                  final host = Uri.tryParse(url)?.host ?? '';
                  onProgress?.call('Reading ${host.ifEmpty('a page')}');
                  if (url.startsWith('http')) read.add((title: host, url: url));
                case 'Read':
                  onProgress?.call('Reading the document…');
                case 'StructuredOutput':
                  onProgress?.call('Writing up…');
              }
            }
          case 'result':
            result = e;
        }
      }
      await p.exitCode;
      return _answer(result, schema, read, await err);
    } finally {
      dir.delete(recursive: true).ignore();
    }
  }

  AiResult _answer(Json? result, Json schema, List<Source> read, String stderr) {
    if (result == null) {
      final why = lastLine(stderr);
      if (RegExp(r'log ?in|sign ?in|auth', caseSensitive: false).hasMatch(why)) {
        throw AiException('Claude Code is not signed in. Reconnect your subscription in Settings.');
      }
      throw AiException(
        why.isEmpty ? 'Claude Code stopped without an answer. Try again.' : 'Claude Code stopped: $why',
        retryable: true,
      );
    }
    if (result['is_error'] == true || str(result['subtype']) != 'success') {
      final said = str(result['result']).ifEmpty(str(result['subtype']));
      if (RegExp(r'limit', caseSensitive: false).hasMatch(said)) {
        throw AiException('Your Claude plan\'s usage limit is reached for now. $said'.trim());
      }
      throw AiException('Claude Code could not finish: $said', retryable: true);
    }
    final data = result['structured_output'];
    if (data is! Map || violation(schema, data) != null) {
      throw AiException('Claude answered in an unexpected form. Try again.', retryable: true);
    }
    final j = data.cast<String, Object?>();
    return AiResult(j, sources: mergeSources(j, read));
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
