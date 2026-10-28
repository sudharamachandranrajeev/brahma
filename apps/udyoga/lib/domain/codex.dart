import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai.dart';
import 'json.dart';
import 'schema.dart';
import 'subscription.dart';

const codexInstallPage = 'https://developers.openai.com/codex/cli';

/// The user's own Codex, OpenAI's coding agent, which Udyoga runs to use
/// their ChatGPT subscription.
class CodexCli extends SubscriptionCli {
  const CodexCli();

  @override
  String get app => 'Codex';
  @override
  String get plan => 'ChatGPT';
  @override
  String get maker => 'OpenAI';
  @override
  String get plans => 'ChatGPT Plus, Pro, Business or Enterprise';
  @override
  String get installPage => codexInstallPage;
  @override
  String get command => 'codex';
  @override
  List<String> get signInArgs => const ['login'];

  /// Runs `codex login status`, which says how Codex is signed in ("Logged
  /// in using ChatGPT") and exits with 0 only when it is. Codex does not say
  /// which account.
  @override
  Future<CliAuth> status(String exe, {StartProcess start = startProcess}) async {
    final p = await start(exe, const ['login', 'status'], runInShell: runsInShell(exe));
    p.stdin.close().ignore();
    final out = p.stdout.transform(utf8.decoder).join();
    final err = p.stderr.transform(utf8.decoder).join();
    final code = await p.exitCode.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        p.kill();
        throw AiException('Codex did not answer in time.');
      },
    );
    final said = '${await out}\n${await err}';
    final loggedIn = code == 0 && RegExp('logged in', caseSensitive: false).hasMatch(said);
    return (
      loggedIn: loggedIn,
      subscription: loggedIn && RegExp('chatgpt', caseSensitive: false).hasMatch(said),
      account: '',
    );
  }
}

/// Asks ChatGPT through the user's Codex in non-interactive mode (`codex
/// exec`), so requests count against their own plan. Every answer is JSON
/// checked against the schema. Codex runs in an empty folder in its
/// read-only sandbox, without the user's config or MCP servers, and keeps no
/// session.
class Codex implements Ai {
  Codex({required this.grant, required this.model, StartProcess? start, DateTime Function()? now})
    : _start = start ?? startProcess,
      _now = now ?? DateTime.now;

  final SubscriptionGrant grant;

  /// With [CodexModels.prefix].
  @override
  final String model;
  final StartProcess _start;
  final DateTime Function() _now;

  static const _limit = Duration(minutes: 15);

  /// The arguments for one request; the prompt comes on stdin.
  List<String> arguments({required String schemaFile, required String effort, required bool web}) => [
    'exec',
    '--json',
    '--color',
    'never',
    if (model != CodexModels.standard) ...['--model', model.replaceFirst(CodexModels.prefix, '')],
    '--output-schema',
    schemaFile,
    '--sandbox',
    'read-only',
    '--skip-git-repo-check',
    '--ephemeral',
    // None of the user's own config, profiles or MCP servers apply; the
    // sign-in still does.
    '--ignore-user-config',
    // Bare values: Codex reads -c values as TOML and falls back to a plain
    // string, and quotes do not survive the Windows shell.
    '-c',
    'model_reasoning_effort=$effort',
    '-c',
    'web_search=${web ? 'live' : 'disabled'}',
    '-',
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
    if (!grant.activeAt(_now())) throw AiException(subscriptionExpired('ChatGPT'));
    // Codex takes text and images only.
    if (content.any((b) => b['type'] == 'document')) {
      throw AiException(
        'The ChatGPT subscription cannot read PDFs in Udyoga. Paste the text instead, or choose another model '
        'in Settings.',
      );
    }
    final dir = await Directory.systemTemp.createTemp('udyoga-codex-');
    try {
      final schemaFile = '${dir.path}${Platform.pathSeparator}schema.json';
      await File(schemaFile).writeAsString(jsonEncode(schema));
      // Codex has no system prompt of its own to replace, so the instructions
      // lead the prompt.
      final prompt = StringBuffer()
        ..writeln('<instructions>')
        ..writeln(system)
        ..writeln(
          web
              ? 'Research with web search as needed (about $searches searches at most), then give your complete '
                    'answer in the required structured form.'
              : 'Answer from what is given here; do not run commands. Give your answer in the required structured '
                    'form.',
        )
        ..writeln('</instructions>')
        ..writeln();
      for (final b in content) {
        if (b['type'] == 'text') prompt.writeln(str(b['text']));
      }
      final p = await _start(
        grant.exe,
        arguments(schemaFile: schemaFile, effort: effort, web: web),
        workingDirectory: dir.path,
        runInShell: runsInShell(grant.exe),
      );
      p.stdin.write(prompt.toString());
      await p.stdin.close();
      final err = p.stderr.transform(utf8.decoder).join();
      final searched = <String>{};
      String? answer;
      var failure = '';
      await for (final line
          in p.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(
                _limit,
                onTimeout: (sink) {
                  p.kill();
                  sink.addError(AiException('Codex took too long. Try again.', retryable: true));
                  sink.close();
                },
              )) {
        final e = decodeObject(line);
        final item = obj(e['item']);
        switch (str(e['type'])) {
          case 'item.started' || 'item.updated' || 'item.completed':
            switch (str(item['type'])) {
              case 'web_search':
                final q = str(item['query']);
                if (q.isNotEmpty && searched.add(q)) onProgress?.call('Searching: $q');
              case 'reasoning':
                onProgress?.call('Thinking…');
              case 'agent_message':
                onProgress?.call('Writing up…');
                if (e['type'] == 'item.completed') answer = str(item['text']);
            }
          case 'turn.failed':
            failure = str(obj(e['error'])['message']);
          case 'error':
            failure = str(e['message']);
        }
      }
      await p.exitCode;
      return _answer(answer, failure, schema, await err);
    } finally {
      dir.delete(recursive: true).ignore();
    }
  }

  AiResult _answer(String? answer, String failure, Json schema, String stderr) {
    if (answer == null) {
      final why = failure.isEmpty ? lastLine(stderr) : failure;
      if (RegExp(r'log ?in|sign ?in|auth|401', caseSensitive: false).hasMatch(why)) {
        throw AiException('Codex is not signed in. Reconnect your ChatGPT subscription in Settings.');
      }
      if (RegExp(r'usage limit|rate limit|429', caseSensitive: false).hasMatch(why)) {
        throw AiException('Your ChatGPT plan\'s usage limit is reached for now. $why'.trim());
      }
      throw AiException(
        why.isEmpty ? 'Codex stopped without an answer. Try again.' : 'Codex stopped: $why',
        retryable: true,
      );
    }
    final data = decodeObject(answer);
    if (data.isEmpty || violation(schema, data) != null) {
      throw AiException('ChatGPT answered in an unexpected form. Try again.', retryable: true);
    }
    return AiResult(data, sources: mergeSources(data, const []));
  }
}
