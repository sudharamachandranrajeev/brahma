import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'account_api.dart';
import 'pocketbase_remote.dart' show isLocalServerHost, validateServerUrl;

/// Where the user said their server runs, so problems are explained for it.
enum ServerPlace { home, cloud, unknown }

/// The result of [checkServer]: the server, or what is wrong in everyday
/// words and what to try.
class ServerCheck {
  const ServerCheck.found(Uri this.url, ServerInfo this.info) : problem = null, fix = null;
  const ServerCheck.problem(String this.problem, String this.fix) : url = null, info = null;

  final Uri? url;
  final ServerInfo? info;
  final String? problem, fix;
  bool get ok => info != null;
}

/// The port home servers listen on unless the installer was told otherwise.
const homeServerPort = 8090;

/// Fills in what people leave out: "192.168.1.20" becomes
/// "http://192.168.1.20:8090", "sync.example.com" becomes "https://...".
String completeServerAddress(String text) {
  var t = text.trim().replaceAll(RegExp(r'/+$'), '');
  if (t.isEmpty || t.contains('://')) return t;
  final host = t.split(RegExp('[:/]')).first;
  final local = isLocalServerHost(host);
  t = '${local ? 'http' : 'https'}://$t';
  final uri = Uri.tryParse(t);
  if (local && uri != null && !uri.hasPort) t = uri.replace(port: homeServerPort).toString();
  return t;
}

bool _tailscale(InternetAddress ip) =>
    ip.type == InternetAddressType.IPv4 &&
    ip.rawAddress[0] == 100 &&
    ip.rawAddress[1] >= 64 &&
    ip.rawAddress[1] < 128;

/// Asks [address] whether it is a sync server, and if not, says why in
/// words someone who never ran a server can act on.
Future<ServerCheck> checkServer(
  String address, {
  ServerPlace place = ServerPlace.unknown,
  http.Client? client,
}) async {
  final Uri url;
  try {
    url = validateServerUrl(completeServerAddress(address));
  } catch (_) {
    return ServerCheck.problem(
      "That address can't be used.",
      place == ServerPlace.home
          ? 'Copy the address the installer printed. It looks like http://192.168.1.20:8090, or '
                'http://100.x.x.x:8090 for Tailscale.'
          : 'Addresses outside your home must start with https://. To reach a home server away from '
                'home, use its Tailscale address (it starts with 100.).',
    );
  }
  final c = client ?? http.Client();
  try {
    final res = await c.get(url.resolve('/api/health')).timeout(const Duration(seconds: 8));
    Object? body;
    try {
      body = jsonDecode(res.body);
    } on FormatException {
      body = null;
    }
    final info = ServerInfo.fromHealth(body);
    if (info != null) return ServerCheck.found(url, info);
    if (res.statusCode == 200 && body is Map && body['message'] == 'API is healthy.') {
      return ServerCheck.found(url, const ServerInfo(worker: false));
    }
    return const ServerCheck.problem(
      "Something answered, but it isn't a Brahma sync server.",
      'Check the address and the number after the colon (the port). The installer prints the right one.',
    );
  } on TimeoutException {
    return _noAnswer(url, place);
  } on SocketException catch (e) {
    return _socketProblem(url, place, e);
  } on HandshakeException {
    return const ServerCheck.problem(
      "A secure connection to the server couldn't be made.",
      'Its https certificate is not valid. Cloudflare servers always have one, so check the address.',
    );
  } on http.ClientException catch (e) {
    return e.message.contains('refused')
        ? _refused()
        : ServerCheck.problem(
            "Couldn't reach the server (${e.message}).",
            'Check the address and try again.',
          );
  } finally {
    if (client == null) c.close();
  }
}

ServerCheck _socketProblem(Uri url, ServerPlace place, SocketException e) {
  final text = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
  if (text.contains('host lookup') || text.contains('name or service') || text.contains('no address')) {
    return ServerCheck.problem(
      "This device can't find ${url.host}.",
      url.host.endsWith('.local')
          ? 'Some phones cannot use .local names. Use the number address the installer printed instead.'
          : 'Check the spelling, and that this device is online.',
    );
  }
  if (text.contains('refused') || const {111, 61, 10061}.contains(e.osError?.errorCode)) return _refused();
  return _noAnswer(url, place);
}

ServerCheck _refused() => const ServerCheck.problem(
  "The computer is there, but the sync server isn't running on it.",
  'On the server computer, run "./install.sh --status" to see why, and "./install.sh" to start it '
      'again. Also check the port number.',
);

ServerCheck _noAnswer(Uri url, ServerPlace place) {
  final ip = InternetAddress.tryParse(url.host);
  if (ip != null && _tailscale(ip)) {
    return const ServerCheck.problem(
      'No answer over Tailscale.',
      'Turn Tailscale on on this device and sign in to the same Tailscale account. Check the server '
          'computer is switched on.',
    );
  }
  if (isLocalServerHost(url.host) || place == ServerPlace.home) {
    return const ServerCheck.problem(
      'No answer from the server computer.',
      'Check it is switched on and not asleep, that this device is on the same Wi-Fi, and that its '
          'firewall lets your devices in (the installer offers to do this).',
    );
  }
  return const ServerCheck.problem(
    'No answer from the server.',
    'Check that you are online and the address is right. A new Cloudflare server can take a minute to start.',
  );
}

/// A home server found on this network by [findHomeServers].
typedef FoundServer = ({Uri url, ServerInfo info});

/// Looks for home sync servers on this device's home network: asks every
/// address next to its own (the same x.y.z.*) on the home server port.
/// Nothing leaves the home network. Yields servers as they answer.
Stream<FoundServer> findHomeServers({int port = homeServerPort, http.Client? client}) async* {
  final c = client ?? http.Client();
  try {
    final prefixes = <String>{};
    for (final nic in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in nic.addresses) {
        final [x, y, z, _] = a.rawAddress;
        final home = x == 10 || (x == 172 && y >= 16 && y < 32) || (x == 192 && y == 168);
        if (home && !a.isLoopback) prefixes.add('$x.$y.$z');
      }
    }
    final hosts = [
      for (final p in prefixes)
        for (var i = 1; i < 255; i++) '$p.$i',
    ];
    const batch = 64;
    for (var i = 0; i < hosts.length; i += batch) {
      final found = await Future.wait([
        for (final h in hosts.skip(i).take(batch)) _probe(c, Uri(scheme: 'http', host: h, port: port)),
      ]);
      for (final f in found) {
        if (f != null) yield f;
      }
    }
  } finally {
    if (client == null) c.close();
  }
}

Future<FoundServer?> _probe(http.Client c, Uri url) async {
  try {
    final res = await c.get(url.resolve('/api/health')).timeout(const Duration(milliseconds: 900));
    final info = ServerInfo.fromHealth(jsonDecode(res.body));
    return info?.kind == ServerKind.home ? (url: url, info: info!) : null;
  } catch (_) {
    return null;
  }
}
