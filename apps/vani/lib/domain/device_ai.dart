import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brahma_core/brahma_core.dart' show UserFacingError;
import 'package:http/http.dart' as http;

import 'models.dart' show Json, obj, objs, str, strs;

/// What the hub asks this device's AI when it answers 409 `needsAi`
/// (hub/README.md, "AI on your device"): one structured answer.
class DeviceRequest {
  const DeviceRequest({
    required this.system,
    required this.prompt,
    this.images = const [],
    this.schema = const {},
    this.effort = 'low',
  });

  final String system, prompt, effort;

  /// Short-lived signed links to the hub's own media.
  final List<String> images;
  final Json schema;

  factory DeviceRequest.fromJson(Json j) => DeviceRequest(
    system: str(j['system']),
    prompt: str(j['prompt']),
    images: strs(j['images']),
    schema: obj(j['schema']),
    effort: str(j['effort'], 'low'),
  );
}

/// Answers one [DeviceRequest] with JSON matching its schema.
typedef DeviceAnswer = Future<Object?> Function(DeviceRequest request);

class DeviceAiException implements Exception, UserFacingError {
  DeviceAiException(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

/// AI that runs on this computer: the user's own, unmodified command-line
/// tool signed in to their own plan, or Ollama. Vani never signs in to these
/// services itself or holds their tokens (Anthropic's terms forbid apps
/// doing that for claude.ai); each tool keeps its own sign-in.
enum DeviceAiTool {
  claude('Claude subscription (Claude Code)', 'claude', 'https://code.claude.com/docs/en/setup'),
  codex('ChatGPT plan (Codex CLI)', 'codex', 'https://developers.openai.com/codex/cli'),
  gemini('Google account (Gemini CLI)', 'gemini', 'https://github.com/google-gemini/gemini-cli'),
  ollama('Ollama on this computer', '', 'https://ollama.com/download');

  const DeviceAiTool(this.label, this.command, this.installPage);
  final String label, command, installPage;

  /// Whether this tool runs a program (Ollama is a local server instead).
  bool get cli => command.isNotEmpty;
}

/// This device's AI choice; device-only, never synced.
class DeviceAiChoice {
  const DeviceAiChoice({required this.tool, this.model = ''});

  static const localKey = 'vani.deviceAi';

  final DeviceAiTool tool;

  /// Empty = the tool's own default (Ollama needs one).
  final String model;

  static DeviceAiChoice? fromJson(Json j) {
    final tool = DeviceAiTool.values.where((t) => t.name == j['tool']).firstOrNull;
    return tool == null ? null : DeviceAiChoice(tool: tool, model: str(j['model']));
  }

  Json toJson() => {'tool': tool.name, 'model': model};
}

/// Whether this platform can run the AI tools (desktop only).
bool get deviceAiSupported => Platform.isLinux || Platform.isWindows;

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

const ollamaBase = 'http://127.0.0.1:11434';

/// Runs [DeviceRequest]s through the chosen tool.
class DeviceAi {
  DeviceAi(this.choice, {http.Client? client, StartProcess? start, Map<String, String>? environment})
    : _http = client ?? http.Client(),
      _start = start ?? _startProcess,
      _env = environment ?? Platform.environment;

  final DeviceAiChoice choice;
  final http.Client _http;
  final StartProcess _start;
  final Map<String, String> _env;

  static const _limit = Duration(minutes: 5);

  /// Where [tool]'s program is, or null. Apps started from a menu often get a
  /// shorter PATH than a terminal, so the usual install places are tried too.
  String? locate([DeviceAiTool? tool]) {
    final t = tool ?? choice.tool;
    if (!t.cli) return null;
    final windows = Platform.isWindows;
    final home = _env[windows ? 'USERPROFILE' : 'HOME'] ?? '';
    final sep = windows ? r'\' : '/';
    final names = windows ? ['${t.command}.exe', '${t.command}.cmd'] : [t.command];
    final dirs = [
      ...(_env['PATH'] ?? _env['Path'] ?? '').split(windows ? ';' : ':'),
      if (windows) ...[
        '$home\\.local\\bin',
        if (_env['APPDATA'] case final appData?) '$appData\\npm',
      ] else ...[
        '$home/.local/bin',
        if (t == DeviceAiTool.claude) '$home/.claude/local',
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

  String _exe() =>
      locate() ??
      (throw DeviceAiException(
        '${choice.tool.label} is not installed on this computer. Install it, then try again.',
      ));

  /// A line about the tool's state for Settings, e.g. who it is signed in as.
  /// Throws when it cannot be used.
  Future<String> check() async {
    if (choice.tool == DeviceAiTool.ollama) {
      final models = await ollamaModels();
      if (models.isEmpty) {
        throw DeviceAiException('Ollama is running but has no models. Run: ollama pull gemma3');
      }
      return 'Ollama is running with ${models.length} model${models.length == 1 ? '' : 's'}.';
    }
    final exe = _exe();
    switch (choice.tool) {
      case DeviceAiTool.claude:
        final out = await _run(exe, const ['auth', 'status']);
        final j = _decode(out.stdout);
        if (j['loggedIn'] != true) throw DeviceAiException('Claude Code is not signed in. Use Sign in.');
        if (str(j['authMethod']) != 'claude.ai') {
          return 'Claude Code is signed in with an API key, not a subscription; requests are billed to that key.';
        }
        return 'Signed in as ${str(j['email'], str(j['orgName'], 'your Claude account'))}.';
      case DeviceAiTool.codex:
        final out = await _run(exe, const ['login', 'status']);
        final said = '${out.stdout}\n${out.stderr}'.trim();
        if (out.code != 0 || !RegExp('logged in', caseSensitive: false).hasMatch(said)) {
          throw DeviceAiException('Codex is not signed in. Use Sign in.');
        }
        return said.split('\n').last.trim();
      case DeviceAiTool.gemini:
        final out = await _run(exe, const ['--version']);
        if (out.code != 0) throw DeviceAiException('Gemini CLI did not start: ${_lastLine(out.stderr)}');
        return 'Gemini CLI ${out.stdout.trim()}. It asks you to sign in with Google the first time.';
      case DeviceAiTool.ollama:
        throw StateError('handled above');
    }
  }

  /// The arguments that open the tool's own sign-in in a terminal.
  List<String> get signInArguments => switch (choice.tool) {
    DeviceAiTool.claude => const ['auth', 'login', '--claudeai'],
    DeviceAiTool.codex => const ['login'],
    DeviceAiTool.gemini || DeviceAiTool.ollama => const [],
  };

  /// Opens a terminal running the tool's own sign-in. False when no terminal
  /// could be started.
  Future<bool> openSignIn() async {
    final login = [_exe(), ...signInArguments];
    final tries = Platform.isWindows
        ? [
            ['cmd', '/c', 'start', 'Sign in', 'cmd', '/k', ...login],
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

  /// The models Ollama has pulled.
  Future<List<String>> ollamaModels() async {
    final http.Response res;
    try {
      res = await _http.get(Uri.parse('$ollamaBase/api/tags')).timeout(const Duration(seconds: 5));
    } on Exception {
      throw DeviceAiException('Ollama is not running on this computer. Start it, then try again.');
    }
    if (res.statusCode != 200) throw DeviceAiException('Ollama answered ${res.statusCode}.');
    return [for (final m in objs(_decode(res.body)['models'])) str(m['name'])]..sort();
  }

  /// One structured answer for the hub.
  Future<Object?> answer(DeviceRequest r) async {
    if (choice.tool == DeviceAiTool.ollama) return _ollama(r);
    final exe = _exe();
    final dir = await Directory.systemTemp.createTemp('vani-ai-');
    try {
      final images = [for (final (i, url) in r.images.indexed) await _download(url, dir, i + 1)];
      return switch (choice.tool) {
        DeviceAiTool.claude => await _claude(exe, dir, r, images),
        DeviceAiTool.codex => await _codex(exe, dir, r, images),
        _ => await _gemini(exe, dir, r, images),
      };
    } finally {
      dir.delete(recursive: true).ignore();
    }
  }

  /// `claude -p` in an empty folder, without the user's settings, hooks or
  /// MCP servers, keeping no session; only Read, and only for images.
  Future<Object?> _claude(String exe, Directory dir, DeviceRequest r, List<String> images) async {
    final out = await _run(
      exe,
      [
        '-p',
        '--output-format',
        'json',
        if (choice.model.isNotEmpty) ...['--model', choice.model],
        '--system-prompt',
        r.system,
        '--json-schema',
        jsonEncode(r.schema),
        '--tools',
        images.isEmpty ? '' : 'Read',
        if (images.isNotEmpty) ...['--allowedTools', 'Read'],
        '--no-session-persistence',
        '--strict-mcp-config',
        '--setting-sources',
        'project',
      ],
      dir: dir,
      input: [
        r.prompt,
        for (final f in images) '<image file="$f">Look at this image with the Read tool.</image>',
      ].join('\n'),
    );
    final j = _decode(out.stdout);
    if (j.isEmpty) throw _stopped('Claude Code', out);
    if (j['is_error'] == true || str(j['subtype']) != 'success') {
      final said = str(j['result'], str(j['subtype']));
      if (RegExp('limit', caseSensitive: false).hasMatch(said)) {
        throw DeviceAiException('Your Claude plan\'s usage limit is reached for now. $said');
      }
      throw DeviceAiException('Claude Code could not finish: $said');
    }
    return j['structured_output'];
  }

  /// `codex exec`, read-only and ephemeral, with the schema as a file.
  Future<Object?> _codex(String exe, Directory dir, DeviceRequest r, List<String> images) async {
    final schema = File('${dir.path}${Platform.pathSeparator}schema.json')
      ..writeAsStringSync(jsonEncode(r.schema));
    final answer = File('${dir.path}${Platform.pathSeparator}answer.json');
    final out = await _run(
      exe,
      [
        'exec',
        '--skip-git-repo-check',
        '--ephemeral',
        '--sandbox',
        'read-only',
        '--output-schema',
        schema.path,
        '-o',
        answer.path,
        if (choice.model.isNotEmpty) ...['-m', choice.model],
        for (final f in images) ...['-i', f],
        '-',
      ],
      dir: dir,
      input: '${r.system}\n\n${r.prompt}',
    );
    if (!answer.existsSync()) throw _stopped('Codex', out);
    return _parse(answer.readAsStringSync(), 'Codex');
  }

  /// `gemini -p` in plan (read-only) mode; the schema goes in the prompt and
  /// images as @file references, which Gemini CLI reads itself.
  Future<Object?> _gemini(String exe, Directory dir, DeviceRequest r, List<String> images) async {
    final out = await _run(
      exe,
      [
        '-p',
        [
          'Answer with only a JSON value matching this JSON schema, no other text:',
          jsonEncode(r.schema),
          for (final f in images) '@$f',
        ].join('\n'),
        '--output-format',
        'json',
        '--approval-mode',
        'plan',
        if (choice.model.isNotEmpty) ...['-m', choice.model],
      ],
      dir: dir,
      input: '${r.system}\n\n${r.prompt}',
    );
    final j = _decode(out.stdout);
    if (j['response'] is! String) {
      final error = str(obj(j['error'])['message']);
      if (error.isNotEmpty) throw DeviceAiException('Gemini CLI could not finish: $error');
      throw _stopped('Gemini CLI', out);
    }
    return _parse(str(j['response']), 'Gemini');
  }

  /// Ollama's chat API with the schema as `format`.
  Future<Object?> _ollama(DeviceRequest r) async {
    if (choice.model.isEmpty) throw DeviceAiException('Pick an Ollama model in Settings > AI.');
    final images = [for (final url in r.images) base64Encode(await _fetch(url))];
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$ollamaBase/api/chat'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'model': choice.model,
              'stream': false,
              'format': r.schema,
              'messages': [
                {'role': 'system', 'content': r.system},
                {'role': 'user', 'content': r.prompt, if (images.isNotEmpty) 'images': images},
              ],
            }),
          )
          .timeout(_limit);
    } on TimeoutException {
      throw DeviceAiException('Ollama took too long. Try a smaller model.');
    } on Exception {
      throw DeviceAiException('Ollama is not running on this computer. Start it, then try again.');
    }
    final j = _decode(res.body);
    if (res.statusCode != 200) {
      throw DeviceAiException('Ollama: ${str(j['error'], 'answered ${res.statusCode}')}');
    }
    return _parse(str(obj(j['message'])['content']), 'Ollama');
  }

  Future<List<int>> _fetch(String url) async {
    final res = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw DeviceAiException('Could not fetch the image from the hub (${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  /// Saves an image into [dir]; returns its file name there.
  Future<String> _download(String url, Directory dir, int n) async {
    final bytes = await _fetch(url);
    final ext = switch (bytes) {
      [0x89, 0x50, ...] => 'png',
      [0x47, 0x49, ...] => 'gif',
      [0x52, 0x49, 0x46, 0x46, ...] => 'webp',
      _ => 'jpg',
    };
    final name = 'image-$n.$ext';
    await File('${dir.path}${Platform.pathSeparator}$name').writeAsBytes(bytes);
    return name;
  }

  Future<({int code, String stdout, String stderr})> _run(
    String exe,
    List<String> args, {
    Directory? dir,
    String? input,
  }) async {
    final p = await _start(
      exe,
      args,
      workingDirectory: dir?.path,
      runInShell: Platform.isWindows && !exe.toLowerCase().endsWith('.exe'),
    );
    if (input != null) p.stdin.write(input);
    p.stdin.close().ignore();
    final out = p.stdout.transform(utf8.decoder).join();
    final err = p.stderr.transform(utf8.decoder).join();
    final code = await p.exitCode.timeout(
      _limit,
      onTimeout: () {
        p.kill();
        throw DeviceAiException('${choice.tool.label} took too long. Try again.');
      },
    );
    return (code: code, stdout: await out, stderr: await err);
  }

  DeviceAiException _stopped(String name, ({int code, String stdout, String stderr}) out) {
    final why = _lastLine(out.stderr);
    if (RegExp(r'log ?in|sign ?in|auth', caseSensitive: false).hasMatch(why)) {
      return DeviceAiException('$name is not signed in. Sign in from Settings > AI.');
    }
    return DeviceAiException(
      why.isEmpty ? '$name stopped without an answer. Try again.' : '$name stopped: $why',
    );
  }
}

/// A model's text answer as JSON (some wrap it in a code fence).
Object? _parse(String text, String name) {
  final t = text
      .trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'```$'), '');
  try {
    return jsonDecode(t.trim());
  } on FormatException {
    throw DeviceAiException('$name answered in an unexpected form. Try again.');
  }
}

Json _decode(String text) {
  try {
    return obj(jsonDecode(text.trim()));
  } on FormatException {
    return const {};
  }
}

String _lastLine(String s) => s.trim().split('\n').last.trim();
