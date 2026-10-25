import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader.dart';
import 'shops.dart';

/// Whether this platform has an embedded web view (Linux has none).
bool get hasWebView =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS);

/// Reads shop search pages in a hidden web view. It shares cookies with the
/// in-app browser, so a shop the user signed in to (and gave a postcode)
/// shows them their own prices, loyalty prices and stock.
class WebSearcher implements PriceSearcher {
  const WebSearcher();

  @override
  bool get available => hasWebView;

  @override
  Future<List<Offer>> search(Shop shop, String query) async {
    final loaded = Completer<void>();
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(shop.searchUrl(query))),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onLoadStop: (_, _) {
        if (!loaded.isCompleted) loaded.complete();
      },
      onReceivedError: (_, req, err) {
        if (req.isForMainFrame != false && !loaded.isCompleted) loaded.completeError(err.description);
      },
    );
    try {
      await view.run();
      await loaded.future.timeout(const Duration(seconds: 30));
      // Most shops draw their results with script after the page loads, so
      // read a few times until products appear.
      var offers = const <Offer>[];
      for (var i = 0; i < 6 && offers.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final json = await view.webViewController?.evaluateJavascript(source: readerScript);
        offers = parseOffers(shop.id, json);
      }
      return offers;
    } finally {
      await view.dispose();
    }
  }
}
