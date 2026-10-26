import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/providers.dart';
import '../ui/widgets.dart';
import 'ask_ai.dart';

/// "Ask AI" for help where the user is: [screen] names the screen, [topic]
/// is what it shows (a page tip, a Sentinel finding, a wizard step).
class AskAiButton extends StatelessWidget {
  const AskAiButton({super.key, this.screen, this.topic});
  final String? screen, topic;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => showAskAi(context, screen: screen, topic: topic),
    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
    label: const Text('Ask AI'),
  );
}

Future<void> showAskAi(BuildContext context, {String? screen, String? topic}) => showDialog<void>(
  context: context,
  builder: (_) => _AskAiDialog(screen: screen, topic: topic),
);

/// Picks where Ask AI's answers come from.
Future<void> showAskAiSetup(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SetupDialog());

const _privacy =
    'Only this app\'s guide, the screen\'s name and your question are sent, never your data. '
    'Don\'t type passwords, recovery keys or other private details.';

class _AskAiDialog extends ConsumerStatefulWidget {
  const _AskAiDialog({this.screen, this.topic});
  final String? screen, topic;

  @override
  ConsumerState<_AskAiDialog> createState() => _AskAiDialogState();
}

class _AskAiDialogState extends ConsumerState<_AskAiDialog> {
  final _question = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <HelpTurn>[];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _system =>
      helpSystemPrompt(app: ref.read(appIdentityProvider).name, hints: ref.read(hintTextsProvider));

  /// The user's next message; the first one says where they are.
  String _asked(String text) =>
      _turns.isEmpty ? helpQuestion(question: text, screen: widget.screen, topic: widget.topic) : text;

  Future<void> _send(HelpAiSetup setup) async {
    final text = _question.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _turns.add((user: true, text: _asked(text)));
      _question.clear();
      _busy = true;
      _error = null;
    });
    try {
      final asker = await ref.read(helpAskerProvider)(setup);
      final answer = await asker.ask(_system, _turns);
      if (mounted) setState(() => _turns.add((user: false, text: answer)));
    } catch (e) {
      // Keep the question so a retry or another AI can answer it.
      if (mounted) {
        setState(() {
          _question.text = text;
          _turns.removeLast();
          _error = describeError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Hands the question to a chat website, with the guide on the clipboard.
  Future<void> _open(({String name, String url}) site) async {
    final text = _question.text.trim();
    final question = helpQuestion(
      question: text.isEmpty ? 'How do I use this?' : text,
      screen: widget.screen,
      topic: widget.topic,
    );
    final full = '$_system\n\n---\n\n$question';
    await Clipboard.setData(ClipboardData(text: full));
    final short = '${ref.read(appIdentityProvider).name} (a Brahma app): $question';
    final ok = await launchUrl(chatLink(site, short), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    showMessage(
      context,
      ok
          ? 'The question and the app\'s guide are copied. Paste them into ${site.name} for a fuller answer.'
          : 'Could not open ${site.name}. The question is copied: paste it into any chat.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(helpAiProvider).value ?? const HelpAiSetup();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = setup.via == HelpAi.chat;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ask AI', style: theme.textTheme.titleLarge),
                        Text(
                          'Answers from: ${setup.via.label}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => showAskAiSetup(context), child: const Text('Change')),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (widget.topic case final topic? when _turns.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 8),
                  child: Text(
                    'About: $topic',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              Flexible(
                child: ListView(
                  controller: _scroll,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 12, right: 8),
                  children: [
                    for (final t in _turns) _Bubble(t),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error, style: TextStyle(color: scheme.error)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: _question,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: chat ? null : (_) => _send(setup),
                  decoration: InputDecoration(
                    labelText: 'What are you trying to do?',
                    border: const OutlineInputBorder(),
                    suffixIcon: chat
                        ? null
                        : IconButton(
                            tooltip: 'Ask',
                            onPressed: _busy ? null : () => _send(setup),
                            icon: const Icon(Icons.send),
                          ),
                  ),
                ),
              ),
              if (chat) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final site in chatSites)
                      OutlinedButton.icon(
                        onPressed: () => _open(site),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text('Ask ${site.name}'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Opens the chat website with your question. Want answers right here? Choose Change.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _privacy,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.turn);
  final HelpTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: turn.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: turn.user ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          turn.text,
          style: TextStyle(color: turn.user ? scheme.onPrimaryContainer : scheme.onSurface),
        ),
      ),
    );
  }
}

class _SetupDialog extends ConsumerStatefulWidget {
  const _SetupDialog();

  @override
  ConsumerState<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends ConsumerState<_SetupDialog> {
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _base = TextEditingController();
  HelpAi? _via;
  bool _hasKey = false, _checking = false, _show = false;
  List<String>? _models;
  String? _result;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    final setup = ref.read(helpAiProvider).value ?? const HelpAiSetup();
    _pick(setup.via, model: setup.model, base: setup.base);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _base.dispose();
    super.dispose();
  }

  Future<void> _pick(HelpAi via, {String model = '', String base = ''}) async {
    setState(() {
      _via = via;
      _model.text = model;
      _base.text = base;
      _key.clear();
      _models = null;
      _result = null;
    });
    final kept = await ref.read(keyVaultProvider).aiKey(via.name);
    if (mounted && _via == via) setState(() => _hasKey = kept != null && kept.isNotEmpty);
  }

  HelpAiSetup get _setup => HelpAiSetup(via: _via!, model: _model.text.trim(), base: _base.text.trim());

  /// Proves the key, address or program works, and lists the models.
  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final typed = _key.text.trim();
      final asker = typed.isEmpty ? await ref.read(helpAskerProvider)(_setup) : HelpAsker(_setup, key: typed);
      if (_via!.needsKey && (asker.key ?? '').isEmpty) throw AskAiException('Paste the key first.');
      final models = await asker.models();
      if (!mounted) return;
      setState(() {
        _ok = true;
        _models = models.take(40).toList();
        _result = switch (_via!) {
          HelpAi.claudeCode ||
          HelpAi.codex => 'Found ${_via!.label}. Make sure it is signed in to your plan.',
          _ when models.isEmpty => 'It answers, but lists no models. Type a model name.',
          _ => 'It works. Pick a model or keep the one shown.',
        };
        if (_model.text.isEmpty && _via!.defaultModel.isEmpty && models.isNotEmpty) {
          _model.text = models.first;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _result = describeError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    final typed = _key.text.trim();
    if (_via!.needsKey && typed.isEmpty && !_hasKey) {
      setState(() {
        _ok = false;
        _result = 'Paste the key first.';
      });
      return;
    }
    if (_via == HelpAi.local && _model.text.trim().isEmpty) {
      setState(() {
        _ok = false;
        _result = 'Choose Check to find the models, or type one.';
      });
      return;
    }
    await ref.read(helpAiProvider.notifier).save(_setup, key: typed.isEmpty ? null : typed);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final via = _via!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Where should answers come from?'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<HelpAi>(
                groupValue: via,
                onChanged: (v) {
                  if (v != null) _pick(v);
                },
                child: Column(
                  children: [
                    for (final v in HelpAi.offered)
                      RadioListTile<HelpAi>(
                        value: v,
                        contentPadding: EdgeInsets.zero,
                        title: Text(v.label),
                        subtitle: Text(v.about),
                      ),
                  ],
                ),
              ),
              const Divider(),
              ..._steps(via, theme),
              if (via == HelpAi.local) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _base,
                  decoration: InputDecoration(
                    labelText: 'Server address',
                    hintText: via.openAiBase,
                    helperText: 'Ollama: http://localhost:11434/v1 · LM Studio: http://localhost:1234/v1',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              if (via.needsKey || via == HelpAi.local) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: !_show,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: via == HelpAi.local ? 'Key (only if the server needs one)' : 'Key',
                    helperText: _hasKey
                        ? 'A key is kept in the system keychain. Paste a new one to replace it.'
                        : null,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _show ? 'Hide' : 'Show',
                      onPressed: () => setState(() => _show = !_show),
                      icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
              ],
              if (via != HelpAi.chat) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  decoration: InputDecoration(
                    labelText: 'Model',
                    hintText: via.defaultModel.isEmpty ? 'The tool\'s own choice' : via.defaultModel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_models case final models? when models.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in models)
                          ActionChip(label: Text(m), onPressed: () => setState(() => _model.text = m)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(onPressed: _checking ? null : _check, child: const Text('Check')),
                    const SizedBox(width: 12),
                    if (_checking)
                      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ],
              if (_result case final result?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    result,
                    style: TextStyle(color: _ok ? Status.good.color : theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Text(_privacy, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  /// What to do for [via], step by step.
  List<Widget> _steps(HelpAi via, ThemeData theme) {
    final steps = switch (via) {
      HelpAi.chat => [
        'Nothing to set up. Ask AI opens ChatGPT, Claude or Gemini in the browser with your question.',
        'Sign in there with your free or paid account.',
      ],
      HelpAi.gemini => [
        'Open Google AI Studio and sign in with your Google account.',
        'Press Create API key, then copy it.',
        'Paste it below and choose Check. The free tier costs nothing.',
      ],
      HelpAi.local => [
        'Install Ollama (or LM Studio) on this computer or one at home.',
        'Download a model, for example: ollama pull gemma3',
        'For a computer at home, let it listen on the network (Ollama: OLLAMA_HOST=0.0.0.0) and type its address below.',
        'Choose Check and pick a model.',
      ],
      HelpAi.claudeCode => [
        'Install Claude Code on this computer.',
        'Run "claude" in a terminal once and sign in with your Claude account (Pro or Max).',
        'Choose Check. Answers then count against your plan; this app never sees your sign-in.',
      ],
      HelpAi.codex => [
        'Install the Codex CLI on this computer.',
        'Run "codex" in a terminal once and sign in with your ChatGPT account.',
        'Choose Check. Answers then count against your plan; this app never sees your sign-in.',
      ],
      HelpAi.anthropic || HelpAi.openai || HelpAi.openrouter => [
        'Open the key page and sign in.',
        'Create a key and copy it.',
        'Paste it below and choose Check. Each question costs a fraction of a cent.',
      ],
    };
    return [
      for (final (i, s) in steps.indexed)
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${i + 1}. $s')),
      if (via.setupPage case final page?)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(page), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(switch (via) {
              HelpAi.gemini => 'Open Google AI Studio',
              HelpAi.local => 'Get Ollama',
              HelpAi.claudeCode => 'Install Claude Code',
              HelpAi.codex => 'Install the Codex CLI',
              _ => 'Open the key page',
            }),
          ),
        ),
    ];
  }
}
