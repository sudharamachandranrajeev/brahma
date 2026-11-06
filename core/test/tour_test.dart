import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _steps = [
  TourStep(title: 'Search', body: 'Type what you want.', target: 'search'),
  TourStep(title: 'Settings', body: 'Change things here.', screen: 'settings', target: 'gear'),
  TourStep(title: 'All done', body: 'Take the tour again from Settings.'),
];

/// Two "screens" in an IndexedStack, as the shell keeps them.
class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  var screen = 0;
  Future<void>? tour;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          actions: [
            TextButton(
              onPressed: () => setState(() {
                tour = runTour(
                  context,
                  _steps,
                  showScreen: (id) => setState(() => screen = id == 'settings' ? 1 : 0),
                );
              }),
              child: const Text('Start'),
            ),
          ],
        ),
        body: IndexedStack(
          index: screen,
          children: [
            const Center(child: TourTarget('search', child: SizedBox(width: 200, height: 40))),
            Align(
              alignment: Alignment.topLeft,
              child: TourTarget(
                'gear',
                child: IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('steps go forward and back, switch screens, and end on Done', (tester) async {
    await tester.pumpWidget(const _App());
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);
    final state = tester.state<_AppState>(find.byType(_App));
    expect(state.screen, 1);
    // The settings button is found on its own screen, not the hidden one.
    expect(TourTarget.find('gear'), isNotNull);
    expect(TourTarget.find('search'), isNull);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step'), findsNothing);
    await state.tour;
  });

  testWidgets('Skip tour and Esc end it at any step', (tester) async {
    await tester.pumpWidget(const _App());
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step'), findsNothing);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.textContaining('Step'), findsNothing);
  });
}
