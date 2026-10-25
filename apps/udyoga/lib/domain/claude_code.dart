import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai.dart';
import 'json.dart';
import 'schema.dart';

/// How long Udyoga may use the Claude subscription before the user has to
/// allow it again.
const claudeCodeGrantLength = Duration(hours: 24);

const claudeCodeExpired =
    'Udyoga\'s 24-hour access to your Claude subscription has ended. Reconnect it in Settings.';

const claudeCodeInstallPage = 'https://code.claude.com/docs/en/setup';

/// The user's permission for Udyoga to run this device's Claude Code: when
/// it was given, the account Claude Code was signed in to then, and where
/// Claude Code is. It lapses after [claudeCodeGrantLength]; Udyoga then asks
/// again at start. Kept on this device only.
class ClaudeCodeGrant {
  const ClaudeCodeGrant({required this.at, required this.account, required this.exe});

  factory ClaudeCodeGrant.fromJson(Json j) => ClaudeCodeGrant(
    at: DateTime.tryParse(str(j['at']))?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    account: str(j['account']),
    exe: str(j['exe']),
  );

  final DateTime at;
  final String account;
  final String exe;

  DateTime get expires => at.add(claudeCodeGrantLength);
  bool activeAt(DateTime now) => now.isBefore(expires);

  Json toJson() => {'at': at.toUtc().toIso8601String(), 'account': account, 'exe': exe};
}

/// What `claude auth status` reports.
typedef ClaudeAuth = ({bool loggedIn, bool subscription, String account});

typedef StartProcess = Future<Process> Function(
  String exe,
  List<String> args, {
  String? workingDirectory,
  bool runInShell,
});

Future<Process> _startProcess(
  String exe,
  List<String> args, {
  String? workingDirectory,
  bool runInShell = false,
}) => Process.start(exe, args, workingDirectory: workingDirectory, runInShell: runInShell);

/// The user's own, unmodified Claude Code, which Udyoga runs to use their
/// Claude subscription. Anthropic's terms do not let apps sign in to
/// claude.ai themselves or hold its tokens, so Udyoga never does: Claude Code
/// signs in through Anthropic's own flow and keeps its credentials to itself.
abstract final class ClaudeCodeCli {
  /// The desktop platforms Claude Code runs on that Udyoga ships for.
  static bool get supported => Platform.isLinux || Platform.isWindows;

  /// Where Claude Code is installed, or null. Apps started from a menu often
  /// get a shorter PATH than a terminal, so the usual install places are
  /// tried too.
  static String? locate({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final windows = Platform.isWindows;
    final home = env[windows ? 'USERPROFILE' : 'HOME'] ?? '';
    final sep = windows ? r'\' : '/';
    final names = windows ? const ['claude.exe', 'claude.cmd'] : const ['claude'];
    final dirs = [
      ...(env['PATH'] ?? env['Path'] ?? '').split(windows ? ';' : ':'),
      if (windows) ...[
        '$home\\.local\\bin',
        if (env['APPDATA'] case final appData?) '$appData\\npm',
      ] else ...[
        '$home/.local/bin',
        '$home/.claude/local',
        '$home/.local/share/mise/shims',
        '$home/.npm-global/bin',
        '/usr/local/bin',
        '/usr/bin',
      ],
    ];
    for (final d in dirs.where((d) => d.isNotEmpty)) {
      for (final n in names) {
        final f = File('$d$sep$n');
        if (f.existsSync()) return f.path;
      }
    }
    return null;
  }

  /// Runs `claude auth status`.
  static Future<ClaudeAuth> status(String exe, {StartProcess start = _startProcess}) async {
    final p = await start(exe, const ['auth', 'status'], runInShell: _shell(exe));
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
      if (code != 0) throw AiException('Claude Code could not check its sign-in: ${_lastLine(await err)}');
      return (loggedIn: false, subscription: false, account: '');
    }
    return (
      loggedIn: j['loggedIn'] == true,
      subscription: str(j['authMethod']) == 'claude.ai',
      account: str(j['email']).ifEmpty(str(j['orgName'])),
    );
  }

  /// The command that signs Claude Code in to a Claude subscription.
  static String signInCommand(String exe) => '"$exe" auth login --claudeai';

  /// Opens a terminal running Claude Code's own sign-in. False when no
  /// terminal could be started (the user then runs [signInCommand] by hand).
  static Future<bool> openSignIn(String exe) async {
    final login = [exe, 'auth', 'login', '--claudeai'];
    final tries = Platform.isWindows
        ? [
            ['cmd', '/c', 'start', 'Claude Code sign-in', 'cmd', '/k', ...login],
          ]
        : [
            ['xdg-terminal-exec', ...login],
            ['x-terminal-emulator', '-e', ...login],
            ['gnome-terminal', '--', ...login],
            ['konsole', '-e', ...login],
            ['xterm', '-e', ...login],
          ];
    for (final t in tries) {
      try {
        await Process.start(t.first, t.sublist(1), mode: ProcessStartMode.detached);
        return true;
      } on ProcessException {
        continue;
      }
    }
    return false;
  }

  static bool _shell(String exe) => Platform.isWindows && !exe.toLowerCase().endsWith('.exe');
}

/// Asks Claude through the user's Claude Code in print mode (`claude -p`),
/// so requests count against their own subscription. Every answer is JSON
/// checked against the schema. Claude Code runs in an empty folder with only
/// the tools a request needs, without the user's settings, hooks or MCP
/// servers, and keeps no session.
class ClaudeCode implements Ai {
  ClaudeCode({required this.grant, required this.model, StartProcess? start, DateTime Function()? now})
    : _start = start ?? _startProcess,
      _now = now ?? DateTime.now;

  final ClaudeCodeGrant grant;

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
    if (!grant.activeAt(_now())) throw AiException(claudeCodeExpired);
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
        runInShell: ClaudeCodeCli._shell(grant.exe),
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
      final why = _lastLine(stderr);
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

String _lastLine(String s) => s.trim().split('\n').last.trim();

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
