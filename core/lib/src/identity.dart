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

/// Link schemes of every Brahma app. Setup and pairing links are about the
/// shared account, so each app accepts all of them.
const brahmaLinkSchemes = {'artha', 'anveshana', 'udyoga'};
