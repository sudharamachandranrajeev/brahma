import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../ui/widgets.dart' show Status;
import 'sentinel.dart';

/// What the device says about its own protection. A fact is null when this
/// platform cannot tell (or the answer needs administrator rights), and a
/// null never becomes a finding: Sentinel only reports what it knows.
class DeviceFacts {
  const DeviceFacts({this.diskEncrypted, this.firewall, this.screenLock, this.antivirus, this.patched});

  /// The disk holding the system is encrypted.
  final bool? diskEncrypted;
  final bool? firewall;
  final bool? screenLock;

  /// Windows Defender (or another antivirus) is on.
  final bool? antivirus;

  /// Day (yyyy-MM-dd) of the newest security update installed.
  final String? patched;
}

/// Runs a program; tests replace it.
typedef Runner = Future<ProcessResult> Function(String exe, List<String> args);

Future<ProcessResult> _run(String exe, List<String> args) =>
    Process.run(exe, args).timeout(const Duration(seconds: 15));

/// Whether the file system mounted at `/` sits on LUKS, from `lsblk -J`
/// output; null when `/` is not in it. A crypt device may hold LVM volumes
/// below it, so any crypt ancestor counts.
bool? rootEncrypted(String lsblkJson) {
  bool? walk(Object? nodes, bool underCrypt) {
    for (final n in nodes is List ? nodes : const []) {
      if (n is! Map) continue;
      final crypt = underCrypt || n['type'] == 'crypt';
      final mounts = n['mountpoints'];
      if ((mounts is List && mounts.contains('/')) || n['mountpoint'] == '/') return crypt;
      final inner = walk(n['children'], crypt);
      if (inner != null) return inner;
    }
    return null;
  }

  try {
    return walk((jsonDecode(lsblkJson) as Map)['blockdevices'], false);
  } on Object {
    return null;
  }
}

/// Whether a firewall service runs, from `systemctl is-active` output for
/// several units (one state per line).
bool firewallActive(String states) => states.split('\n').any((s) => s.trim() == 'active');

const _months = 'JanFebMarAprMayJunJulAugSepOctNovDec';

/// The day the running kernel was built, from `uname -v`, as YYYY-MM-DD:
/// on Linux the nearest thing to a security patch date, since distributions
/// rebuild the kernel with its fixes. Null when the text has no date.
String? kernelBuilt(String unameV) {
  String day(String y, int m, String d) => '$y-${'$m'.padLeft(2, '0')}-${d.padLeft(2, '0')}';
  final iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(unameV);
  if (iso != null) return day(iso[1]!, int.parse(iso[2]!), iso[3]!);
  const mon = '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)';
  // Arch: "Sat, 17 Oct 2026 22:09:33 +0000".
  final dmy = RegExp('\\b(\\d{1,2}) $mon (\\d{4})\\b').firstMatch(unameV);
  if (dmy != null) return day(dmy[3]!, _months.indexOf(dmy[2]!) ~/ 3 + 1, dmy[1]!);
  // Ubuntu, Fedora: "Fri Aug 30 12:02:04 UTC 2024".
  final mdy = RegExp('\\b$mon +(\\d{1,2}) [\\d:]+ \\S+ (\\d{4})\\b').firstMatch(unameV);
  if (mdy != null) return day(mdy[3]!, _months.indexOf(mdy[1]!) ~/ 3 + 1, mdy[2]!);
  return null;
}

Future<DeviceFacts> _linux(Runner run) async {
  bool? disk, firewall;
  String? patched;
  try {
    final r = await run('lsblk', ['-J', '-o', 'NAME,TYPE,MOUNTPOINTS']);
    if (r.exitCode == 0) disk = rootEncrypted('${r.stdout}');
  } on Object {
    // No lsblk: unknown.
  }
  try {
    // Exit code is non-zero when none is active, so only the text counts.
    final r = await run('systemctl', ['is-active', 'ufw', 'firewalld', 'nftables']);
    firewall = firewallActive('${r.stdout}');
  } on Object {
    // No systemd: unknown.
  }
  try {
    final r = await run('uname', ['-v']);
    if (r.exitCode == 0) patched = kernelBuilt('${r.stdout}');
  } on Object {
    // Unknown.
  }
  return DeviceFacts(diskEncrypted: disk, firewall: firewall, patched: patched);
}

/// Defender's state and the newest hotfix day, from one PowerShell call.
const _windowsScript = r'''
$d = Get-MpComputerStatus -ErrorAction SilentlyContinue
$h = Get-HotFix -ErrorAction SilentlyContinue | Where-Object InstalledOn | Sort-Object InstalledOn -Descending | Select-Object -First 1
@{
  av = if ($d) { [bool]($d.AntivirusEnabled -and $d.RealTimeProtectionEnabled) } else { $null }
  patched = if ($h) { $h.InstalledOn.ToString('yyyy-MM-dd') } else { $null }
} | ConvertTo-Json -Compress
''';

Future<DeviceFacts> _windows(Runner run) async {
  try {
    final r = await run('powershell', ['-NoProfile', '-NonInteractive', '-Command', _windowsScript]);
    final j = jsonDecode('${r.stdout}'.trim());
    if (r.exitCode == 0 && j is Map) {
      return DeviceFacts(antivirus: j['av'] as bool?, patched: j['patched'] as String?);
    }
  } on Object {
    // Unknown.
  }
  return const DeviceFacts();
}

/// Android's answers, from MainActivity (`<package>/device`).
Future<DeviceFacts> _android(String package) async {
  try {
    final j = await MethodChannel('$package/device').invokeMapMethod<String, Object?>('security');
    if (j == null) return const DeviceFacts();
    return DeviceFacts(
      diskEncrypted: j['encrypted'] as bool?,
      screenLock: j['screenLock'] as bool?,
      patched: j['patched'] as String?,
    );
  } on Object {
    return const DeviceFacts();
  }
}

/// Reads the facts on this device; tests override it.
final deviceFactsProvider = FutureProvider<DeviceFacts>((ref) async {
  if (Platform.isLinux) return _linux(_run);
  if (Platform.isWindows) return _windows(_run);
  if (Platform.isAndroid) return _android(ref.watch(appIdentityProvider).androidPackage);
  return const DeviceFacts();
}, retry: (_, _) => null);

/// Days after which the newest security update counts as old.
const oldPatchDays = 120;

/// Device: disk encryption, screen lock, security updates, firewall and
/// antivirus, each only where the platform can say.
final deviceCheck = SecurityCheck(
  id: 'device',
  title: 'This device',
  findings: FutureProvider((ref) async {
    final f = await ref.watch(deviceFactsProvider.future);
    final patched = f.patched == null ? null : DateTime.tryParse(f.patched!);
    final age = patched == null ? null : DateTime.now().difference(patched).inDays;
    final steps = switch (Platform.operatingSystem) {
      'android' => 'Settings > Security and privacy > More security settings > Encryption.',
      'windows' => 'Settings > Privacy and security > Device encryption (or BitLocker).',
      _ => 'Encrypt the disk (LUKS); on most distributions that means reinstalling.',
    };
    return [
      if (f.diskEncrypted == false)
        Finding(
          id: 'device.disk',
          status: Status.warning,
          title: 'This device\'s storage is not encrypted',
          why:
              'Whoever gets hold of the device can read its files without any password, Brahma\'s '
              'database included: its key sits in the same storage.',
          steps: steps,
        ),
      if (f.screenLock == false)
        const Finding(
          id: 'device.screenlock',
          status: Status.serious,
          title: 'This device has no screen lock',
          why:
              'Anyone who picks it up can open it and every app on it. The app lock\'s device unlock '
              'also needs one.',
          steps: 'Set a PIN, pattern or password in the system settings.',
        ),
      if (age != null && age >= oldPatchDays)
        Finding(
          id: 'device.patch',
          status: Status.warning,
          title: 'Security updates are $age days old',
          why:
              'Known holes stay open on a device that misses updates. The newest one installed is '
              'from ${f.patched}.',
          steps: 'Install the system updates, or check that automatic updates are on.',
        ),
      if (f.antivirus == false)
        const Finding(
          id: 'device.antivirus',
          status: Status.warning,
          title: 'Windows antivirus is off',
          why: 'Real-time protection is not running, so malware is not stopped on arrival.',
          steps: 'Settings > Privacy and security > Windows Security > Virus and threat protection.',
        ),
      if (f.firewall == false)
        const Finding(
          id: 'device.firewall',
          status: Status.info,
          title: 'No firewall is running',
          why:
              'Services on this device are open to the network it is on. Behind a home router that is '
              'a small risk.',
          steps: 'Enable ufw or firewalld.',
        ),
    ];
  }),
);
