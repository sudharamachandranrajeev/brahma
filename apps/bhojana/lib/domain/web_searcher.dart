import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'reader.dart';
import 'shops.dart';

/// Whether this build has an embedded web view. Linux has one (WPE WebKit)
/// when built with it; the portable release tarball is built without it
/// (packages/no_linux_webview) and opens shops in the system browser.
bool get hasWebView =>
    !kIsWeb &&
    (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isWindows ||
        Platform.isMacOS ||
        (Platform.isLinux && InAppWebViewPlatform.instance != null));

/// Settings for every web view that shows a shop. The plugin's JavaScript
/// bridge (window.flutter_inappwebview) is off: Bhojana only runs scripts
/// with evaluateJavascript, and a shop page calling the bridge's callHandler
/// gets null back, which the Windows plugin (0.7.0-beta.3) dereferences and
/// the app crashes.
InAppWebViewSettings webSettings({bool? supportMultipleWindows}) => InAppWebViewSettings(
  javaScriptEnabled: true,
  javaScriptBridgeEnabled: false,
  supportMultipleWindows: supportMultipleWindows,
);

/// Reads shop search pages in a hidden web view. It shares cookies with the
/// in-app browser, so a shop the user signed in to (and gave a postcode)
/// shows them their own prices, loyalty prices and stock.
class WebSearcher implements PriceSearcher {
  const WebSearcher();

  @override
  bool get available => hasWebView;

  /// [keep] is given the settled page before it closes (the live tests save
  /// it, to replay the reader over it offline). Throws [ShopCheck] when the
  /// shop shows its bot check instead.
  @override
  Future<List<Offer>> search(
    Shop shop,
    String query, {
    Future<void> Function(InAppWebViewController web)? keep,
  }) async {
    final loaded = Completer<void>();
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(shop.searchUrl(query))),
      initialSettings: webSettings(),
      onLoadStop: (_, _) {
        if (!loaded.isCompleted) loaded.complete();
      },
      // A bot check (Cloudflare's "Just a moment…") comes with a 403. The
      // Windows web view reports any status of 400 or more here instead of
      // in onLoadStop, but the page is there to read and to check.
      onReceivedHttpError: (_, req, _) {
        if (req.isForMainFrame != false && !loaded.isCompleted) loaded.complete();
      },
      onReceivedError: (_, req, err) {
        // A load cut short by the shop's own redirect is not a failure; the
        // page it goes to still ends in onLoadStop.
        if (err.type == WebResourceErrorType.CANCELLED) return;
        if (req.isForMainFrame != false && !loaded.isCompleted) loaded.completeError(err.description);
      },
    );
    try {
      await view.run();
      await loaded.future.timeout(const Duration(seconds: 30));
      // Most shops draw their results with script after the page loads, so
      // read a few times until products for the query appear (Iceland's take
      // about ten seconds; its menus have prices before that) and the page
      // stops changing for two reads (Iceland draws its multi-buy badges a
      // second or two after the tiles, sometimes redrawing them first).
      var offers = const <Offer>[];
      String? last;
      var same = 0, checks = 0;
      final web = view.webViewController!;
      for (var i = 0; i < 14; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final json = '${await web.evaluateJavascript(source: readerScript)}';
        same = json == last ? same + 1 : 0;
        if (same >= 2 && rank(query, offers).isNotEmpty) break;
        last = json;
        offers = parseOffers(shop.id, json);
        // Twice in a row, in case the check passes by itself and moves on.
        if (rank(query, offers).isEmpty && await web.evaluateJavascript(source: checkScript) == true) {
          if (++checks >= 2) throw ShopCheck(shop.name);
        } else {
          checks = 0;
        }
      }
      await keep?.call(web);
      return offers;
    } finally {
      await view.dispose();
    }
  }
}
