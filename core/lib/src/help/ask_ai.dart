import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app/providers.dart';
import '../sync/pocketbase_remote.dart' show isLocalServerHost;

/// Ask AI: help with finding the way around an app, from an AI the user
/// picks. Only the app's own guide (its hint texts and [coreGuide]), the
/// screen's name and the user's question are sent, never the app's data.
/// Keys stay in the system keychain; the command-line tools keep their own
/// sign-in, which the app never sees.

/// Where the answers come from.
enum HelpAi {
  chat('A chat website', 'Opens ChatGPT, Claude or Gemini with the question. Nothing to set up.'),
  gemini('Free Google account', 'Gemini, with a free key from Google AI Studio.'),
  local('AI on this computer or network', 'Ollama, LM Studio or any OpenAI-compatible server.'),
  claudeCode('Claude subscription', 'Your Claude plan, through Claude Code on this computer.'),
  codex('ChatGPT plan', 'Your ChatGPT plan, through the Codex CLI on this computer.'),
  anthropic('Anthropic API key', 'Pay as you go at console.anthropic.com.'),
  openai('OpenAI API key', 'Pay as you go at platform.openai.com.'),
  openrouter('OpenRouter key', 'Many models with one key, some of them free.');

  const HelpAi(this.label, this.about);
  final String label, about;

  /// Runs a program on this computer, so desktop only.
  bool get cli => this == claudeCode || this == codex;
  bool get needsKey => this == gemini || this == anthropic || this == openai || this == openrouter;

  /// Where to get a key or the program.
  String? get setupPage => switch (this) {
    chat => null,
    gemini => 'https://aistudio.google.com/apikey',
    local => 'https://ollama.com/download',
    claudeCode => 'https://code.claude.com/docs/en/setup',
    codex => 'https://developers.openai.com/codex/cli',
    anthropic => 'https://console.anthropic.com/settings/keys',
    openai => 'https://platform.openai.com/api-keys',
    openrouter => 'https://openrouter.ai/keys',
  };

  /// The model used when the user names none; empty lets the service or
  /// tool pick its own.
  String get defaultModel => switch (this) {
    gemini => 'gemini-3.5-flash-lite',
    anthropic => 'claude-opus-5-5',
    openrouter => 'openrouter/auto',
    _ => '',
  };

  /// The chat-completions base of the OpenAI-compatible ones.
  String? get openAiBase => switch (this) {
    openai => 'https://api.openai.com/v1',
    openrouter => 'https://openrouter.ai/api/v1',
    local => 'http://localhost:11434/v1',
    _ => null,
  };

  static bool get desktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// The choices this device offers.
  static List<HelpAi> get offered => [
    for (final v in values)
      if (!v.cli || desktop) v,
  ];
}

/// The user's choice, kept in the local setting `ai.help` (not synced: a
/// key or a local server belongs to one device).
class HelpAiSetup {
  const HelpAiSetup({this.via = HelpAi.chat, this.model = '', this.base = ''});
  final HelpAi via;

  /// Empty for [HelpAi.defaultModel].
  final String model;

  /// The local server's address, for [HelpAi.local].
  final String base;

  String get effectiveModel => model.isEmpty ? via.defaultModel : model;
  String get effectiveBase => base.isEmpty ? via.openAiBase ?? '' : base;

  factory HelpAiSetup.fromJson(Object? j) {
    if (j is! Map) return const HelpAiSetup();
    return HelpAiSetup(
      via: HelpAi.values.firstWhere((v) => v.name == j['via'], orElse: () => HelpAi.chat),
      model: j['model'] is String ? j['model'] as String : '',
      base: j['base'] is String ? j['base'] as String : '',
    );
  }

  Map<String, Object?> toJson() => {'via': via.name, 'model': model, 'base': base};
}

class AskAiException implements Exception, UserFacingError {
  AskAiException(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

/// One turn of the conversation.
typedef HelpTurn = ({bool user, String text});

/// How Brahma's shared parts work, for every app's guide.
const coreGuide = '''
Shared parts of every Brahma app:
- Navigation: on wide windows a rail on the left; on phones a dock along the bottom, and the menu button (or a swipe right) opens a panel listing every screen. Settings is one of the screens.
- First start: the app asks where data lives. "Keep everything on this device" needs nothing else. "Sync across my devices" opens the sync setup wizard. Either can be changed later in Settings > Sync.
- Sync setup wizard (Settings > Sync > Set up sync): choose Home server (a Linux computer at home that stays on; run brahma/server/home/install.sh there, then paste the setup link it prints or use "Find my home server" on the same Wi-Fi), Cloud server (Cloudflare free plan; run npm run setup in brahma/server, then paste the link), or "I already have a server" (type its address). Then create the account. Write down the recovery key it shows: with the password it is the only way to unlock synced data.
- Away from home: install Tailscale on the server and each device, then run ./install.sh --link on the server for an address that works anywhere.
- Add a device: Settings > Sync > Add a device shows a code; on the new device choose "Join from another device" and scan or paste it.
- Sign in with e-mail: Settings > Sync > Sign in with e-mail. If the password changed, the app asks for the recovery key.
- App lock: Settings > App lock sets a PIN, with fingerprint or face unlock where the device has it.
- Sentinel: Settings > Security and privacy > Sentinel lists what needs attention (updates, device settings, attacks under way, advisories), each with why it matters, the steps to fix it and, where possible, a one-tap fix. Snooze hides one for 30 days.
- Hints: Settings > Hints turns tips on or off; Restore brings dismissed page tips back.
- Ask AI: Settings > Hints > Ask AI picks where answers come from.''';

/// The system prompt: who answers, and the guide to answer from.
String helpSystemPrompt({required String app, required Map<String, String> hints}) {
  String section(String prefix) => [
    for (final MapEntry(:key, :value) in hints.entries)
      if (key.startsWith(prefix)) '- ${key.substring(prefix.length)}: $value',
  ].join('\n');
  final other = [
    for (final MapEntry(:key, :value) in hints.entries)
      if (!key.startsWith('nav.') && !key.startsWith('page.')) '- $key: $value',
  ].join('\n');
  return '''
You help people find their way around $app, a personal app in the Brahma suite. Answer from the guide below. Give short numbered steps that name the exact screens, buttons and menus. If the guide does not cover the question, say so and point to the closest screen. Keep answers brief. Never ask for passwords, recovery keys, API keys or the user's own data, and tell the user not to paste them.

Screens of $app:
${section('nav.')}

What each screen is for:
${section('page.')}

Buttons and options:
$other

$coreGuide''';
}

/// The question as the user asks it, with where they are.
String helpQuestion({required String question, String? screen, String? topic}) => [
  if (screen != null) 'I am on the $screen screen.',
  if (topic != null && topic.isNotEmpty) 'It says: $topic',
  question,
].join('\n');

/// Chat websites that open with a prefilled question.
const chatSites = <({String name, String url})>[
  (name: 'ChatGPT', url: 'https://chatgpt.com/'),
  (name: 'Claude', url: 'https://claude.ai/new'),
  (name: 'Gemini', url: 'https://gemini.google.com/app'),
];

/// The address opening [site] with [prompt], where the site takes one.
/// Gemini takes none: the prompt goes on the clipboard instead. Long prompts
/// are cut down for the address; the clipboard always has all of it.
Uri chatLink(({String name, String url}) site, String prompt) {
  final short = prompt.length > 1800 ? '${prompt.substring(0, 1800)}…' : prompt;
  return switch (site.name) {
    'Gemini' => Uri.parse(site.url),
    _ => Uri.parse(site.url).replace(queryParameters: {'q': short}),
  };
}

/// Finds a program on this computer. Apps started from a menu often get a
/// shorter PATH than a terminal, so the usual install places are tried too.
String? locateTool(String name, {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final windows = Platform.isWindows;
  final home = env[windows ? 'USERPROFILE' : 'HOME'] ?? '';
  final sep = windows ? r'\' : '/';
  final names = windows ? ['$name.exe', '$name.cmd'] : [name];
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
      '/opt/homebrew/bin',
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

/// Asks the chosen AI. [key] is the keychain's key for the ones that need it.
class HelpAsker {
  HelpAsker(this.setup, {this.key, http.Client? client}) : _http = client ?? http.Client();
  final HelpAiSetup setup;
  final String? key;
  final http.Client _http;

  static const _timeout = Duration(seconds: 90);

  /// The answer to the last turn of [turns].
  Future<String> ask(String system, List<HelpTurn> turns) async {
    if (setup.via.needsKey && (key == null || (key ?? '').trim().isEmpty)) {
      throw AskAiException('Add your ${setup.via.label} key first.');
    }
    return switch (setup.via) {
      HelpAi.chat => throw AskAiException('A chat website answers in the browser.'),
      HelpAi.gemini => _gemini(system, turns),
      HelpAi.anthropic => _anthropic(system, turns),
      HelpAi.local || HelpAi.openai || HelpAi.openrouter => _openAi(system, turns),
      HelpAi.claudeCode || HelpAi.codex => _cli(system, turns),
    };
  }

  /// Model names the service offers, to pick from. Also proves the key or
  /// address works.
  Future<List<String>> models() async {
    switch (setup.via) {
      case HelpAi.gemini:
        final j = await _send(
          http.Request('GET', Uri.parse('$_geminiBase/models?pageSize=100'))
            ..headers['x-goog-api-key'] = (key ?? '').trim(),
        );
        return [
          for (final m in _list(j['models']).map(_map))
            if (_list(m['supportedGenerationMethods']).contains('generateContent'))
              '${m['name']}'.replaceFirst('models/', ''),
        ];
      case HelpAi.anthropic:
        final j = await _send(
          http.Request('GET', Uri.parse('https://api.anthropic.com/v1/models'))
            ..headers.addAll(_anthropicHeaders),
        );
        return [for (final m in _list(j['data']).map(_map)) '${m['id']}'];
      case HelpAi.local || HelpAi.openai || HelpAi.openrouter:
        final j = await _send(http.Request('GET', Uri.parse('${_base()}/models'))..headers.addAll(_bearer));
        return [for (final m in _list(j['data']).map(_map)) '${m['id']}']..sort();
      case HelpAi.claudeCode || HelpAi.codex:
        _exe();
        return const [];
      case HelpAi.chat:
        return const [];
    }
  }

  static const _geminiBase = 'https://generativelanguage.googleapis.com/v1beta';

  Future<String> _gemini(String system, List<HelpTurn> turns) async {
    final j = await _send(
      http.Request('POST', Uri.parse('$_geminiBase/models/${setup.effectiveModel}:generateContent'))
        ..headers.addAll({'x-goog-api-key': (key ?? '').trim(), 'content-type': 'application/json'})
        ..body = jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': system},
            ],
          },
          'contents': [
            for (final t in turns)
              {
                'role': t.user ? 'user' : 'model',
                'parts': [
                  {'text': t.text},
                ],
              },
          ],
        }),
    );
    final parts = _list(_map(_map(_list(j['candidates']).firstOrNull)['content'])['parts']);
    return _text([for (final p in parts) _map(p)['text']]);
  }

  Map<String, String> get _anthropicHeaders => {
    'x-api-key': (key ?? '').trim(),
    'anthropic-version': '2026-10-21',
    'content-type': 'application/json',
  };

  Future<String> _anthropic(String system, List<HelpTurn> turns) async {
    final j = await _send(
      http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
        ..headers.addAll({..._anthropicHeaders, 'anthropic-beta': 'server-side-fallback-2026-07-01'})
        ..body = jsonEncode({
          'model': setup.effectiveModel,
          'max_tokens': 16000,
          // Short help answers: little thinking needed.
          'output_config': {'effort': 'low'},
          'fallbacks': 'default',
          'system': system,
          'messages': [
            for (final t in turns) {'role': t.user ? 'user' : 'assistant', 'content': t.text},
          ],
        }),
    );
    if (j['stop_reason'] == 'refusal') throw AskAiException('Claude declined to answer that question.');
    return _text([
      for (final b in _list(j['content']))
        if (_map(b)['type'] == 'text') _map(b)['text'],
    ]);
  }

  Map<String, String> get _bearer => {
    if (key != null && (key ?? '').trim().isNotEmpty) 'authorization': 'Bearer ${(key ?? '').trim()}',
  };

  /// The OpenAI-compatible base, which must be https unless it is on this
  /// computer or the home network.
  String _base() {
    final base = setup.effectiveBase.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasAuthority) throw AskAiException('That is not a server address.');
    if (uri.scheme == 'https' || (uri.scheme == 'http' && isLocalServerHost(uri.host))) return base;
    throw AskAiException('Use https:// for servers outside this computer and your home network.');
  }

  Future<String> _openAi(String system, List<HelpTurn> turns) async {
    if (setup.effectiveModel.isEmpty) throw AskAiException('Pick a model first.');
    final j = await _send(
      http.Request('POST', Uri.parse('${_base()}/chat/completions'))
        ..headers.addAll({..._bearer, 'content-type': 'application/json'})
        ..body = jsonEncode({
          'model': setup.effectiveModel,
          'messages': [
            {'role': 'system', 'content': system},
            for (final t in turns) {'role': t.user ? 'user' : 'assistant', 'content': t.text},
          ],
        }),
    );
    return _text([_map(_map(_list(j['choices']).firstOrNull)['message'])['content']]);
  }

  Future<Map<String, Object?>> _send(http.Request request) async {
    final http.Response r;
    try {
      r = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw AskAiException('${setup.via.label} did not answer in time.');
    } on SocketException {
      throw AskAiException(
        setup.via == HelpAi.local
            ? 'Nothing answers at ${setup.effectiveBase}. Is the AI server running?'
            : 'No connection. Check the internet connection.',
      );
    } on http.ClientException catch (e) {
      throw AskAiException('No connection: ${e.message}');
    }
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw AskAiException('${setup.via.label} answered ${r.statusCode} in an unexpected form.');
    }
    if (r.statusCode == 200 && j is Map) return j.cast<String, Object?>();
    final said = switch (j) {
      {'error': {'message': final String m}} => m,
      {'error': final String m} => m,
      _ => '',
    };
    throw AskAiException(switch (r.statusCode) {
      401 || 403 => 'The key was refused. Check it in Ask AI\'s settings. $said'.trim(),
      404 => 'Not found: check the model name. $said'.trim(),
      429 => 'The usage limit is reached for now. Try again later. $said'.trim(),
      _ => '${setup.via.label} answered ${r.statusCode}. $said'.trim(),
    });
  }

  String _exe() {
    final name = setup.via == HelpAi.claudeCode ? 'claude' : 'codex';
    return locateTool(name) ??
        (throw AskAiException(
          '${setup.via.label} needs the $name program. Install it from ${setup.via.setupPage}',
        ));
  }

  /// The user's own, unmodified Claude Code or Codex, signed in to their own
  /// plan, with no tools, in an empty folder, keeping no session.
  Future<String> _cli(String system, List<HelpTurn> turns) async {
    final exe = _exe();
    final dir = await Directory.systemTemp.createTemp('brahma-help-');
    try {
      final transcript = [for (final t in turns) '${t.user ? 'User' : 'You'}: ${t.text}'].join('\n\n');
      final answer = File('${dir.path}${Platform.pathSeparator}answer.txt');
      final args = setup.via == HelpAi.claudeCode
          ? [
              '-p',
              '--output-format',
              'json',
              if (setup.model.isNotEmpty) ...['--model', setup.model],
              '--system-prompt',
              system,
              '--tools',
              '',
              '--no-session-persistence',
              '--strict-mcp-config',
              '--setting-sources',
              'project',
            ]
          : [
              'exec',
              '--skip-git-repo-check',
              '--ephemeral',
              '--sandbox',
              'read-only',
              '-o',
              answer.path,
              if (setup.model.isNotEmpty) ...['-m', setup.model],
              '-',
            ];
      final p = await Process.start(
        exe,
        args,
        workingDirectory: dir.path,
        runInShell: Platform.isWindows && !exe.toLowerCase().endsWith('.exe'),
      );
      p.stdin.write(setup.via == HelpAi.claudeCode ? transcript : '$system\n\n$transcript');
      await p.stdin.close();
      final out = p.stdout.transform(utf8.decoder).join();
      final err = p.stderr.transform(utf8.decoder).join();
      final code = await p.exitCode.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          p.kill();
          throw AskAiException('${setup.via.label} did not answer in time.');
        },
      );
      if (setup.via == HelpAi.codex) {
        if (answer.existsSync()) return _text([answer.readAsStringSync()]);
        throw _stopped(await err);
      }
      final j = _map(_tryJson(await out));
      if (j['is_error'] == true || j['result'] is! String) {
        throw _stopped(j['result'] is String ? j['result'] as String : await err, code: code);
      }
      return _text([j['result']]);
    } finally {
      dir.delete(recursive: true).ignore();
    }
  }

  AskAiException _stopped(String said, {int code = 1}) {
    final why = said.trim().split('\n').last.trim();
    if (RegExp(r'log ?in|sign ?in|auth', caseSensitive: false).hasMatch(why)) {
      final name = setup.via == HelpAi.claudeCode ? 'claude' : 'codex';
      return AskAiException(
        '${setup.via.label} is not signed in. Run "$name" in a terminal once and sign in.',
      );
    }
    return AskAiException(
      why.isEmpty ? '${setup.via.label} stopped without an answer.' : '${setup.via.label}: $why',
    );
  }

  static Object? _tryJson(String s) {
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  static List<Object?> _list(Object? v) => v is List ? v : const [];
  static Map<Object?, Object?> _map(Object? v) => v is Map ? v : const {};

  String _text(List<Object?> parts) {
    final text = parts.whereType<String>().join().trim();
    if (text.isEmpty) throw AskAiException('${setup.via.label} gave an empty answer. Try again.');
    return text;
  }
}

/// The user's Ask AI choice on this device.
class HelpAiSettings extends AsyncNotifier<HelpAiSetup> {
  static const _setting = 'ai.help';

  @override
  Future<HelpAiSetup> build() async {
    final db = ref.watch(coreSessionProvider).db;
    final raw = await db.localSetting(_setting);
    return HelpAiSetup.fromJson(raw == null ? null : jsonDecode(raw));
  }

  /// Saves [setup] and, when given, its key ('' removes it).
  Future<void> save(HelpAiSetup setup, {String? key}) async {
    if (key != null) await ref.read(keyVaultProvider).setAiKey(setup.via.name, key.trim());
    await ref.read(coreSessionProvider).db.setLocalSetting(_setting, jsonEncode(setup.toJson()));
    state = AsyncData(setup);
  }
}

final helpAiProvider = AsyncNotifierProvider<HelpAiSettings, HelpAiSetup>(HelpAiSettings.new);

/// Builds the asker for a setup, with its key from the keychain. Tests
/// override it.
final helpAskerProvider = Provider<Future<HelpAsker> Function(HelpAiSetup)>((ref) {
  return (setup) async => HelpAsker(
    setup,
    key: setup.via.needsKey || setup.via == HelpAi.local
        ? await ref.read(keyVaultProvider).aiKey(setup.via.name)
        : null,
  );
});
