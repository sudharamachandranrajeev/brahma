import 'dart:convert';
import 'dart:io';

import 'package:bhojana/domain/reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chromium.dart';

/// Replays the reader over real shop pages saved by the live test
/// (integration_test/live_shops_test.dart), offline: each page must still
/// read as many products and multi-buys as it did live. The pages are the
/// shops' own and stay on this machine (test/live_pages is not committed),
/// so this only runs where a live run has saved some.
void main() {
  final dir = Directory('test/live_pages');
  final pages = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.html')).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : const <File>[];

  for (final page in pages) {
    final name = page.uri.pathSegments.last.replaceAll('.html', '');
    test(
      'saved page $name reads as it did live',
      () async {
        final live = jsonDecode(File(page.path.replaceAll('.html', '.json')).readAsStringSync()) as Map;
        final tmp = await Directory.systemTemp.createTemp('bhojana_replay');
        addTearDown(() => tmp.delete(recursive: true));
        final html = page.readAsStringSync().replaceFirst(
          RegExp('^<!doctype html>', caseSensitive: false),
          '',
        );
        final at = html.lastIndexOf('</body>');
        final replay = File('${tmp.path}/page.html')
          ..writeAsStringSync(
            // Saved as UTF-8; without saying so a file page reads £ as Â£.
            '<!doctype html><meta charset="utf-8">${at < 0 ? html : html.substring(0, at)}'
            '<pre id="out"></pre><script>document.getElementById("out").textContent = $readerScript;</script>'
            '</body></html>',
          );
        final offers = parseOffers('${live['shop']}', await dumpOut(chromium!, tmp, replay));
        expect(offers.length, live['products'], reason: 'products');
        expect(offers.where((o) => o.multiBuy != null).length, live['deals'], reason: 'multi-buys');
      },
      timeout: const Timeout(Duration(seconds: 90)),
      skip: chromium == null ? 'Chromium is not installed' : null,
    );
  }
}
