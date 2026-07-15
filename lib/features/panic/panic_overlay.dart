import 'package:flutter/material.dart';

import 'panic_button.dart';

/// Overlays the draggable [PanicButton] on top of [child] so it is *always*
/// visible — including over a focused WebView — and never covered by other UI
/// (PROMPT.md §4.2, §5). Owns the button's position; default is bottom-right.
class PanicOverlay extends StatefulWidget {
  const PanicOverlay({
    super.key,
    required this.onPanic,
    required this.child,
  });

  final VoidCallback onPanic;
  final Widget child;

  @override
  State<PanicOverlay> createState() => _PanicOverlayState();
}

class _PanicOverlayState extends State<PanicOverlay> {
  static const double _buttonSize = 56;
  static const double _margin = 16;

  /// Top-left of the button. Null until the user first drags it, so it starts
  /// pinned to the bottom-right corner regardless of screen size.
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = (constraints.maxWidth - _buttonSize - _margin)
            .clamp(_margin, double.infinity);
        final maxY = (constraints.maxHeight - _buttonSize - _margin)
            .clamp(_margin, double.infinity);
        final desired = _position ?? Offset(maxX, maxY);
        final pos = Offset(
          desired.dx.clamp(_margin, maxX),
          desired.dy.clamp(_margin, maxY),
        );
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: PanicButton(
                size: _buttonSize,
                onPanic: widget.onPanic,
                onDrag: (delta) => setState(() => _position = pos + delta),
              ),
            ),
          ],
        );
      },
    );
  }
}
