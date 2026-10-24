import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vani/app/app.dart';
import 'package:vani/app/providers.dart';
import 'package:vani/app/session.dart';
import 'package:vani/domain/hub.dart';
import 'package:vani/domain/prefs.dart';

import 'fake_hub.dart';
import 'support.dart';

/// The whole app over a fresh in-memory database and a [FakeHub], for
/// widget tests.
class AppHarness {
  AppHarness(this.tester, {FakeHub? hub}) : hub = hub ?? FakeHub();
  final WidgetTester tester;
  final FakeHub hub;
  late AppSession session;

  /// Opens the database; with [connected] the hub link is already saved.
  Future<void> open({bool connected = true, ThemeMode theme = ThemeMode.dark, String name = 'Sam'}) async {
    await tester.runAsync(() async {
      final store = await Store.open(memoryDatabase());
      session = AppSession(KeyVault(MemorySecretStore(), vaniIdentity), store, VaniPrefs(store));
      if (connected) await session.prefs.saveHub(const HubLink(url: hubUrl, token: hubToken));
      if (name.isNotEmpty) await session.prefs.saveName(name);
      await session.db.setLocalSetting('vani.theme', theme.name);
    });
  }

  Widget app({Key? key}) => RepaintBoundary(
    key: key,
    child: ProviderScope(
      overrides: vaniOverrides(session, client: hub.client),
      retry: (_, _) => null,
      child: const VaniApp(),
    ),
  );

  Future<void> run({Key? key}) async {
    await tester.pumpWidget(app(key: key));
    await settle();
  }

  Future<void> close() async {
    // Disposing the scope stops the sync and refresh timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => session.db.close());
  }

  /// Lets database and hub work (real async) and animations finish.
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f, warnIfMissed: false);
    await settle();
  }

  Future<void> tapText(String text) => tap(find.text(text).last);

  /// Picks the segment labelled [label] of a segmented button.
  Future<void> segment(String label) => tap(
    find.descendant(of: find.byWidgetPredicate((w) => w is SegmentedButton), matching: find.text(label)),
  );

  /// Types into the text field labelled [label].
  Future<void> enter(String label, String text) async {
    final f = find.widgetWithText(TextField, label).last;
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  static final _nav = find.byWidgetPredicate((w) => const {'_Rail', '_PillBar'}.contains('${w.runtimeType}'));

  /// Goes to a top-level page through the rail (desktop) or the floating
  /// bar and its More sheet (phone).
  Future<void> go(String page) async {
    final direct = find.descendant(of: _nav, matching: find.byTooltip(page));
    if (direct.evaluate().isNotEmpty) return tap(direct.first);
    await tap(find.descendant(of: _nav, matching: find.byTooltip('More')));
    await tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(page)));
  }

  /// Opens the composer from the navigation.
  Future<void> compose() => tap(find.descendant(of: _nav, matching: find.byTooltip('Compose')));

  void desktop() => _size(const Size(1440, 900));

  void phone() => _size(const Size(390, 844));

  void _size(Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
}
