import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/book.dart';
import '../domain/claude.dart';
import '../domain/feeds.dart';
import '../domain/n8n.dart';
import '../ui/common.dart';
import 'providers.dart';

/// Settings for the AI and the job sites, read together.
final _aiSettingsProvider = FutureProvider((ref) async {
  ref.watch(revisionProvider);
  final book = ref.watch(sessionProvider).book;
  return (
    key: await book.pref<String>(PrefKeys.aiKey, ''),
    model: await book.pref<String>(PrefKeys.aiModel, defaultModel),
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
    final key = s?.key ?? '';
    return PageScaffold(
      title: 'Settings',
      children: [
        SectionCard(
          title: 'Claude',
          hint: 'settings.ai',
          trailing: TextButton(
            onPressed: () => _editKey(context, ref, key),
            child: Text(key.isEmpty ? 'Add key' : 'Change'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                key.isEmpty
                    ? 'The AI features (CV reading, assessments, career map, job search, tailored CVs and '
                          'interview reviews) use your own Claude API key from console.anthropic.com. '
                          'You pay Anthropic for what you use.'
                    : 'Key ending ${key.length > 4 ? key.substring(key.length - 4) : key}. '
                          'Spent about \$${(s?.spend ?? 0).toStringAsFixed(2)} this month on this device.',
              ),
              if (s != null) ...[
                const SizedBox(height: 12),
                Choice<String>(
                  label: 'Model',
                  value: s.model,
                  options: aiModels,
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
        const HintsCard(),
        const SyncCard(),
        const SecurityCard(
          network:
              'Nothing leaves the device unless you sign in to sync, refresh jobs (your search terms go to the job '
              'sites) or use an AI feature (your profile and the job go to Anthropic with your key).',
        ),
        const AboutCard(
          description:
              'Career and job search: matched openings, tailored CVs, applications, contacts, career paths, '
              'learning and interview practice.',
        ),
      ],
    );
  }

  Future<void> _editKey(BuildContext context, WidgetRef ref, String current) {
    final key = TextEditingController(text: current);
    return showFormDialog(
      context,
      title: 'Claude API key',
      fields: (_) => [
        Field(
          key,
          'API key',
          obscure: true,
          autofocus: true,
          hint: 'sk-ant-…',
          helper:
              'Create one at console.anthropic.com > API keys. Synced end-to-end encrypted to your devices.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => openLink(context, 'https://console.anthropic.com/settings/keys'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open the console'),
          ),
        ),
      ],
      onSave: () async {
        final k = key.text.trim();
        if (k.isNotEmpty && !k.startsWith('sk-')) return 'Claude keys start with sk-';
        await ref.mutate((s) => s.book.setPref(PrefKeys.aiKey, k));
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
