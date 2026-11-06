import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// A guided tour: a short walk through an app's main screens, one control at
/// a time. It is optional (offered once at first start), can be skipped at
/// every step (Skip tour, Esc, or Back on Android) and can be taken again
/// from Settings > Hints and help.
///
/// An app lists its steps in [tourProvider] and marks the controls they
/// point at with [TourTarget]. [AppShell] runs it, since only the shell can
/// switch screens between steps.

/// One stop on the tour.
class TourStep {
  const TourStep({required this.title, required this.body, this.screen, this.target});
  final String title;

  /// One or two plain sentences on what the control does.
  final String body;

  /// The destination id to show first, when the control is on another screen.
  final String? screen;

  /// The [TourTarget] id to point at. Without one (or when it is not on
  /// screen) the step shows in the middle.
  final String? target;
}

/// This app's tour; empty means the app has none (no offer, no Settings entry).
final tourProvider = Provider<List<TourStep>>((ref) => const []);

/// Bumped to ask the shell to start the tour (Settings > Take the tour).
final tourRequestProvider = NotifierProvider<TourRequests, int>(TourRequests.new);

class TourRequests extends Notifier<int> {
  @override
  int build() => 0;
  void start() => state++;
}

const _offeredKey = 'tour.offered';

/// Whether to offer the tour at start: once per device, never again after
/// either answer. Local only, never synced.
final tourOfferProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(tourProvider).isEmpty) return false;
  return await ref.watch(coreSessionProvider).db.localSetting(_offeredKey) == null;
});

Future<void> markTourOffered(WidgetRef ref) =>
    ref.read(coreSessionProvider).db.setLocalSetting(_offeredKey, DateTime.now().toUtc().toIso8601String());

/// Marks [child] as the control tour steps call [id].
class TourTarget extends StatefulWidget {
  const TourTarget(this.id, {super.key, required this.child});
  final String id;
  final Widget child;

  /// The context of the mounted target [id], newest first when two are.
  static BuildContext? find(String id) {
    final list = _mounted[id];
    if (list == null) return null;
    for (final s in list.reversed) {
      if (s.mounted && _visible(s.context)) return s.context;
    }
    return null;
  }

  @override
  State<TourTarget> createState() => _TourTargetState();
}

final _mounted = <String, List<_TourTargetState>>{};

/// The shell keeps visited pages in an IndexedStack; a target on a page not
/// on show is skipped, as is one offstage or hidden.
bool _visible(BuildContext context) {
  // Visibility.of is false inside an IndexedStack child not on show.
  var shown = Visibility.of(context);
  context.visitAncestorElements((e) {
    if (e.widget case Offstage(offstage: true)) shown = false;
    return shown;
  });
  final box = context.findRenderObject();
  return shown && box is RenderBox && box.hasSize && box.attached;
}

class _TourTargetState extends State<TourTarget> {
  @override
  void initState() {
    super.initState();
    (_mounted[widget.id] ??= []).add(this);
  }

  @override
  void didUpdateWidget(TourTarget old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _mounted[old.id]?.remove(this);
      (_mounted[widget.id] ??= []).add(this);
    }
  }

  @override
  void dispose() {
    _mounted[widget.id]?.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Asks once whether to take the tour. Either answer is remembered.
Future<bool> offerTour(BuildContext context, WidgetRef ref) async {
  final name = ref.read(appIdentityProvider).name;
  final take = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.tour_outlined),
      title: Text('Welcome to $name'),
      content: const Text(
        'A short tour shows the main screens, one step at a time. You can skip it at any step, '
        'and take it later from Settings > Hints and help.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Take the tour')),
      ],
    ),
  );
  await markTourOffered(ref);
  return take ?? false;
}

/// Runs [steps]. [showScreen] switches to a step's screen. Ends on the last
/// step's Done, on Skip tour, Esc, or the system Back.
Future<void> runTour(BuildContext context, List<TourStep> steps, {void Function(String screen)? showScreen}) {
  if (steps.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => _Tour(steps, showScreen),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _Tour extends StatefulWidget {
  const _Tour(this.steps, this.showScreen);
  final List<TourStep> steps;
  final void Function(String screen)? showScreen;

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  var _at = 0;
  Rect? _hole;

  TourStep get _step => widget.steps[_at];

  @override
  void initState() {
    super.initState();
    _go(0);
  }

  Future<void> _go(int i) async {
    setState(() {
      _at = i;
      _hole = null;
    });
    final step = widget.steps[i];
    if (step.screen != null) widget.showScreen?.call(step.screen!);
    // Let the screen switch and lay out before finding the control.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _at != i || step.target == null) return;
    var target = TourTarget.find(step.target!);
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(target, alignment: 0.3, duration: const Duration(milliseconds: 200));
    await WidgetsBinding.instance.endOfFrame;
    target = TourTarget.find(step.target!);
    if (!mounted || _at != i || target == null || !target.mounted) return;
    final box = target.findRenderObject()! as RenderBox;
    final overlay = context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    setState(() => _hole = (topLeft & box.size).inflate(6));
  }

  void _end() => Navigator.of(context).pop();

  void _next() => _at == widget.steps.length - 1 ? _end() : _go(_at + 1);

  void _back() {
    if (_at > 0) _go(_at - 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hole = _hole;
    final last = _at == widget.steps.length - 1;
    final card = _TourCard(
      step: _step,
      at: _at,
      count: widget.steps.length,
      onNext: _next,
      onBack: _at == 0 ? null : _back,
      onSkip: _end,
      last: last,
    );
    // The card goes below the control when there is room, else above, else
    // in the middle.
    const cardWidth = 360.0, gap = 12.0;
    final left = hole == null
        ? null
        : (hole.center.dx - cardWidth / 2).clamp(16.0, (size.width - cardWidth - 16).clamp(16.0, size.width));
    final below = hole != null && size.height - hole.bottom > 220;
    final above = hole != null && !below && hole.top > 220;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _end,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _back,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Taps on the dimmed page do nothing; the tour keeps the page still.
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {},
                  child: CustomPaint(painter: _Dim(hole, Colors.black.withValues(alpha: 0.6))),
                ),
              ),
              if (hole != null && (below || above))
                Positioned(
                  left: left,
                  width: cardWidth.clamp(0, size.width - 32),
                  top: below ? hole.bottom + gap : null,
                  bottom: above ? size.height - hole.top + gap : null,
                  child: card,
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: cardWidth),
                      child: card,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.at,
    required this.count,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.last,
  });
  final TourStep step;
  final int at, count;
  final VoidCallback onNext, onSkip;
  final VoidCallback? onBack;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Tour, step ${at + 1} of $count',
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Step ${at + 1} of $count', style: text.labelMedium),
              const SizedBox(height: 4),
              Text(step.title, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(step.body),
              const SizedBox(height: 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onSkip, child: const Text('Skip tour')),
                  if (onBack != null) TextButton(onPressed: onBack, child: const Text('Back')),
                  FilledButton(autofocus: true, onPressed: onNext, child: Text(last ? 'Done' : 'Next')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims everything but [hole].
class _Dim extends CustomPainter {
  _Dim(this.hole, this.color);
  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final shade = hole == null
        ? all
        : Path.combine(
            PathOperation.difference,
            all,
            Path()..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(12))),
          );
    canvas.drawPath(shade, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Dim old) => old.hole != hole || old.color != color;
}
