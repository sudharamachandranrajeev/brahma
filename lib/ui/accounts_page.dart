import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/providers.dart';
import '../domain/hub.dart';
import '../domain/models.dart';
import 'app_wizard.dart';
import 'common.dart';
import 'look.dart';

/// Connected accounts with their sign-in health, ways to connect more, and
/// the developer-app credentials the hub signs in with (never shown back,
/// only whether they are set).
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final t = Theme.of(context).textTheme;
    return PageBody(
      maxWidth: 1200,
      children: [
        PageHeader(
          'Accounts',
          subtitle: accounts.value == null
              ? 'Where Vani posts and listens'
              : '${accounts.value!.length} connected · tokens stay on your hub, encrypted',
        ),
        HubView(
          accounts,
          builder: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    'No accounts yet. Bluesky, Mastodon and Telegram connect in a minute; the others first walk you '
                    'through making your own free app.',
                    style: t.bodyLarge?.copyWith(color: Tone.of(context).muted),
                  ),
                ),
              _Grid(children: [for (final a in list) _AccountCard(account: a)]),
              const SizedBox(height: 28),
              const SectionTitle('Connect'),
              const _Grid(
                min: 260,
                children: [
                  _ConnectCard(provider: OAuthProvider.meta),
                  _ConnectCard(provider: OAuthProvider.google),
                  _ConnectCard(provider: OAuthProvider.linkedin),
                  _ConnectCard(provider: OAuthProvider.threads),
                  _FormCard(platform: Platform.bluesky),
                  _FormCard(platform: Platform.mastodon),
                  _FormCard(platform: Platform.telegram),
                ],
              ),
              const SizedBox(height: 28),
              const _Credentials(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children, this.min = 340});
  final List<Widget> children;
  final double min;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = (box.maxWidth / min).floor().clamp(1, 4);
      final w = (box.maxWidth - 14 * (n - 1)) / n;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final (i, c) in children.indexed)
            SizedBox(
              width: w,
              child: Stagger(i, child: c),
            ),
        ],
      );
    },
  );
}

OAuthProvider? providerOf(Platform p) => switch (p) {
  Platform.instagram || Platform.facebook => OAuthProvider.meta,
  Platform.youtube => OAuthProvider.google,
  Platform.linkedin => OAuthProvider.linkedin,
  Platform.threads => OAuthProvider.threads,
  _ => null,
};

const _capabilityLabels = {
  'publish': 'Publish',
  'comments': 'Comments',
  'messages': 'Messages',
  'mentions': 'Mentions',
  'live': 'Live chat',
  'insights': 'Insights',
  'private_reply': 'Private replies',
};

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = account;
    final t = Theme.of(context).textTheme;
    final (label, color) = switch (a.status) {
      'expiring' => (
        'Expires ${localTime(a.expiresAt) == null ? 'soon' : whenLabel(a.expiresAt).split(',').first}',
        const Color(0xFFF59E0B),
      ),
      'broken' => ('Sign in again', signal),
      _ => ('Connected', growth),
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Avatar(name: a.name, url: a.avatar, size: 52),
                  Positioned(right: -4, bottom: -4, child: PlatformBadge(a.platform, size: 24, ring: true)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      [a.platform.label, if (a.handle.isNotEmpty) a.handle].join(' · '),
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Tag(label, color: color),
            ],
          ),
          if (a.statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(a.statusMessage!, style: t.bodySmall?.copyWith(color: color)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final c in a.capabilities) Tag(_capabilityLabels[c] ?? c)],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (a.status != 'ok' && providerOf(a.platform) != null)
                TextButton.icon(
                  onPressed: () => connectProvider(context, ref, providerOf(a.platform)!),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Reconnect'),
                ),
              Hint(
                'accounts.check',
                child: TextButton.icon(
                  onPressed: () async {
                    Account? checked;
                    final ok = await guarded(
                      context,
                      () async => checked = await ref.hub((h) => h.checkAccount(a.id)),
                    );
                    if (ok && context.mounted) {
                      showMessage(
                        context,
                        checked?.status == 'ok'
                            ? '${a.name} is signed in.'
                            : '${a.name}: ${checked?.statusMessage ?? checked?.status}',
                      );
                    }
                  },
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Check'),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Remove ${a.name}?',
                    message: 'Its scheduled posts will not go out to it, and its replies stop arriving.',
                    action: 'Remove',
                    destructive: true,
                  );
                  if (ok && context.mounted) {
                    await guarded(context, () => ref.hub((h) => h.removeAccount(a.id)));
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<Platform> _platformsOf(OAuthProvider p) => switch (p) {
  OAuthProvider.meta => const [Platform.facebook, Platform.instagram],
  OAuthProvider.google => const [Platform.youtube],
  OAuthProvider.linkedin => const [Platform.linkedin],
  OAuthProvider.threads => const [Platform.threads],
};

class _ConnectCard extends ConsumerWidget {
  const _ConnectCard({required this.provider});
  final OAuthProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final set = ref.watch(credentialsProvider).value?.any((c) => c.provider == provider.name && c.set);
    return Panel(
      onTap: () => connectProvider(context, ref, provider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (i, p) in _platformsOf(provider).indexed)
                Transform.translate(
                  offset: Offset(-10.0 * i, 0),
                  child: PlatformBadge(p, size: 42, ring: i > 0),
                ),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, color: Tone.of(context).muted),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            provider == OAuthProvider.meta ? 'Facebook & Instagram' : provider.label,
            style: t.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(provider.brings, style: t.bodySmall),
          if (set == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                children: [
                  const Tag('Ready', color: growth, icon: Icons.check_rounded),
                  TextButton(onPressed: () => openAppWizard(context, provider), child: const Text('Setup steps')),
                ],
              ),
            ),
          if (set == false) ...[
            const SizedBox(height: 8),
            Tag(
              'Set up · ${appSetupSteps(provider)} steps',
              color: const Color(0xFFF59E0B),
              icon: Icons.construction_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _FormCard extends ConsumerWidget {
  const _FormCard({required this.platform});
  final Platform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Panel(
      onTap: () => switch (platform) {
        Platform.bluesky => _addBluesky(context, ref),
        Platform.telegram => _addTelegram(context, ref),
        _ => _addMastodon(context, ref),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlatformBadge(platform, size: 42),
              const Spacer(),
              Icon(Icons.add_rounded, color: Tone.of(context).muted),
            ],
          ),
          const SizedBox(height: 14),
          Text(platform.label, style: t.titleMedium),
          const SizedBox(height: 2),
          Text(switch (platform) {
            Platform.bluesky => 'With an app password',
            Platform.telegram => 'A channel or group, with your bot',
            _ => 'Sign in on your server',
          }, style: t.bodySmall),
        ],
      ),
    );
  }

  Future<void> _addBluesky(BuildContext context, WidgetRef ref) async {
    final handle = TextEditingController();
    final password = TextEditingController();
    final service = TextEditingController();
    final ok = await showFormDialog(
      context,
      title: 'Add Bluesky',
      action: 'Add',
      fields: (_) => [
        const Text(
          'Create an app password in Bluesky under Settings > Privacy and security > App passwords.',
        ),
        const SizedBox(height: 16),
        Field(handle, 'Handle', hint: 'you.bsky.social'),
        Field(password, 'App password', hint: 'xxxx-xxxx-xxxx-xxxx', obscure: true),
        Field(service, 'Server (optional)', hint: 'https://bsky.social'),
      ],
      onSave: () async {
        if (handle.text.trim().isEmpty || password.text.trim().isEmpty) {
          return 'Enter the handle and app password.';
        }
        await ref.hub(
          (h) => h.addBluesky(
            handle: handle.text.trim().replaceFirst('@', ''),
            appPassword: password.text.trim(),
            service: service.text.trim().isEmpty ? null : service.text.trim(),
          ),
        );
        return null;
      },
    );
    if (ok && context.mounted) showMessage(context, 'Bluesky connected.');
  }

  /// One click: the hub registers itself on the server, then the user signs
  /// in there. An access token is the fallback.
  Future<void> _addMastodon(BuildContext context, WidgetRef ref) async {
    final instance = TextEditingController();
    var useToken = false;
    final ok = await showFormDialog(
      context,
      title: 'Add Mastodon',
      action: 'Sign in',
      fields: (_) => [
        const Text('Enter your server, then sign in there. Vani registers itself on the server for you.'),
        const SizedBox(height: 16),
        Field(instance, 'Server', hint: 'mastodon.social'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              useToken = true;
              Navigator.pop(context, false);
            },
            child: const Text('Use an access token instead'),
          ),
        ),
      ],
      onSave: () async => _host(instance.text).isEmpty ? 'Enter your server.' : null,
    );
    if (!context.mounted) return;
    if (useToken) return _addMastodonToken(context, ref);
    if (ok) await signIn(context, ref, 'Mastodon', (h) => h.connectMastodon(_host(instance.text)));
  }

  static String _host(String text) =>
      text.trim().replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), '').replaceFirst(RegExp(r'^@?[^@]*@'), '');

  Future<void> _addMastodonToken(BuildContext context, WidgetRef ref) async {
    final instance = TextEditingController();
    final token = TextEditingController();
    final ok = await showFormDialog(
      context,
      title: 'Add Mastodon with a token',
      action: 'Add',
      fields: (_) => [
        const Text(
          'On your server, open Preferences > Development > New application, tick read and write, save, '
          'then copy "Your access token".',
        ),
        const SizedBox(height: 16),
        Field(instance, 'Server', hint: 'mastodon.social'),
        Field(token, 'Access token', obscure: true),
      ],
      onSave: () async {
        if (instance.text.trim().isEmpty || token.text.trim().isEmpty) return 'Enter the server and token.';
        await ref.hub((h) => h.addMastodon(instance: _host(instance.text), accessToken: token.text.trim()));
        return null;
      },
    );
    if (ok && context.mounted) showMessage(context, 'Mastodon connected.');
  }

  Future<void> _addTelegram(BuildContext context, WidgetRef ref) async {
    final token = TextEditingController();
    final chat = TextEditingController();
    final ok = await showFormDialog(
      context,
      title: 'Add Telegram',
      action: 'Add',
      fields: (_) => [
        const Text(
          'Make a bot with @BotFather and copy its token. Add the bot as an admin of your channel with '
          '"Post messages", and as an admin of the channel\'s discussion group so comments reach the inbox. '
          'Use one bot per channel.',
        ),
        const SizedBox(height: 16),
        Field(token, 'Bot token', hint: '123456789:AA...', obscure: true),
        Field(chat, 'Channel or group', hint: '@yourchannel, t.me/yourchannel or -100...'),
      ],
      onSave: () async {
        if (token.text.trim().isEmpty || chat.text.trim().isEmpty) {
          return 'Enter the bot token and the channel.';
        }
        await ref.hub((h) => h.addTelegram(botToken: token.text.trim(), chat: chat.text.trim()));
        return null;
      },
    );
    if (ok && context.mounted) showMessage(context, 'Telegram connected.');
  }
}

/// Starts an OAuth sign-in. Without the app credentials it opens the guided
/// setup of the user's own app instead, which ends here.
Future<void> connectProvider(BuildContext context, WidgetRef ref, OAuthProvider p) async {
  final creds = await ref.read(credentialsProvider.future).catchError((_) => const <CredentialStatus>[]);
  if (!context.mounted) return;
  if (!creds.any((c) => c.provider == p.name && c.set)) return openAppWizard(context, p);
  await signIn(context, ref, p.label, (h) => h.connect(p));
}

/// Opens the sign-in page [start] gets from the hub in the browser, then
/// watches the hub for the new accounts its callback stores.
Future<void> signIn(BuildContext context, WidgetRef ref, String label, Future<String> Function(HubClient h) start) async {
  final before = {for (final a in await ref.read(accountsProvider.future)) a.id};
  final String url;
  try {
    url = await ref.hub(start, refresh: false);
  } catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!context.mounted) return;
  if (!opened) {
    await copyText(context, url, what: 'Could not open a browser; the sign-in link is copied.');
    if (!context.mounted) return;
  }
  final found = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _Waiting(label: label, before: before),
  );
  ref.read(hubRevisionProvider.notifier).bump();
  if (found != null && found > 0 && context.mounted) {
    showMessage(context, '$found ${found == 1 ? 'account' : 'accounts'} connected.');
  }
}

/// Polls the hub's accounts until new ones appear (up to five minutes).
class _Waiting extends ConsumerStatefulWidget {
  const _Waiting({required this.label, required this.before});
  final String label;
  final Set<String> before;

  @override
  ConsumerState<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends ConsumerState<_Waiting> {
  late final Timer _timer;
  var _ticks = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (++_ticks > 100) return _close(0);
    try {
      final hub = await ref.read(hubProvider.future);
      final now = await hub!.accounts();
      final added = now.where((a) => !widget.before.contains(a.id)).length;
      if (added > 0) _close(added);
    } catch (_) {
      // Keep waiting; the dialog says what to do.
    }
  }

  void _close(int n) {
    _timer.cancel();
    if (mounted) Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Signing in to ${widget.label}'),
    content: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(),
        SizedBox(height: 16),
        Text('Finish signing in in your browser. This closes by itself when the accounts arrive.'),
      ],
    ),
    actions: [TextButton(onPressed: () => _close(0), child: const Text('Cancel'))],
  );
}

// ---- credentials ----

class _CredInfo {
  const _CredInfo(this.title, this.icon, this.publicLabel, this.secretLabel, this.console, this.steps);
  final String title;
  final IconData icon;
  final String? publicLabel;
  final String secretLabel, console;
  final List<String> steps;
}

final _creds = {
  CredentialProvider.meta: _CredInfo(
    'Meta (Facebook & Instagram)',
    FontAwesomeIcons.meta.data,
    'App ID',
    'App secret',
    'https://developers.facebook.com/apps',
    [
      'Create an app of type Business.',
      'Add Facebook Login for Business, the Instagram API (with Facebook login) and Webhooks.',
      'Under Facebook Login > Settings, paste the redirect URI below into Valid OAuth Redirect URIs.',
      'Under Webhooks, subscribe the Page and Instagram objects to the callback URL and verify token below '
          '(fields: feed, comments, messages, mentions).',
      'Copy the App ID and App secret from App settings > Basic.',
    ],
  ),
  CredentialProvider.threads: _CredInfo(
    'Threads',
    FontAwesomeIcons.threads.data,
    'Threads app ID',
    'Threads app secret',
    'https://developers.facebook.com/apps',
    [
      'Create an app with the "Access the Threads API" use case.',
      'Add the redirect URI below to the Threads redirect callback URLs.',
      'Subscribe Threads webhooks (replies, mentions) to the callback URL below.',
      'Copy the Threads app ID and secret from the use case settings.',
    ],
  ),
  CredentialProvider.google: _CredInfo(
    'Google (YouTube)',
    FontAwesomeIcons.google.data,
    'Client ID',
    'Client secret',
    'https://console.cloud.google.com/apis/credentials',
    [
      'Create a Google Cloud project and enable the YouTube Data API v3.',
      'Configure the OAuth consent screen (External) and add your Google account as a test user.',
      'Create an OAuth client ID of type Web application with the redirect URI below.',
      'Copy the client ID and secret.',
    ],
  ),
  CredentialProvider.linkedin: _CredInfo(
    'LinkedIn',
    FontAwesomeIcons.linkedinIn.data,
    'Client ID',
    'Client secret',
    'https://www.linkedin.com/developers/apps',
    [
      'Create an app linked to a LinkedIn Page.',
      'Under Products, add "Sign In with LinkedIn using OpenID Connect" and "Share on LinkedIn".',
      'Under Auth, add the redirect URI below.',
      'Reading comments needs the Community Management API, which LinkedIn approves per app.',
    ],
  ),
  CredentialProvider.ebay: _CredInfo(
    'eBay (discovery)',
    FontAwesomeIcons.ebay.data,
    'App ID (Client ID)',
    'Cert ID (Client secret)',
    'https://developer.ebay.com/my/keys',
    [
      'Join the eBay Developers Program and create a Production keyset.',
      'Copy the App ID and Cert ID. Discovery searches public listings with them.',
    ],
  ),
  CredentialProvider.anthropic: _CredInfo(
    'Anthropic (Claude)',
    Icons.auto_awesome_rounded,
    null,
    'API key',
    'https://console.anthropic.com/settings/keys',
    [
      'Sign in to the Claude Console (a separate account from a Claude.ai subscription) and add credit under Billing.',
      'Create an API key and paste it below. You pay Anthropic for what you use.',
    ],
  ),
  CredentialProvider.openai: _CredInfo(
    'OpenAI (GPT)',
    Icons.auto_awesome_rounded,
    null,
    'API key',
    'https://platform.openai.com/api-keys',
    [
      'Sign in to the OpenAI Platform (separate from a ChatGPT plan) and add credit under Billing.',
      'Create a secret key and paste it below. You pay OpenAI for what you use.',
    ],
  ),
  CredentialProvider.gemini: _CredInfo(
    'Google Gemini',
    FontAwesomeIcons.google.data,
    null,
    'API key',
    'https://aistudio.google.com/apikey',
    [
      'Sign in to Google AI Studio with your Google account.',
      'Create an API key and paste it below. The free tier needs no card; Google may use free-tier requests to '
          'improve its products.',
    ],
  ),
  CredentialProvider.openrouter: _CredInfo(
    'OpenRouter',
    Icons.hub_rounded,
    null,
    'API key',
    'https://openrouter.ai/settings/keys',
    [
      'OpenRouter reaches many AI models (some free) with one key.',
      'Create a key and paste it below, then pick a model.',
    ],
  ),
  CredentialProvider.compatible: _CredInfo(
    'Other AI service',
    Icons.dns_rounded,
    'API address (https, ending in /v1)',
    'API key',
    'https://platform.openai.com/docs/api-reference/chat',
    [
      'Any service with an OpenAI-compatible API (Groq, Mistral, Together, DeepSeek...).',
      'The hub runs on the internet, so the address must be public https. Ollama on this computer is set up '
          'under "On this computer" instead.',
    ],
  ),
};

String credentialTitle(CredentialProvider p) => _creds[p]!.title;
IconData credentialIcon(CredentialProvider p) => _creds[p]!.icon;

class _Credentials extends ConsumerWidget {
  const _Credentials();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = {
      for (final c in ref.watch(credentialsProvider).value ?? const <CredentialStatus>[]) c.provider: c,
    };
    final t = Theme.of(context).textTheme;
    final tone = Tone.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('App credentials'),
          Text(
            'Your own developer apps, so the platforms deal with you directly. Secrets are encrypted on the hub '
            'and never sent back.',
            style: t.bodyMedium?.copyWith(color: tone.muted),
          ),
          const SizedBox(height: 12),
          for (final p in CredentialProvider.values.where((p) => !p.ai))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tone.cardHigh, borderRadius: BorderRadius.circular(12)),
                child: Icon(_creds[p]!.icon, size: 18, color: tone.text),
              ),
              title: Text(_creds[p]!.title),
              subtitle: Text(
                status[p.name]?.set ?? false
                    ? ['Set', if (status[p.name]!.publicId != null) status[p.name]!.publicId!].join(' · ')
                    : 'Not set',
              ),
              trailing: Icon(
                status[p.name]?.set ?? false
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: status[p.name]?.set ?? false ? growth : tone.muted,
              ),
              onTap: () => editCredential(context, ref, p),
            ),
        ],
      ),
    );
  }
}

/// The credential editor, with the console steps, the redirect URI and
/// (for Meta and Threads) the webhook to paste there.
Future<void> editCredential(BuildContext context, WidgetRef ref, CredentialProvider p) async {
  final info = _creds[p]!;
  final meta = await ref.read(metaProvider.future).catchError((_) => const HubMeta());
  final status = (await ref.read(credentialsProvider.future).catchError((_) => const <CredentialStatus>[]))
      .where((c) => c.provider == p.name)
      .firstOrNull;
  if (!context.mounted) return;
  final publicId = TextEditingController(text: status?.publicId ?? '');
  final secret = TextEditingController();
  final redirect = meta.redirectUris[p.name];
  final webhook = switch (p) {
    CredentialProvider.meta => meta.webhookUrl,
    CredentialProvider.threads => meta.threadsWebhookUrl,
    _ => '',
  };
  final t = Theme.of(context).textTheme;
  final saved = await showFormDialog(
    context,
    title: info.title,
    width: 600,
    fields: (_) => [
      for (final (i, s) in info.steps.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text('${i + 1}.', style: t.bodyMedium?.copyWith(color: signal)),
              ),
              Expanded(child: Text(s)),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => openLink(context, info.console),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(p.ai ? 'Get a key' : 'Open the developer console'),
        ),
      ),
      if (redirect != null && redirect.isNotEmpty)
        Copyable('Redirect URI', redirect, hint: 'credentials.redirect'),
      if (webhook.isNotEmpty) ...[
        Copyable('Webhook callback URL', webhook),
        Copyable('Webhook verify token', meta.verifyToken),
      ],
      const SizedBox(height: 8),
      if (info.publicLabel != null) Field(publicId, info.publicLabel!),
      Field(
        secret,
        info.secretLabel,
        obscure: true,
        helper: status?.set ?? false ? 'Leave as is? Cancel. A new value replaces the stored one.' : null,
      ),
      if (status?.set ?? false)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final ok = await confirm(
                context,
                title: 'Remove ${info.title} credentials?',
                message: p.ai
                    ? 'The hub stops using ${info.title} for AI.'
                    : 'Accounts connected through them keep working until their tokens expire.',
                action: 'Remove',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              if (await guarded(context, () => ref.hub((h) => h.deleteCredential(p))) && context.mounted) {
                Navigator.pop(context, false);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Remove'),
          ),
        ),
    ],
    onSave: () async {
      if (info.publicLabel != null && publicId.text.trim().isEmpty) return 'Enter the ${info.publicLabel}.';
      if (secret.text.trim().isEmpty) return 'Enter the ${info.secretLabel}.';
      await ref.hub(
        (h) => h.setCredential(
          p,
          publicId: info.publicLabel == null ? null : publicId.text.trim(),
          secret: secret.text.trim(),
        ),
      );
      return null;
    },
  );
  if (saved && context.mounted) showMessage(context, '${info.title} saved.');
}
