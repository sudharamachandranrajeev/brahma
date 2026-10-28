import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:udyoga/app/modules.dart';
import 'package:udyoga/db/database.dart';
import 'package:udyoga/domain/pipeline.dart';
import 'package:udyoga/ui/applications_page.dart';

import 'app_harness.dart';
import 'seed.dart';

/// Smoke tests: every page builds, with and without data, on phone and
/// desktop widths, without throwing or overflowing; and the main flows.
void main() {
  final pages = [for (final d in allDestinations) d.label];

  testWidgets('every page builds on a desktop window, empty and with data', (tester) async {
    for (final seeded in [false, true]) {
      final app = AppHarness(tester)..desktop();
      await app.open(seed: seeded ? seedBook : null);
      await app.run();
      for (final label in pages) {
        await app.go(label);
        expect(tester.takeException(), isNull, reason: '$label (seeded: $seeded)');
      }
      await app.close();
    }
  });

  testWidgets('the application board moves a card by drag and by its menu', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedBook);
    await app.run();
    await app.go('Applications');
    expect(find.byType(ApplicationBoard), findsOneWidget);

    Future<String> stageOf(String title) => tester
        .runAsync(() async => (await app.book.db.select(app.book.db.jobApplications).get()))
        .then((all) => all!.singleWhere((a) => a.title == title).stage);

    final card = find.text('Digital Nurse Specialist');
    final screening = find.ancestor(
      of: find.text('Screening'),
      matching: find.byType(DragTarget<JobApplication>),
    );
    final drag = await tester.startGesture(tester.getCenter(card));
    await tester.pump(kLongPressTimeout);
    await drag.moveTo(tester.getCenter(screening));
    await tester.pump();
    await drag.up();
    await app.settle();
    expect(await stageOf('Digital Nurse Specialist'), Stage.screening.id);

    await app.tap(
      find.descendant(
        of: find.ancestor(of: find.text('EPR Trainer'), matching: find.byType(Card)),
        matching: find.byTooltip('Move to'),
      ),
    );
    await app.tapText('Move to Rejected');
    expect(await stageOf('EPR Trainer'), Stage.rejected.id);
    expect(find.text('EPR Trainer'), findsNothing);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('every page builds on a phone, with the detail pages', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedBook);
    await app.run();
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.go('Jobs');
    await app.tap(find.widgetWithText(ChoiceChip, 'Applied'));
    await app.tapText('EPR Trainer');
    expect(find.text('The advert'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await app.settle();

    await app.go('Applications');
    await app.tapText('Digital Nurse Specialist');
    expect(find.text('Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await app.settle();

    await app.go('Interview');
    await app.tapText('Clinical Informatics Nurse');
    expect(find.text('Tell us about a change you led.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('Today shows due follow-ups, the interview and closing jobs', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedBook);
    await app.run();
    expect(find.text('Follow up today'), findsOneWidget);
    expect(find.text('Upcoming interviews'), findsOneWidget);
    expect(find.text('Closing this week'), findsOneWidget);
    await app.close();
  });

  testWidgets('a job moves to an application from its page', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedBook);
    await app.run();
    await app.go('Jobs');
    await app.tap(find.widgetWithText(ChoiceChip, 'Saved'));
    await app.tapText('Clinical Informatics Nurse');
    await app.tapText('Apply for this job');
    expect(tester.takeException(), isNull);
    // The dialog asks whether it was sent; either answer opens an application.
    final sent = find.textContaining('sent', findRichText: true);
    expect(sent, findsWidgets);
    await app.close();
  });

  testWidgets('the LinkedIn human check cleans a draft on the device', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seedBook);
    await app.run();
    await app.go('LinkedIn');
    expect(find.text('Your voice'), findsOneWidget);
    expect(find.textContaining('You post and send everything yourself'), findsWidgets);
    await app.tapText('Human check');
    await app.enter('Draft', 'We leverage it \u2014 daily.');
    await app.tapText('Check');
    await app.settle();
    expect(find.text('Cleaned text'), findsOneWidget);
    expect(find.textContaining('\u2014'), findsNothing);
    expect(tester.takeException(), isNull);
    await app.close();
  });
}
