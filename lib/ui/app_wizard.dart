import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/hub.dart';
import '../domain/models.dart';
import 'accounts_page.dart' show connectProvider;
import 'common.dart';
import 'look.dart';

/// A value the platform's console needs from the hub.
enum _Paste { redirect, webhook, verifyToken }

/// One step of making a developer app: what to do, why, where.
class _Step {
  const _Step(this.title, this.text, {this.link, this.linkLabel = 'Open the page', this.paste = const []});
  final String title, text;
  final String? link;
  final String linkLabel;
  final List<_Paste> paste;
}

/// How to make the user's own app on a platform, written for someone who has
/// never seen a developer console. Each user is the developer of their own
/// app, so no App Review is needed: the app only ever signs in its maker.
class _Guide {
  const _Guide({
    required this.why,
    required this.steps,
    required this.idLabel,
    required this.secretLabel,
    required this.keysWhere,
    this.signInNote,
  });
  final String why, idLabel, secretLabel, keysWhere;
  final String? signInNote;
  final List<_Step> steps;
}

const _guides = {
  OAuthProvider.meta: _Guide(
    why:
        'Facebook and Instagram let only apps post for you, read comments and answer messages. You make your '
        'own small app, used only by you. While it stays in development mode it needs no review by Meta.',
    steps: [
      _Step(
        'Become a Meta developer',
        'Sign in with your Facebook account and follow "Get started" (it asks to confirm your phone or email). '
            'It is free.',
        link: 'https://developers.facebook.com/async/registration',
      ),
      _Step(
        'Create the app',
        'Tap Create app and give it any name, for example "My Vani". When asked what it does, pick the use '
            'cases for managing your Facebook Page and for the Instagram API with Facebook login. If asked for '
            'an app type, pick Business. Leave it in development mode.',
        link: 'https://developers.facebook.com/apps/creation/',
      ),
      _Step(
        'Add your hub\'s sign-in address',
        'In the app, open Facebook Login for Business > Settings and paste this into Valid OAuth Redirect '
            'URIs, then Save. Meta sends you back to your hub with it after you sign in.',
        link: 'https://developers.facebook.com/apps',
        linkLabel: 'Open your apps',
        paste: [_Paste.redirect],
      ),
      _Step(
        'Instant replies (optional)',
        'So comments and messages arrive in seconds instead of within 10 minutes: open Webhooks, choose Page, '
            'paste the callback URL and verify token, tap Verify and save, then subscribe to feed, messages '
            'and mentions. Do the same for Instagram with comments, messages and mentions. You can skip this.',
        paste: [_Paste.webhook, _Paste.verifyToken],
      ),
    ],
    idLabel: 'App ID',
    secretLabel: 'App secret',
    keysWhere: 'In the app, open App settings > Basic. Copy the App ID, then tap Show next to App secret and copy it.',
    signInNote:
        'Instagram must be a Business or Creator account linked to a Facebook Page you manage. When Meta asks, '
        'tick every Page and Instagram account Vani should use.',
  ),
  OAuthProvider.threads: _Guide(
    why:
        'Threads lets only apps post for you and read replies. You make your own small app, used only by you; '
        'in development mode it needs no review. It can be the same Meta app as Facebook and Instagram, with '
        'Threads added.',
    steps: [
      _Step(
        'Create the app',
        'Sign in as a Meta developer, tap Create app and pick the "Access the Threads API" use case. Or open '
            'your existing Vani app and add that use case.',
        link: 'https://developers.facebook.com/apps/creation/',
      ),
      _Step(
        'Add your hub\'s sign-in address',
        'Open Use cases > Access the Threads API > Customize > Settings. Paste this into Redirect Callback '
            'URLs. Meta also asks for Uninstall and Delete callback URLs: paste the same address there.',
        link: 'https://developers.facebook.com/apps',
        linkLabel: 'Open your apps',
        paste: [_Paste.redirect],
      ),
      _Step(
        'Let your Threads profile use it',
        'In development mode only invited testers can sign in. Open App roles > Roles > Add people, choose '
            'Threads Tester and enter your Threads username. Then accept the invite on Threads under Settings > '
            'Account > Website permissions > Invites.',
        link: 'https://www.threads.net/settings/account',
        linkLabel: 'Open Threads settings',
      ),
      _Step(
        'Instant replies (optional)',
        'So replies arrive in seconds: in the Threads use case open Webhooks, paste the callback URL and '
            'verify token, and subscribe to replies and mentions. You can skip this.',
        paste: [_Paste.webhook, _Paste.verifyToken],
      ),
    ],
    idLabel: 'Threads app ID',
    secretLabel: 'Threads app secret',
    keysWhere:
        'Open Use cases > Access the Threads API > Customize > Settings and copy the Threads app ID and Threads '
        'app secret (not the main App ID).',
  ),
  OAuthProvider.google: _Guide(
    why:
        'YouTube lets only apps upload for you and read comments. You make your own Google Cloud project, used '
        'only by you. It is free and needs no review for your own channel.',
    steps: [
      _Step(
        'Create a project',
        'Sign in with the Google account that owns your channel, give the project any name and tap Create.',
        link: 'https://console.cloud.google.com/projectcreate',
      ),
      _Step(
        'Switch on the YouTube API',
        'With the new project selected, tap Enable on "YouTube Data API v3".',
        link: 'https://console.cloud.google.com/apis/library/youtube.googleapis.com',
      ),
      _Step(
        'Describe the sign-in screen',
        'Tap Get started. App name: anything, for example "My Vani". Support and contact email: yours. '
            'Audience: External. Agree and create.',
        link: 'https://console.cloud.google.com/auth/overview',
      ),
      _Step(
        'Publish it',
        'Open Audience and tap Publish app, then Confirm, so it shows "In production". In "Testing" Google signs '
            'you out every 7 days. Google may call it unverified: that is fine for your own use.',
        link: 'https://console.cloud.google.com/auth/audience',
      ),
      _Step(
        'Make the sign-in client',
        'Tap Create client. Application type: Web application. Under Authorized redirect URIs tap Add URI and '
            'paste this, then Create.',
        link: 'https://console.cloud.google.com/auth/clients/create',
        paste: [_Paste.redirect],
      ),
    ],
    idLabel: 'Client ID',
    secretLabel: 'Client secret',
    keysWhere: 'Google shows the Client ID and Client secret when the client is made (or open it under Clients).',
    signInNote:
        'Google warns that it has not verified the app, because you made it. Tap Advanced, then Go to your app, '
        'and allow the YouTube permissions.',
  ),
  OAuthProvider.linkedin: _Guide(
    why:
        'LinkedIn lets only apps post for you. You make your own app, used only by you. LinkedIn ties every app '
        'to a company Page, so you may need a simple one first.',
    steps: [
      _Step(
        'Have a LinkedIn Page',
        'Already run a company or brand Page? Skip this. Otherwise make a simple one (your name or brand is '
            'fine). Vani posts to your own profile either way.',
        link: 'https://www.linkedin.com/company/setup/new/',
        linkLabel: 'Make a Page',
      ),
      _Step(
        'Create the app',
        'Give it a name, pick your Page, add a logo (any square image) and agree. Then on the Settings tab tap '
            'Verify and follow the link as the Page\'s admin.',
        link: 'https://www.linkedin.com/developers/apps/new',
      ),
      _Step(
        'Add what it may do',
        'On the Products tab request "Share on LinkedIn" and "Sign In with LinkedIn using OpenID Connect". Both '
            'are granted at once.',
        link: 'https://www.linkedin.com/developers/apps',
        linkLabel: 'Open your apps',
      ),
      _Step(
        'Add your hub\'s sign-in address',
        'On the Auth tab, under Authorized redirect URLs for your app, tap Add redirect URL, paste this and '
            'Update.',
        paste: [_Paste.redirect],
      ),
    ],
    idLabel: 'Client ID',
    secretLabel: 'Primary Client Secret',
    keysWhere: 'On the Auth tab, copy the Client ID and the Primary Client Secret.',
    signInNote: 'Reading comments needs LinkedIn\'s Community Management API, which LinkedIn approves per app.',
  ),
};

/// How many steps setting up [p] takes, counting the keys and signing in.
int appSetupSteps(OAuthProvider p) => _guides[p]!.steps.length + 2;

/// Opens the guided setup of the user's own developer app for [p], which
/// ends with signing in.
Future<void> openAppWizard(BuildContext context, OAuthProvider p) => Navigator.of(context).push(
  MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => AppWizardPage(provider: p)),
);

class AppWizardPage extends ConsumerStatefulWidget {
  const AppWizardPage({super.key, required this.provider});
  final OAuthProvider provider;

  @override
  ConsumerState<AppWizardPage> createState() => _AppWizardPageState();
}

class _AppWizardPageState extends ConsumerState<AppWizardPage> {
  late final _guide = _guides[widget.provider]!;
  late final _cred = CredentialProvider.values.byName(widget.provider.name);
  final _id = TextEditingController();
  final _secret = TextEditingController();
  var _step = 0;
  var _checking = false;
  String? _checked, _error;

  @override
  void initState() {
    super.initState();
    ref.read(credentialsProvider.future).then((list) {
      final saved = list.where((c) => c.provider == _cred.name).firstOrNull;
      if (mounted && saved?.publicId != null && _id.text.isEmpty) _id.text = saved!.publicId!;
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  int get _keysStep => _guide.steps.length;

  /// Checks the ID and secret with the platform, then saves them on the hub.
  Future<void> _checkAndSave() async {
    final id = _id.text.trim(), secret = _secret.text.trim();
    if (id.isEmpty || secret.isEmpty) {
      setState(() => _error = 'Paste the ${_guide.idLabel} and the ${_guide.secretLabel}.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final detail = await ref.hub(
        (h) => h.checkCredential(_cred, publicId: id, secret: secret),
        refresh: false,
      );
      await ref.hub((h) => h.setCredential(_cred, publicId: id, secret: secret));
      setState(() {
        _checked = detail;
        _step = _keysStep + 1;
      });
    } on HubException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaProvider).value ?? const HubMeta();
    final muted = TextStyle(color: Tone.of(context).muted);
    final p = widget.provider;
    final name = p == OAuthProvider.meta ? 'Facebook & Instagram' : p.label;
    String value(_Paste v) => switch (v) {
      _Paste.redirect => meta.redirectUris[p.name] ?? '',
      _Paste.webhook => p == OAuthProvider.threads ? meta.threadsWebhookUrl : meta.webhookUrl,
      _Paste.verifyToken => meta.verifyToken,
    };
    const labels = {
      _Paste.redirect: 'Redirect URI',
      _Paste.webhook: 'Webhook callback URL',
      _Paste.verifyToken: 'Webhook verify token',
    };
    Step step(int i, String title, List<Widget> body) => Step(
      title: Text(title),
      isActive: _step >= i,
      state: _step > i ? StepState.complete : StepState.indexed,
      content: Align(
        alignment: Alignment.centerLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
      ),
    );
    Widget buttons(List<Widget> b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: b),
    );
    return Scaffold(
      appBar: AppBar(title: Text('Set up $name')),
      body: PageBody(
        maxWidth: 760,
        children: [
          Text(_guide.why, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            'Takes about 10 minutes, once. Keep this window open beside the browser.',
            style: muted,
          ),
          const SizedBox(height: 16),
          Stepper(
            physics: const NeverScrollableScrollPhysics(),
            currentStep: _step,
            onStepTapped: (i) => setState(() => _step = i > _keysStep && _checked == null ? _keysStep : i),
            controlsBuilder: (_, _) => const SizedBox.shrink(),
            steps: [
              for (final (i, s) in _guide.steps.indexed)
                step(i, s.title, [
                  Text(s.text),
                  if (s.paste.isNotEmpty) const SizedBox(height: 12),
                  for (final v in s.paste) Copyable(labels[v]!, value(v)),
                  buttons([
                    if (s.link != null)
                      OutlinedButton.icon(
                        onPressed: () => openLink(context, s.link!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(s.linkLabel),
                      ),
                    FilledButton(
                      onPressed: () => setState(() => _step = i + 1),
                      child: Text(s.title.contains('optional') ? 'Done or skip, next' : 'Done, next'),
                    ),
                  ]),
                ]),
              step(_keysStep, 'Paste the app\'s keys', [
                Text(_guide.keysWhere),
                const SizedBox(height: 12),
                Field(_id, _guide.idLabel),
                Field(_secret, _guide.secretLabel, obscure: true),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                Text(
                  'Vani asks ${p.label} whether they are right, then keeps them on your hub, encrypted. The '
                  'secret is never shown again.',
                  style: muted,
                ),
                buttons([
                  FilledButton(
                    onPressed: _checking ? null : _checkAndSave,
                    child: Text(_checking ? 'Checking…' : 'Check and save'),
                  ),
                ]),
              ]),
              step(_keysStep + 1, 'Sign in with ${p.label}', [
                if (_checked != null)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: growth, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_checked!)),
                    ],
                  ),
                if (_guide.signInNote != null) ...[const SizedBox(height: 8), Text(_guide.signInNote!)],
                buttons([
                  FilledButton.icon(
                    onPressed: _checked == null
                        ? null
                        : () async {
                            await connectProvider(context, ref, p);
                            if (context.mounted) Navigator.pop(context);
                          },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: Text('Sign in with ${p.label}'),
                  ),
                ]),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
