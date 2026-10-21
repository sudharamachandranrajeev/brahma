import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Hints the shared screens use. Each app adds its own through
/// [hintTextsProvider].
const coreHints = <String, String>{
  'nav.settings': 'Hints, sync and security.',
  'nav.more': 'The rest of the app.',
  'settings.hints': 'Show these tips and the explanations at the top of each page.',
  'settings.restoreHints': 'Turn hints on and show every page explanation again.',
  'settings.sync':
      'Keep devices in step through your own server. Data is encrypted before it leaves the device.',
};

/// Wraps [child] in a tooltip with hint [id], unless hints are off.
class Hint extends ConsumerWidget {
  const Hint(this.id, {super.key, required this.child});
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(hintsProvider).value?.enabled ?? true;
    final text = ref.watch(hintTextsProvider)[id];
    if (!on || text == null) return child;
    return Tooltip(message: text, child: child);
  }
}

/// An icon button whose tooltip is the hint when hints are on and the plain
/// [label] otherwise, so screen readers always get a label.
class HintIconButton extends ConsumerWidget {
  const HintIconButton(this.id, {super.key, required this.icon, required this.label, this.onPressed});
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(hintsProvider).value?.enabled ?? true;
    final hint = ref.watch(hintTextsProvider)[id];
    return IconButton(
      icon: Icon(icon),
      tooltip: on && hint != null ? '$label: $hint' : label,
      onPressed: onPressed,
    );
  }
}

/// A page explanation that fades in and can be dismissed ("Got it").
/// Settings > Hints brings dismissed ones back.
class HintBanner extends ConsumerStatefulWidget {
  const HintBanner(this.id, {super.key});
  final String id;

  @override
  ConsumerState<HintBanner> createState() => _HintBannerState();
}

class _HintBannerState extends ConsumerState<HintBanner> {
  bool _closing = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hintsProvider).value;
    final text = ref.watch(hintTextsProvider)[widget.id];
    final visible = state != null && state.shows(widget.id) && text != null;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _closing ? 0 : 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              onEnd: () {
                if (_closing) ref.read(hintsProvider.notifier).dismiss(widget.id);
              },
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: scheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: scheme.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
                        ),
                        TextButton(
                          onPressed: _closing ? null : () => setState(() => _closing = true),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
