import 'package:flutter/material.dart';

/// Discreet "anonymous mode active" indicator (PROMPT.md §5). Purely visual —
/// it reflects that every WebView runs incognito with in-memory-only state.
class AnonymousBadge extends StatelessWidget {
  const AnonymousBadge({super.key, this.compact = false});

  /// When true, shows just the icon (for tight chrome); otherwise icon + label.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Tooltip(
      message: 'Modo anônimo ativo — nada é gravado no dispositivo',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, size: 14, color: color),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                'Anônimo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
