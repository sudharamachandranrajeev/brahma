import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a problem report carries the details, steps, error and version', () {
    final body = reportBody(
      kind: ReportKind.bug,
      app: 'Vidya',
      version: '0.2.0',
      platform: 'android 15',
      details: 'The timer stopped.',
      steps: '1. Start focus',
      error: 'StateError: Bad state',
    );
    expect(body, contains('### What happened\nThe timer stopped.'));
    expect(body, contains('### Steps to see it\n1. Start focus'));
    expect(body, contains('```\nStateError: Bad state\n```'));
    expect(body, endsWith('Vidya 0.2.0 on android 15. Sent from the app\'s Report a problem form.'));
    final idea = reportBody(
      kind: ReportKind.feature,
      app: 'Vidya',
      version: '0.2.0',
      platform: 'linux',
      details: 'Dark mode',
      error: 'ignored',
    );
    expect(idea, contains('### What would help\nDark mode'));
    expect(idea, isNot(contains('ignored')));
  });

  test('the issue opens on the app\'s own repository, else Brahma\'s', () {
    final link = issueLink(
      repo: issueRepo(const AppIdentity(id: 'v', name: 'V', androidPackage: 'p', releases: 'o/vidya')),
      kind: ReportKind.feature,
      title: 'Dark mode',
      body: 'x' * 9000,
    );
    expect(link.toString(), startsWith('https://github.com/o/vidya/issues/new?'));
    expect(link.queryParameters['title'], 'Feature: Dark mode');
    expect(link.queryParameters['labels'], 'enhancement');
    expect(link.queryParameters['body']!.length, lessThan(6100));
    expect(
      issueRepo(const AppIdentity(id: 'u', name: 'U', androidPackage: 'p')),
      'sudharamachandranrajeev/brahma-life-suite',
    );
  });

  test('only the last three errors are kept', () {
    for (var i = 0; i < 5; i++) {
      AppErrors.record('error $i');
    }
    expect(AppErrors.recent, ['error 2', 'error 3', 'error 4']);
    expect(AppErrors.last, 'error 4');
  });

  testWidgets('an error offers a report that includes it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIdentityProvider.overrideWithValue(
            const AppIdentity(id: 'v', name: 'Vidya', androidPackage: 'p'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showError(context, StateError('boom')),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report a problem'), findsWidgets);
    expect(find.text('Include the last error'), findsOneWidget);
    expect(find.textContaining('boom'), findsWidgets);
    await tester.tap(find.text('Continue on GitHub'));
    await tester.pump();
    expect(find.text('Give it a short title'), findsOneWidget);
  });

  test('a report says which screen it came from', () {
    final body = reportBody(
      kind: ReportKind.feature,
      app: 'Vidya',
      version: '0.2.0',
      platform: 'linux',
      details: 'Dark mode',
      screen: 'Search',
    );
    expect(body, endsWith("Sent from the app's Suggest a feature form, on the Search screen."));
  });

  testWidgets('the Feedback button opens the form, an idea first', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appIdentityProvider.overrideWithValue(
            const AppIdentity(id: 'v', name: 'Vidya', androidPackage: 'p'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(appBar: AppBar(actions: const [FeedbackButton(screen: 'Search')])),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Feedback: report a problem or suggest a feature'));
    await tester.pumpAndSettle();
    expect(find.text('Suggest a feature'), findsOneWidget);
    expect(find.text('In a few words, what would help?'), findsOneWidget);
    await tester.tap(find.text('Bug'));
    await tester.pumpAndSettle();
    expect(find.text('Report a problem'), findsOneWidget);
  });
}
