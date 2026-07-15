import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/privacy_config.dart';
import '../../widgets/anonymous_badge.dart';
import 'address_bar.dart';
import 'tab_manager.dart';

/// The main browser surface: address bar, optional tab strip, and the active
/// tab's content (blank start page or a live WebView). All tabs live in an
/// [IndexedStack] so their WebViews keep their in-memory state while hidden.
class BrowserScreen extends ConsumerWidget {
  const BrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tabManagerProvider);
    return SafeArea(
      child: Column(
        children: [
          const AddressBar(),
          if (state.tabs.length > 1) const _TabStrip(),
          Expanded(
            child: IndexedStack(
              index: state.activeIndex,
              children: [
                for (final tab in state.tabs)
                  KeyedSubtree(
                    key: ValueKey<int>(tab.id),
                    child: tab.isBlank
                        ? _StartPage(
                            onSubmit: (value) => ref
                                .read(tabManagerProvider.notifier)
                                .navigateActive(value),
                          )
                        : _WebViewTab(tabId: tab.id, initialUrl: tab.url),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One live WebView, configured with the anonymous privacy settings. Reports
/// url/title/progress back to the [TabManager].
class _WebViewTab extends ConsumerWidget {
  const _WebViewTab({required this.tabId, required this.initialUrl});

  final int tabId;
  final String initialUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tabManagerProvider.notifier);
    return InAppWebView(
      initialUrlRequest: PrivacyConfig.buildUrlRequest(WebUri(initialUrl)),
      initialSettings: PrivacyConfig.buildSettings(),
      onWebViewCreated: (controller) =>
          notifier.attachController(tabId, controller),
      onLoadStop: (controller, url) => notifier.onUrlChanged(tabId, url),
      onUpdateVisitedHistory: (controller, url, isReload) =>
          notifier.onUrlChanged(tabId, url),
      onTitleChanged: (controller, title) =>
          notifier.onTitleChanged(tabId, title),
      onProgressChanged: (controller, progress) =>
          notifier.onProgressChanged(tabId, progress),
    );
  }
}

/// Blank new-tab page: brand, a centered search field and the anonymous badge
/// (PROMPT.md §5).
class _StartPage extends StatefulWidget {
  const _StartPage({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<_StartPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_moon,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Secret Browser', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const AnonymousBadge(),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: false,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Pesquisar ou digitar endereço',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
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

/// Horizontal strip of open tabs for switching/closing (in-memory only).
class _TabStrip extends ConsumerWidget {
  const _TabStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(tabManagerProvider);
    final notifier = ref.read(tabManagerProvider.notifier);
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: state.tabs.length,
        itemBuilder: (context, index) {
          final tab = state.tabs[index];
          final selected = index == state.activeIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
            child: InkWell(
              onTap: () => notifier.setActive(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        tab.isBlank ? 'Nova aba' : tab.title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => notifier.closeTab(tab.id),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
