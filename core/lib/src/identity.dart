/// Which Brahma app is running.
///
/// The apps share one sync account and one encrypted vault (same server,
/// same password, same data key), so an account made in one app works in
/// all of them. Each app keeps its own keychain entries, database file and
/// link scheme.
class AppIdentity {
  const AppIdentity({required this.id, required this.name, required this.androidPackage});

  /// Lower-case id: keychain prefix, database file name and link scheme.
  final String id;

  /// Display name, e.g. "Artha".
  final String name;

  /// Android application id; the links method channel lives under it.
  final String androidPackage;

  String get linkScheme => id;
  String get linkChannel => '$androidPackage/links';
}

/// Whether [scheme] can be a Brahma app's link scheme. Setup and pairing
/// links are about the shared account, so each app accepts every app's
/// links. Apps join the suite over time, so this is a rule (a plain
/// lower-case id that is not a web scheme) rather than a list that every
/// installed app would need rebuilding to extend.
bool isBrahmaScheme(String scheme) =>
    RegExp(r'^[a-z][a-z0-9]*$').hasMatch(scheme) && !_otherSchemes.contains(scheme);

const _otherSchemes = {'http', 'https', 'file', 'mailto', 'tel', 'sms', 'data', 'content', 'intent'};
