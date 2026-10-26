import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/device_ai.dart';
import '../domain/hub.dart' show NoHubException;
import '../domain/models.dart';
import 'accounts_page.dart' show credentialIcon, credentialTitle, editCredential;
import 'common.dart';
import 'look.dart';

/// The models an AI service's key can use, as the hub lists them (which also
/// checks the key). Not reloaded every minute: listing calls the service.
final aiModelsProvider = FutureProvider.autoDispose.family<List<String>, CredentialProvider>((ref, p) async {
  final hub = await ref.watch(hubProvider.future);
  if (hub == null) throw NoHubException();
  return hub.aiModels(p);
});

/// What this computer's AI tool reports (who it is signed in as), or why it
/// cannot be used.
final deviceAiStatusProvider = FutureProvider.autoDispose<String?>((ref) async {
  final ai = await ref.watch(deviceAiProvider.future);
  return ai?.check();
});

/// The models Ollama has pulled on this computer.
final ollamaModelsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final ai = await ref.watch(deviceAiProvider.future);
  return ai == null ? const [] : ai.ollamaModels();
});

/// Settings > AI: a key on the hub (any of the services, and its model), and
/// on a computer the user's own subscription through its official tool.
class AiSettings extends ConsumerWidget {
  const AiSettings({super.key, required this.settings, required this.onSave});
  final HubSettings settings;
  final Future<void> Function(HubSettings) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final muted = t.bodyMedium?.copyWith(color: tone.muted);
    final keyed = {
      for (final c in ref.watch(credentialsProvider).value ?? const <CredentialStatus>[])
        if (c.set) c.provider,
    };
    final services = CredentialProvider.aiServices;
    final withKey = services.where((p) => keyed.contains(p.name)).toList();
    final active = s.aiProvider != null && keyed.contains(s.aiProvider!.name) ? s.aiProvider : withKey.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AI drafts captions, suggests replies, translates, writes alt text and checks discovery finds. '
          'Connect one way below; each service bills you directly.',
          style: muted,
        ),
        const SizedBox(height: 16),
        Text('On the hub', style: t.titleSmall),
        const SizedBox(height: 4),
        Text(
          'An API key lets the hub use AI on its own, including in the background (sorting the inbox, matching '
          'discovery finds, the weekly summary). API keys are separate from Claude, ChatGPT or Gemini plans. '
          'Google Gemini has a free tier.',
          style: muted,
        ),
        for (final p in services)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(credentialIcon(p), size: 20, color: tone.text),
            title: Text(credentialTitle(p)),
            subtitle: Text(
              keyed.contains(p.name) ? (p == active ? 'Key set · in use' : 'Key set') : 'No key',
            ),
            trailing: Icon(
              keyed.contains(p.name) ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: keyed.contains(p.name) ? growth : tone.muted,
            ),
            onTap: () async {
              await editCredential(context, ref, p);
              ref.invalidate(aiModelsProvider(p));
            },
          ),
        if (withKey.length > 1)
          Choice<CredentialProvider?>(
            key: ValueKey(('ai.provider', s.aiProvider)),
            label: 'The hub uses',
            value: s.aiProvider,
            options: {
              null: 'The first with a key, in this order',
              for (final p in withKey) p: credentialTitle(p),
            },
            onChanged: (p) => onSave(s.withAiProvider(p)),
          ),
        if (active != null) _HubModel(provider: active, settings: s, onSave: onSave),
        const SizedBox(height: 16),
        Text('On this computer', style: t.titleSmall),
        const SizedBox(height: 4),
        if (deviceAiSupported)
          const _DeviceAi()
        else
          Text(
            'To use a Claude, ChatGPT or Gemini plan instead of a key, open Vani on a Windows or Linux computer. '
            'This phone uses the hub\'s key.',
            style: muted,
          ),
      ],
    );
  }
}

/// The model the hub uses with [provider], from the service's own list.
class _HubModel extends ConsumerWidget {
  const _HubModel({required this.provider, required this.settings, required this.onSave});
  final CredentialProvider provider;
  final HubSettings settings;
  final Future<void> Function(HubSettings) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        settings.aiModels[provider.name] ?? (provider == CredentialProvider.anthropic ? claudeModels.keys.first : '');
    final listed = ref.watch(aiModelsProvider(provider));
    if (listed.hasError && !listed.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          describeError(listed.error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    final models = listed.value ?? (provider == CredentialProvider.anthropic ? claudeModels.keys.toList() : const []);
    if (models.isEmpty && current.isEmpty) return const LinearProgressIndicator();
    return Choice<String>(
      key: ValueKey(('ai.model', provider, current, models.length)),
      label: '${credentialTitle(provider)} model',
      value: current,
      options: {
        if (current.isEmpty) '': 'Pick a model',
        if (current.isNotEmpty && !models.contains(current)) current: current,
        for (final m in models) m: claudeModels[m] ?? m,
      },
      onChanged: (m) {
        if (m.isNotEmpty) onSave(settings.copyWith(aiModels: {...settings.aiModels, provider.name: m}));
      },
    );
  }
}

/// This computer's AI: the user's own CLI (signed in by the tool itself), or
/// Ollama. Device-only.
class _DeviceAi extends ConsumerWidget {
  const _DeviceAi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    final muted = t.bodyMedium?.copyWith(color: tone.muted);
    final ai = ref.watch(deviceAiProvider).value;
    final choice = ai?.choice;
    final status = ai == null ? null : ref.watch(deviceAiStatusProvider);
    void set(DeviceAiChoice? c) => guarded(context, () => ref.read(deviceAiProvider.notifier).set(c));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Use your own plan through its official app, signed in by you: Vani never sees your password or its '
          'tokens. It answers while Vani is open here; background AI on the hub still needs a key.',
          style: muted,
        ),
        const SizedBox(height: 12),
        Choice<DeviceAiTool?>(
          key: ValueKey(('ai.device', choice?.tool)),
          label: 'Answer AI requests with',
          value: choice?.tool,
          options: {null: 'The hub\'s key', for (final tool in DeviceAiTool.values) tool: tool.label},
          onChanged: (tool) => set(tool == null ? null : DeviceAiChoice(tool: tool)),
        ),
        if (ai != null && choice != null) ...[
          switch (status) {
            AsyncData(:final value) => _Status(icon: Icons.check_circle_rounded, color: growth, text: value ?? ''),
            AsyncError(:final error) => _Status(
              icon: Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              text: describeError(error),
            ),
            _ => const LinearProgressIndicator(),
          },
          const SizedBox(height: 8),
          if (choice.tool == DeviceAiTool.claude)
            Choice<String>(
              key: ValueKey(('ai.claude', choice.model)),
              label: 'Model',
              value: choice.model,
              options: {'': 'Claude Code\'s default', ...claudeModels},
              onChanged: (m) => set(DeviceAiChoice(tool: choice.tool, model: m)),
            )
          else if (choice.tool == DeviceAiTool.ollama)
            switch (ref.watch(ollamaModelsProvider)) {
              AsyncData(:final value) when value.isNotEmpty => Choice<String>(
                key: ValueKey(('ai.ollama', choice.model)),
                label: 'Model',
                value: choice.model,
                options: {if (!value.contains(choice.model)) choice.model: 'Pick a model', for (final m in value) m: m},
                onChanged: (m) {
                  if (m.isNotEmpty) set(DeviceAiChoice(tool: choice.tool, model: m));
                },
              ),
              _ => const SizedBox.shrink(),
            }
          else
            _ModelField(
              key: ValueKey(('ai.model', choice.tool)),
              model: choice.model,
              onSave: (m) => set(DeviceAiChoice(tool: choice.tool, model: m)),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (choice.tool.cli && ai.locate() == null)
                FilledButton.tonalIcon(
                  onPressed: () => openLink(context, choice.tool.installPage),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('How to install'),
                )
              else if (choice.tool.cli)
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!await ai.openSignIn() && context.mounted) {
                      showMessage(
                        context,
                        'Open a terminal and run: ${[ai.locate(), ...ai.signInArguments].join(' ')}',
                      );
                    }
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Sign in'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => openLink(context, choice.tool.installPage),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Get Ollama'),
                ),
              TextButton.icon(
                onPressed: () {
                  ref.invalidate(deviceAiStatusProvider);
                  ref.invalidate(ollamaModelsProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Check again'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

/// A model name typed in, saved when the field is left (blank = the tool's default).
class _ModelField extends StatefulWidget {
  const _ModelField({super.key, required this.model, required this.onSave});
  final String model;
  final ValueChanged<String> onSave;

  @override
  State<_ModelField> createState() => _ModelFieldState();
}

class _ModelFieldState extends State<_ModelField> {
  late final _c = TextEditingController(text: widget.model);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    if (_c.text.trim() != widget.model) widget.onSave(_c.text.trim());
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _c,
      decoration: const InputDecoration(labelText: 'Model', helperText: 'Leave blank for the tool\'s default.'),
      onSubmitted: (_) => _save(),
      onTapOutside: (_) => _save(),
    ),
  );
}
