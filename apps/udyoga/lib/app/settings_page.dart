import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/book.dart';
import '../domain/ai.dart';
import '../domain/feeds.dart';
import '../domain/gemini.dart';
import '../domain/n8n.dart';
import '../domain/update.dart';
import '../ui/common.dart';
import 'providers.dart';

/// Settings for the AI and the job sites, read together.
final _aiSettingsProvider = FutureProvider((ref) async {
  ref.watch(revisionProvider);
  final book = ref.watch(sessionProvider).book;
  return (
    keys: await book.aiKeys(),
    model: await book.pref<String>(PrefKeys.aiModel, ''),
    routine: await book.pref<String>(PrefKeys.aiRoutine, 'off'),
    feeds: await book.feedKeys(),
    n8n: await book.n8nLink(),
    spend: await book.spend(today().substring(0, 7)),
  );
});

const _routines = {
  'off': 'Off: only when I ask',
  'weekly': 'Weekly job search, monthly career map',
  'daily': 'Daily job search, monthly career map',
};

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_aiSettingsProvider).value;
    final keys = s?.keys ?? const <AiProvider, String>{};
    final model = s == null ? null : effectiveModel(s.model, keys);
    return PageScaffold(
      title: 'Settings',
      children: [
        SectionCard(
          title: 'AI',
          hint: 'settings.ai',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                model == null
                    ? 'The AI features (CV reading, assessments, career map, job search, tailored CVs and '
                          'interview reviews) need a key. The quickest is a free Gemini key: sign in to Google '
                          'AI Studio with your Google account, press Create API key and paste it here. A '
                          'Claude API key from console.anthropic.com works too; Anthropic bills you for use.'
                    : 'Spent about \$${(s?.spend ?? 0).toStringAsFixed(2)} this month on this device at '
                          'list prices; a Gemini key on the free tier costs nothing.',
              ),
              if (model == null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () {
                      openLink(context, geminiKeyPage);
                      _editKey(context, ref, AiProvider.gemini, '');
                    },
                    icon: const Icon(Icons.bolt),
                    label: const Text('Get a free Gemini key'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              for (final p in [AiProvider.gemini, AiProvider.claude])
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (keys[p] ?? '').isEmpty
                            ? '${p.label}: no key'
                            : '${p.label}: key ending ${_tail(keys[p]!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: s == null ? null : () => _editKey(context, ref, p, keys[p] ?? ''),
                      child: Text((keys[p] ?? '').isEmpty ? 'Add key' : 'Change'),
                    ),
                  ],
                ),
              if (s != null && model != null) ...[
                const SizedBox(height: 12),
                Choice<String>(
                  key: ValueKey(model),
                  label: 'Model',
                  value: model,
                  options: {
                    for (final e in aiModels.entries)
                      if ((keys[AiProvider.of(e.key)] ?? '').isNotEmpty) e.key: e.value,
                  },
                  onChanged: (v) => ref.mutate((x) => x.book.setPref(PrefKeys.aiModel, v)),
                ),
                Hint(
                  'settings.routine',
                  child: Choice<String>(
                    label: 'AI routine',
                    value: s.routine,
                    options: _routines,
                    onChanged: (v) => ref.mutate((x) => x.book.setPref(PrefKeys.aiRoutine, v)),
                  ),
                ),
              ],
            ],
          ),
        ),
        SectionCard(
          title: 'Job sites',
          hint: 'settings.feeds',
          trailing: TextButton(
            onPressed: s == null ? null : () => _editFeeds(context, ref, s.feeds),
            child: const Text('Keys'),
          ),
          child: Text(
            [
              'Remotive, Jobicy and Arbeitnow need no key.',
              (s?.feeds.adzunaId.isNotEmpty ?? false)
                  ? 'Adzuna is on.'
                  : 'Adzuna (UK, US, India, Australia, Canada, much of Europe) needs a free key.',
              (s?.feeds.reed.isNotEmpty ?? false) ? 'Reed is on.' : 'Reed (UK) needs a free key.',
              'Sites without an open feed, such as LinkedIn and Indeed, are searched by the AI or opened '
                  'from the Jobs page.',
            ].join(' '),
          ),
        ),
        SectionCard(
          title: 'n8n lead workflow',
          hint: 'settings.n8n',
          trailing: TextButton(
            onPressed: s == null ? null : () => _editN8n(context, ref, s.n8n),
            child: Text(s?.n8n.isSet ?? false ? 'Change' : 'Connect'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s?.n8n.isSet ?? false
                    ? 'Connected to ${Uri.tryParse(s!.n8n.url)?.host ?? s.n8n.url}. Each job\'s Contacts card can '
                          'ask it for people to contact.'
                    : 'Optional: your own n8n workflow that finds recruiters and hiring managers for a job from '
                          'public sources, with your own search and AI keys. You send every connection request '
                          'yourself; nothing is automated on LinkedIn.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openLink(
                    context,
                    'https://github.com/sudharamachandranrajeev/udyoga/blob/main/docs/n8n/README.md',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('How to set it up'),
                ),
              ),
            ],
          ),
        ),
        if (ref.watch(updaterProvider) case final updater?) _UpdateCard(updater),
        const HintsCard(),
        const SyncCard(),
        const SecurityCard(
          network:
              'Nothing leaves the device unless you sign in to sync, refresh jobs (your search terms go to the job '
              'sites) or use an AI feature (your profile and the job go to Google or Anthropic with your key).',
        ),
        const AboutCard(
          description:
              'Career and job search: matched openings, tailored CVs, applications, contacts, career paths, '
              'learning and interview practice.',
        ),
      ],
    );
  }

  static String _tail(String key) => key.length > 4 ? key.substring(key.length - 4) : key;

  Future<void> _editKey(BuildContext context, WidgetRef ref, AiProvider provider, String current) {
    final key = TextEditingController(text: current);
    final gemini = provider == AiProvider.gemini;
    return showFormDialog(
      context,
      title: gemini ? 'Gemini API key' : 'Claude API key',
      fields: (_) => [
        Field(
          key,
          'API key',
          obscure: true,
          autofocus: true,
          hint: gemini ? null : 'sk-ant-…',
          helper:
              '${gemini ? 'Free: sign in to Google AI Studio with your Google account and press Create API key.' : 'Create one at console.anthropic.com > API keys.'} '
              'Synced end-to-end encrypted to your devices. Leave empty to remove it.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                openLink(context, gemini ? geminiKeyPage : 'https://console.anthropic.com/settings/keys'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(gemini ? 'Open Google AI Studio' : 'Open the console'),
          ),
        ),
      ],
      onSave: () async {
        final k = key.text.trim();
        if (k.isNotEmpty && !gemini && !k.startsWith('sk-')) return 'Claude keys start with sk-';
        if (k.isNotEmpty && gemini) {
          try {
            await Gemini(
              apiKey: k,
              model: provider.defaultModel,
              client: ref.read(httpClientProvider),
            ).check();
          } on AiException catch (e) {
            return e.message;
          }
        }
        await ref.mutate((s) => s.book.setPref(gemini ? PrefKeys.geminiKey : PrefKeys.aiKey, k));
        return null;
      },
    );
  }

  Future<void> _editN8n(BuildContext context, WidgetRef ref, N8nLink current) {
    final url = TextEditingController(text: current.url);
    final secret = TextEditingController(text: current.secret);
    return showFormDialog(
      context,
      title: 'n8n lead workflow',
      fields: (_) => [
        Field(
          url,
          'Webhook address',
          autofocus: true,
          hint: 'https://n8n.example.com/webhook/udyoga-leads',
          helper: 'The production URL of the workflow\'s Webhook node. Leave empty to disconnect.',
        ),
        Field(secret, 'Secret', obscure: true, helper: 'The value the workflow checks in X-Udyoga-Secret.'),
      ],
      onSave: () async {
        final u = url.text.trim();
        if (u.isNotEmpty) {
          try {
            N8nLink.check(u);
          } on N8nException catch (e) {
            return e.message;
          }
        }
        await ref.mutate(
          (s) => s.book.setPref(PrefKeys.n8n, N8nLink(url: u, secret: secret.text.trim()).toJson()),
        );
        return null;
      },
    );
  }

  Future<void> _editFeeds(BuildContext context, WidgetRef ref, FeedKeys k) {
    final adzunaId = TextEditingController(text: k.adzunaId);
    final adzunaKey = TextEditingController(text: k.adzunaKey);
    final reed = TextEditingController(text: k.reed);
    return showFormDialog(
      context,
      title: 'Job site keys',
      fields: (_) => [
        Field(adzunaId, 'Adzuna app ID', helper: 'Free at developer.adzuna.com'),
        Field(adzunaKey, 'Adzuna app key', obscure: true),
        Field(reed, 'Reed API key', obscure: true, helper: 'Free at reed.co.uk/developers/jobseeker'),
      ],
      onSave: () async {
        await ref.mutate(
          (s) => s.book.setPref(
            PrefKeys.feedKeys,
            FeedKeys(
              adzunaId: adzunaId.text.trim(),
              adzunaKey: adzunaKey.text.trim(),
              reed: reed.text.trim(),
            ).toJson(),
          ),
        );
        return null;
      },
    );
  }
}

/// This version, and a newer one when GitHub has it, installed from here.
class _UpdateCard extends ConsumerWidget {
  const _UpdateCard(this.updater);
  final Updater updater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final release = update.value;
    return SectionCard(
      title: 'Updates',
      trailing: TextButton(
        onPressed: update.isLoading ? null : () => ref.invalidate(updateProvider),
        child: const Text('Check again'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (update) {
            AsyncLoading() => 'Udyoga ${updater.current}. Looking for a newer version…',
            AsyncError(:final error) => 'Udyoga ${updater.current}. Could not check: $error',
            _ when release == null => 'Udyoga ${updater.current} is the newest version.',
            _ => 'Udyoga ${release.version} is out (this is ${updater.current}).',
          }),
          if (release != null && !update.isLoading) ...[
            if (release.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(release.notes, maxLines: 8, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _install(context, release),
                  icon: const Icon(Icons.system_update_outlined),
                  label: const Text('Update now'),
                ),
                TextButton.icon(
                  onPressed: () => openLink(context, releasesPage),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('All releases'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _install(BuildContext context, Release release) async {
    final said = await runAi(
      context,
      title: 'Updating to ${release.version}',
      status: 'Downloading…',
      task: (progress) async {
        final file = await updater.download(
          release,
          onProgress: (d) => progress('Downloading… ${(d * 100).round()}%'),
        );
        progress('Installing…');
        return updater.install(file);
      },
    );
    if (said == null || !context.mounted) return;
    if (updater.os != 'linux') return showMessage(context, said);
    final restart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Udyoga ${release.version} is installed'),
        content: const Text('Restart Udyoga to use it. Your data stays as it is.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restart now')),
        ],
      ),
    );
    if (restart == true) await Updater.restartLinux();
  }
}
