import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/book.dart';
import '../domain/ai.dart';
import '../domain/feeds.dart';
import '../domain/gemini.dart';
import '../domain/n8n.dart';
import '../domain/subscription.dart';
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
                    ? 'The AI features (CV reading, assessments, career map, job search, tailored CVs, '
                          'interview reviews and the LinkedIn studio) need a key. The quickest is a free Gemini '
                          'key: sign in to Google AI Studio with your Google account, press Create API key and '
                          'paste it here. A Claude API key from console.anthropic.com works too; Anthropic bills '
                          'you for use.${SubscriptionCli.supported ? ' With a Claude Pro or Max plan, connect it '
                                    'through Claude Code instead; with a ChatGPT plan, through Codex.' : ''}'
                    : 'Spent about \$${(s?.spend ?? 0).toStringAsFixed(2)} this month on this device at '
                          'list prices; a Gemini key on the free tier and your Claude or ChatGPT subscription '
                          'cost nothing more.',
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
              if (SubscriptionCli.supported)
                for (final p in subscriptionClis.keys) _SubscriptionRow(p),
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
        const AppLockCard(),
        const HintsCard(),
        const SyncCard(),
        const SecurityCard(
          network:
              'Nothing leaves the device unless you sign in to sync, refresh jobs (your search terms go to the job '
              'sites) or use an AI feature (your profile and the job go to Google, Anthropic or OpenAI with your key '
              'or plan).',
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

/// Whether Udyoga looks for a new version at start, on this device.
final _updateOnStartProvider = FutureProvider<bool>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(sessionProvider).book.updateOnStart();
});

/// This version, and a newer one when GitHub has it, installed from here.
class _UpdateCard extends ConsumerWidget {
  const _UpdateCard(this.updater);
  final Updater updater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final release = update.value;
    final onStart = ref.watch(_updateOnStartProvider).value ?? true;
    final asked = ref.watch(updateAskedProvider);
    return SectionCard(
      title: 'Updates',
      trailing: TextButton(
        onPressed: update.isLoading
            ? null
            : () {
                ref.read(updateAskedProvider.notifier).ask();
                ref.invalidate(updateProvider);
              },
        child: Text(asked || onStart ? 'Check again' : 'Check now'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (update) {
            AsyncLoading() => 'Udyoga ${updater.current}. Looking for a newer version…',
            AsyncError(:final error) => 'Udyoga ${updater.current}. Could not check: $error',
            _ when release == null && !asked && !onStart => 'Udyoga ${updater.current}.',
            _ when release == null => 'Udyoga ${updater.current} is the newest version.',
            _ => 'Udyoga ${release.version} is out (this is ${updater.current}).',
          }),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Look for updates when Udyoga starts'),
            subtitle: const Text('Asks before anything is downloaded.'),
            value: onStart,
            onChanged: (v) => ref.mutate((s) => s.book.setUpdateOnStart(v)),
          ),
          if (release != null && !update.isLoading) ...[
            if (release.notes.isNotEmpty) ...[
              Text(release.notes, maxLines: 8, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => installUpdate(context, updater, release),
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
}

/// Asks whether to install [release] now; installs it on yes.
Future<void> offerUpdate(BuildContext context, Updater updater, Release release) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Udyoga ${release.version} is out'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Text(
          [
            'You have ${updater.current}. Update now? Your data stays as it is.',
            if (release.notes.isNotEmpty) release.notes,
          ].join('\n\n'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update now')),
      ],
    ),
  );
  if (go == true && context.mounted) await installUpdate(context, updater, release);
}

/// Downloads, checks and installs [release], then offers a restart on Linux.
Future<void> installUpdate(BuildContext context, Updater updater, Release release) async {
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

/// A subscription in the AI card: who it is signed in as and for how long
/// Udyoga may use it.
class _SubscriptionRow extends ConsumerWidget {
  const _SubscriptionRow(this.provider);
  final AiProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cli = subscriptionClis[provider]!;
    final grant = ref.watch(grantProvider(provider)).value;
    final active = grant != null && grant.activeAt(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: Text(switch (grant) {
            null => '${provider.label}: not connected',
            _ when active =>
              '${provider.label}: ${grant.account.isEmpty ? 'connected' : grant.account} through ${cli.app}, '
                  'until ${niceDateTime(grant.expires.toLocal().toIso8601String())}',
            _ => '${provider.label}: the 24 hours are up',
          }),
        ),
        if (grant != null)
          TextButton(
            onPressed: () => ref.mutate((s) => s.book.setGrant(provider, null)),
            child: const Text('Disconnect'),
          ),
        if (!active)
          TextButton(
            onPressed: () => connectSubscription(context, ref, provider),
            child: Text(grant == null ? 'Connect' : 'Reconnect'),
          ),
      ],
    );
  }
}

/// Lets Udyoga use the subscription [provider] that this device's CLI
/// (Claude Code or Codex) is signed in to, for 24 hours. Signing in happens
/// in the CLI's own flow, in a terminal; Udyoga only asks the CLI who is
/// signed in. Returns whether access was given.
Future<bool> connectSubscription(BuildContext context, WidgetRef ref, AiProvider provider) async {
  final cli = subscriptionClis[provider]!;
  final exe = cli.locate();
  if (exe == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${cli.app} is not installed'),
        content: Text(
          'Udyoga uses your ${cli.plan} subscription through ${cli.app}, ${cli.maker}\'s own app, so your '
          '${cli.plan} password and sign-in never pass through Udyoga. Install ${cli.app}, then connect again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () => openLink(context, cli.installPage),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('How to install it'),
          ),
        ],
      ),
    );
    return false;
  }
  while (true) {
    if (!context.mounted) return false;
    final auth = await runAi(
      context,
      title: provider.label,
      status: 'Asking ${cli.app} who is signed in…',
      task: (_) => cli.status(exe),
    );
    if (auth == null || !context.mounted) return false;
    if (auth.loggedIn && auth.subscription) {
      final allow = await confirm(
        context,
        title: 'Use your ${cli.plan} subscription?',
        message:
            'Udyoga will run ${cli.app}, signed in as ${auth.account.isEmpty ? 'your ${cli.plan} account' : auth.account}, '
            'for its AI features for the next 24 hours. Requests count towards your plan\'s usage limits. After 24 '
            'hours Udyoga stops and asks again when it starts.',
        action: 'Allow for 24 hours',
      );
      if (!allow) return false;
      final first = await ref.read(sessionProvider).book.grant(provider) == null;
      await ref.mutate((s) async {
        await s.book.setGrant(
          provider,
          SubscriptionGrant(at: DateTime.now().toUtc(), account: auth.account, exe: exe),
        );
        // A first connection switches the AI to the subscription; the model
        // can be changed below.
        if (first) await s.book.setPref(PrefKeys.aiModel, provider.defaultModel);
      });
      if (context.mounted) showMessage(context, 'Connected for 24 hours.');
      return true;
    }
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign in to ${cli.app}'),
        content: Text(
          '${auth.loggedIn ? '${cli.app} is signed in with an API key, not a ${cli.plan} plan (${cli.plans}).' : '${cli.app} is not signed in.'} '
          'Udyoga opens ${cli.app}\'s own sign-in in a terminal: choose your ${cli.plan} account there and finish '
          'in the browser. Then come back and press "I have signed in".\n\n'
          'Or run this yourself:\n${cli.signInCommand(exe)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'check'), child: const Text('I have signed in')),
          FilledButton(onPressed: () => Navigator.pop(context, 'open'), child: const Text('Open sign-in')),
        ],
      ),
    );
    if (next == null || !context.mounted) return false;
    if (next == 'open') {
      if (!await cli.openSignIn(exe) && context.mounted) {
        await copyText(
          context,
          cli.signInCommand(exe),
          what: 'No terminal found. The command is copied.',
        );
      }
      if (!context.mounted) return false;
      final done = await confirm(
        context,
        title: 'Finish signing in',
        message: 'Complete the sign-in in the terminal and your browser, then continue.',
        action: 'I have signed in',
      );
      if (!done) return false;
    }
  }
}
