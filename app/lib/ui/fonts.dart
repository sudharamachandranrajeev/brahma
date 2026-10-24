import 'dart:convert';

import 'package:flutter/services.dart';

/// Makes the fonts the apps bundle usable under their plain family names.
///
/// An app's fonts are registered as `packages/<app>/<Family>` when the app
/// is a dependency, but its theme asks for `<Family>` (right when it runs on
/// its own). This loads each such family once under its plain name too, so
/// the apps look the same inside the suite.
Future<void> shareAppFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  final plain = {for (final f in manifest) (f as Map)['family'] as String};
  final loaded = <String>{};
  for (final f in manifest.cast<Map<String, Object?>>()) {
    final match = RegExp(r'^packages/[^/]+/(.+)$').firstMatch(f['family']! as String);
    if (match == null) continue;
    final family = match.group(1)!;
    if (plain.contains(family) || !loaded.add(family)) continue;
    final loader = FontLoader(family);
    for (final font in (f['fonts']! as List).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}
