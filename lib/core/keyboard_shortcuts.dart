import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Intent fired by the panic keyboard shortcut. Wired to `PanicService.trigger`.
class PanicIntent extends Intent {
  const PanicIntent();
}

/// The default panic chord: **Ctrl/Cmd + Shift + X** (PROMPT.md §4.4).
///
/// Both the Control and Meta variants are registered so the same physical
/// gesture works on Windows/Android/Linux (Ctrl) and macOS/iOS (Cmd).
const List<ShortcutActivator> panicActivators = <ShortcutActivator>[
  SingleActivator(LogicalKeyboardKey.keyX, control: true, shift: true),
  SingleActivator(LogicalKeyboardKey.keyX, meta: true, shift: true),
];

/// Max gap between two `Esc` presses to count as the alternative panic trigger.
const Duration kDoubleEscWindow = Duration(milliseconds: 600);

/// Registers the global panic shortcuts around [child].
///
/// - **Ctrl/Cmd + Shift + X** → [onPanic] (via `Shortcuts`/`Actions`).
/// - **Esc pressed twice quickly** → [onPanic] (handled by a root `Focus` so it
///   works regardless of which descendant holds focus).
///
/// Both paths call exactly the same callback, which the app points at
/// `PanicService.trigger()`. Works natively on desktop and with a physical
/// keyboard on mobile.
///
/// Known limitation: when a native WebView holds keyboard focus it may swallow
/// key events before Flutter sees them; the floating panic button always works.
class PanicShortcuts extends StatefulWidget {
  const PanicShortcuts({
    super.key,
    required this.onPanic,
    required this.child,
  });

  final VoidCallback onPanic;
  final Widget child;

  @override
  State<PanicShortcuts> createState() => _PanicShortcutsState();
}

class _PanicShortcutsState extends State<PanicShortcuts> {
  DateTime? _lastEsc;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final now = DateTime.now();
    final last = _lastEsc;
    if (last != null && now.difference(last) <= kDoubleEscWindow) {
      _lastEsc = null;
      widget.onPanic();
      return KeyEventResult.handled;
    }
    _lastEsc = now;
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      // A focused node whose descendants can still take focus (text field,
      // WebView) — we only peek at Esc and otherwise let events propagate.
      skipTraversal: true,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          for (final activator in panicActivators) activator: const PanicIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PanicIntent: CallbackAction<PanicIntent>(
              onInvoke: (_) {
                widget.onPanic();
                return null;
              },
            ),
          },
          child: widget.child,
        ),
      ),
    );
  }
}
