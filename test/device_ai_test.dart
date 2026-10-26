import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vani/domain/device_ai.dart';

class _Proc implements Process {
  _Proc(this.out, {this.onExit});
  final String out;
  final void Function()? onExit;

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(out));
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  late final IOSink stdin = IOSink(
    StreamController<List<int>>()..stream.listen((b) => stdinText += utf8.decode(b)),
  );
  String stdinText = '';
  @override
  Future<int> get exitCode async {
    onExit?.call();
    return 0;
  }

  @override
  int get pid => 1;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

const _request = DeviceRequest(
  system: 'Translate the text into English.',
  prompt: 'Hola',
  schema: {'type': 'object'},
);

void main() {
  late Directory bin;
  setUp(() {
    bin = Directory.systemTemp.createTempSync('vani-bin-');
    for (final n in ['claude', 'codex', 'gemini']) {
      File('${bin.path}/$n').writeAsStringSync('#!/bin/sh\n');
    }
  });
  tearDown(() => bin.deleteSync(recursive: true));

  DeviceAi make(DeviceAiTool tool, StartProcess start, {String model = '', http.Client? client}) => DeviceAi(
    DeviceAiChoice(tool: tool, model: model),
    start: start,
    client: client,
    environment: {'PATH': bin.path, 'HOME': '/nonexistent'},
  );

  test('Claude Code runs in print mode, locked down, and returns the structured output', () async {
    late List<String> args;
    late _Proc proc;
    final ai = make(DeviceAiTool.claude, (exe, a, {workingDirectory, runInShell = false}) async {
      expect(exe, '${bin.path}/claude');
      args = a;
      return proc = _Proc(
        jsonEncode({
          'subtype': 'success',
          'structured_output': {'text': 'Hello'},
        }),
      );
    }, model: 'claude-haiku-5-5');
    expect(await ai.answer(_request), {'text': 'Hello'});
    expect(args, containsAllInOrder(['-p', '--model', 'claude-haiku-5-5', '--system-prompt']));
    expect(args, containsAll(['--no-session-persistence', '--strict-mcp-config', '--json-schema']));
    expect(args[args.indexOf('--tools') + 1], '');
    expect(proc.stdinText, contains('Hola'));
  });

  test('a usage limit and a missing tool are worded for the user', () async {
    final limited = make(
      DeviceAiTool.claude,
      (_, _, {workingDirectory, runInShell = false}) async =>
          _Proc(jsonEncode({'subtype': 'error', 'is_error': true, 'result': 'Usage limit reached'})),
    );
    await expectLater(limited.answer(_request), throwsA(predicate((e) => '$e'.contains('usage limit'))));

    bin.deleteSync(recursive: true);
    bin.createSync();
    final missing = make(
      DeviceAiTool.codex,
      (_, _, {workingDirectory, runInShell = false}) async => _Proc(''),
    );
    await expectLater(missing.answer(_request), throwsA(predicate((e) => '$e'.contains('not installed'))));
  });

  test('Codex reads the schema from a file and writes its answer to one', () async {
    final ai = make(DeviceAiTool.codex, (exe, a, {workingDirectory, runInShell = false}) async {
      expect(a.first, 'exec');
      expect(a, containsAll(['--ephemeral', '--skip-git-repo-check', '--output-schema']));
      final schema = File(a[a.indexOf('--output-schema') + 1]);
      expect(jsonDecode(schema.readAsStringSync()), {'type': 'object'});
      return _Proc('', onExit: () => File(a[a.indexOf('-o') + 1]).writeAsStringSync('{"text":"Hello"}'));
    });
    expect(await ai.answer(_request), {'text': 'Hello'});
  });

  test('Gemini CLI answers in a code fence and Ollama answers over HTTP', () async {
    final gemini = make(DeviceAiTool.gemini, (_, a, {workingDirectory, runInShell = false}) async {
      expect(a, containsAll(['--output-format', 'json', '--approval-mode', 'plan']));
      return _Proc(jsonEncode({'response': '```json\n{"text":"Hello"}\n```'}));
    });
    expect(await gemini.answer(_request), {'text': 'Hello'});

    final ollama = make(
      DeviceAiTool.ollama,
      (_, _, {workingDirectory, runInShell = false}) async => throw StateError('no process'),
      model: 'gemma3',
      client: MockClient((req) async {
        if (req.url.path == '/api/tags') {
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'gemma3'},
              ],
            }),
            200,
          );
        }
        final body = jsonDecode(req.body) as Map;
        expect(body['model'], 'gemma3');
        expect(body['format'], {'type': 'object'});
        return http.Response(
          jsonEncode({
            'message': {'content': '{"text":"Hello"}'},
          }),
          200,
        );
      }),
    );
    expect(await ollama.answer(_request), {'text': 'Hello'});
    expect(await ollama.ollamaModels(), ['gemma3']);
  });

  test('the choice is stored on this device as JSON', () {
    final c = DeviceAiChoice.fromJson({'tool': 'codex', 'model': 'gpt-x'})!;
    expect(c.tool, DeviceAiTool.codex);
    expect(c.toJson(), {'tool': 'codex', 'model': 'gpt-x'});
    expect(DeviceAiChoice.fromJson({'tool': 'nope'}), isNull);
  });
}
