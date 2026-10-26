import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vani/app/app.dart';
import 'package:vani/app/providers.dart';
import 'package:vani/domain/cloudflare.dart';
import 'package:vani/ui/hub_setup.dart';

import 'app_harness.dart';
import 'fake_cloudflare.dart';

void main() {
  test('hub versions compare by number', () {
    expect(hubIsOlder(null, '0.3.0'), isTrue);
    expect(hubIsOlder('0.2.9', '0.3.0'), isTrue);
    expect(hubIsOlder('0.3.0', '0.3.0'), isFalse);
    expect(hubIsOlder('0.10.0', '0.9.1'), isFalse);
  });

  testWidgets('a new user sets up a hub from the first screen and is connected', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(connected: false);
    final cf = FakeCloudflare();
    await tester.pumpWidget(
      ProviderScope(
        overrides: vaniOverrides(app.session, client: cf.client),
        retry: (_, _) => null,
        child: const VaniApp(),
      ),
    );
    await app.settle();

    await app.tapText('Set up a hub');
    expect(find.text('Make a free Cloudflare account'), findsOneWidget);
    await app.tapText('Next');
    await app.tapText('Done, next');
    await app.enter('Paste the key here', 'wrong');
    await app.tapText('Check the key');
    expect(find.textContaining('refused the key'), findsOneWidget);

    await app.enter('Paste the key here', 'cf-key');
    await app.tapText('Check the key');
    expect(find.text('Address: https://vani-hub.tester.workers.dev'), findsOneWidget);
    await app.tapText('Set up');
    await app.settle();

    expect(tester.takeException(), isNull);
    expect(find.text('Your hub is live and this computer is connected.'), findsOneWidget);
    expect(find.text('1. Vani on your phone'), findsOneWidget);
    expect(cf.workersDev, isTrue);

    final link = await tester.runAsync(() => app.session.prefs.hub());
    expect(link!.url, 'https://vani-hub.tester.workers.dev');
    expect(link.token, cf.hubToken);
    final saved = await tester.runAsync(() => app.session.db.localSetting(HubDeployment.localKey));
    expect(saved, contains('cf-key'));

    await app.tapText('Finish');
    expect(find.text('Connect your social hub'), findsNothing);
    await app.close();
  });
}
