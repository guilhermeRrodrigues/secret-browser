import 'package:flutter/material.dart';

/// The always-visible floating "X" (PROMPT.md §4.2).
///
/// - Semi-transparent at rest, solid while pressed or dragged.
/// - A **single tap** fires [onPanic] immediately — no confirmation (it's a
///   panic action).
/// - Dragging reports movement via [onDrag]; the parent [PanicOverlay] owns the
///   position so the button can be repositioned anywhere on screen.
class PanicButton extends StatefulWidget {
  const PanicButton({
    super.key,
    required this.size,
    required this.onPanic,
    required this.onDrag,
  });

  final double size;
  final VoidCallback onPanic;
  final ValueChanged<Offset> onDrag;

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton> {
  bool _active = false;

  void _setActive(bool value) {
    if (_active == value) return;
    setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Botão de pânico: apagar tudo e fechar',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPanic,
        onTapDown: (_) => _setActive(true),
        onTapUp: (_) => _setActive(false),
        onTapCancel: () => _setActive(false),
        onPanStart: (_) => _setActive(true),
        onPanUpdate: (details) => widget.onDrag(details.delta),
        onPanEnd: (_) => _setActive(false),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _active ? 1 : 0.6,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
