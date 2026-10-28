import 'dart:io';

import 'json.dart';

/// How long Udyoga may use a subscription before the user has to allow it
/// again.
const subscriptionGrantLength = Duration(hours: 24);

/// Shown when a request is made after the grant for [plan] ('Claude',
/// 'ChatGPT') has lapsed.
String subscriptionExpired(String plan) =>
    'Udyoga\'s 24-hour access to your $plan subscription has ended. Reconnect it in Settings.';

/// The user's permission for Udyoga to run this device's subscription CLI
/// (Claude Code or Codex): when it was given, the account the CLI was signed
/// in to then, and where the CLI is. It lapses after
/// [subscriptionGrantLength]; Udyoga then asks again at start. Kept on this
/// device only.
class SubscriptionGrant {
  const SubscriptionGrant({required this.at, required this.account, required this.exe});

  factory SubscriptionGrant.fromJson(Json j) => SubscriptionGrant(
    at: DateTime.tryParse(str(j['at']))?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    account: str(j['account']),
    exe: str(j['exe']),
  );

  final DateTime at;
  final String account;
  final String exe;

  DateTime get expires => at.add(subscriptionGrantLength);
  bool activeAt(DateTime now) => now.isBefore(expires);

  Json toJson() => {'at': at.toUtc().toIso8601String(), 'account': account, 'exe': exe};
}

/// What a CLI reports about its sign-in. [subscription] is true when it is
/// signed in to a plan rather than with an API key.
typedef CliAuth = ({bool loggedIn, bool subscription, String account});

typedef StartProcess = Future<Process> Function(
  String exe,
  List<String> args, {
  String? workingDirectory,
  bool runInShell,
});

Future<Process> startProcess(
  String exe,
  List<String> args, {
  String? workingDirectory,
  bool runInShell = false,
}) => Process.start(exe, args, workingDirectory: workingDirectory, runInShell: runInShell);

/// A vendor's own, unmodified command-line app that Udyoga runs to use the
/// user's subscription. Vendors do not let other apps sign in to their plans
/// or hold their tokens, so Udyoga never does: the CLI signs in through the
/// vendor's own flow and keeps its credentials to itself.
abstract class SubscriptionCli {
  const SubscriptionCli();

  /// The desktop platforms these CLIs run on that Udyoga ships for.
  static bool get supported => Platform.isLinux || Platform.isWindows;

  /// The CLI's name ('Claude Code'), its plan ('Claude') and its maker
  /// ('Anthropic'), for the user.
  String get app;
  String get plan;
  String get maker;

  /// The plans that include it, for the user ('Claude Pro or Max').
  String get plans;
  String get installPage;

  /// The executable's name without an extension.
  String get command;

  /// The arguments that start the CLI's own sign-in to a plan.
  List<String> get signInArgs;

  /// Asks the CLI who is signed in.
  Future<CliAuth> status(String exe, {StartProcess start = startProcess});

  /// Where the CLI is installed, or null. Apps started from a menu often get
  /// a shorter PATH than a terminal, so the usual install places are tried
  /// too.
  String? locate({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final windows = Platform.isWindows;
    final home = env[windows ? 'USERPROFILE' : 'HOME'] ?? '';
    final sep = windows ? r'\' : '/';
    final names = windows ? ['$command.exe', '$command.cmd'] : [command];
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
        '/home/linuxbrew/.linuxbrew/bin',
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

  /// The command that signs the CLI in to a plan.
  String signInCommand(String exe) => ['"$exe"', ...signInArgs].join(' ');

  /// Opens a terminal running the CLI's own sign-in. False when no terminal
  /// could be started (the user then runs [signInCommand] by hand).
  Future<bool> openSignIn(String exe) async {
    final login = [exe, ...signInArgs];
    final tries = Platform.isWindows
        ? [
            ['cmd', '/c', 'start', '$app sign-in', 'cmd', '/k', ...login],
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
}

/// Whether [exe] has to be started through the shell (a Windows .cmd shim).
bool runsInShell(String exe) => Platform.isWindows && !exe.toLowerCase().endsWith('.exe');

String lastLine(String s) => s.trim().split('\n').last.trim();
