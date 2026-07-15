import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tab_manager.dart';

/// Top bar: URL field, security (lock) indicator, reload/stop, new tab and a
/// tab counter (PROMPT.md §5). Reads/writes tab state via Riverpod.
class AddressBar extends ConsumerStatefulWidget {
  const AddressBar({super.key});

  @override
  ConsumerState<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends ConsumerState<AddressBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    ref.read(tabManagerProvider.notifier).navigateActive(value);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(tabManagerProvider);
    final tab = state.activeTab;
    final loading = tab.progress > 0 && tab.progress < 1;

    // Keep the field in sync with the active tab unless the user is editing it.
    if (!_focusNode.hasFocus && _controller.text != tab.url) {
      _controller.text = tab.url;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              _SecurityIcon(tab: tab),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.go,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: _submit,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Pesquisar ou digitar endereço',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: loading ? 'Parar' : 'Recarregar',
                icon: Icon(loading ? Icons.close : Icons.refresh),
                onPressed: tab.controller == null
                    ? null
                    : () {
                        final notifier = ref.read(tabManagerProvider.notifier);
                        loading ? notifier.stopActive() : notifier.reloadActive();
                      },
              ),
              _TabCounter(count: state.tabs.length),
              IconButton(
                tooltip: 'Nova aba',
                icon: const Icon(Icons.add),
                onPressed: () => ref.read(tabManagerProvider.notifier).addTab(),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 2,
          child: loading
              ? LinearProgressIndicator(
                  value: tab.progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                )
              : null,
        ),
      ],
    );
  }
}

class _SecurityIcon extends StatelessWidget {
  const _SecurityIcon({required this.tab});

  final BrowserTab tab;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String tooltip;
    if (tab.isBlank) {
      icon = Icons.search;
      color = Colors.grey;
      tooltip = 'Pronto para pesquisar';
    } else if (tab.isSecure) {
      icon = Icons.lock;
      color = Colors.greenAccent;
      tooltip = 'Conexão segura (HTTPS)';
    } else {
      icon = Icons.lock_open;
      color = Colors.amberAccent;
      tooltip = 'Conexão não segura (HTTP)';
    }
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _TabCounter extends StatelessWidget {
  const _TabCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
