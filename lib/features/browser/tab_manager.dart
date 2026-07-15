import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/panic_service.dart';
import '../../core/privacy_config.dart';

/// A single in-memory browser tab. Never serialized to disk (PROMPT.md §5).
@immutable
class BrowserTab {
  const BrowserTab({
    required this.id,
    this.controller,
    this.url = '',
    this.title = 'Nova aba',
    this.isSecure = false,
    this.progress = 0,
  });

  final int id;

  /// Live WebView handle, set once `onWebViewCreated` fires. Null while the tab
  /// is still showing the blank start page.
  final InAppWebViewController? controller;

  final String url;
  final String title;
  final bool isSecure;
  final double progress;

  /// A blank tab has never navigated anywhere yet — it shows the start page.
  bool get isBlank => url.isEmpty;

  BrowserTab copyWith({
    Object? controller = _sentinel,
    String? url,
    String? title,
    bool? isSecure,
    double? progress,
  }) {
    return BrowserTab(
      id: id,
      controller: controller == _sentinel
          ? this.controller
          : controller as InAppWebViewController?,
      url: url ?? this.url,
      title: title ?? this.title,
      isSecure: isSecure ?? this.isSecure,
      progress: progress ?? this.progress,
    );
  }

  static const Object _sentinel = Object();
}

/// Immutable snapshot of the whole tab state.
@immutable
class TabManagerState {
  const TabManagerState({required this.tabs, required this.activeIndex});

  final List<BrowserTab> tabs;
  final int activeIndex;

  BrowserTab get activeTab => tabs[activeIndex];

  TabManagerState copyWith({List<BrowserTab>? tabs, int? activeIndex}) {
    return TabManagerState(
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

/// Owns all tabs, entirely in memory. Also exposes the wipe hook used by the
/// panic service to reset everything to a single blank tab.
class TabManager extends Notifier<TabManagerState> {
  int _nextId = 0;

  @override
  TabManagerState build() {
    return TabManagerState(tabs: [_blankTab()], activeIndex: 0);
  }

  BrowserTab _blankTab() => BrowserTab(id: _nextId++);

  void addTab() {
    final tabs = [...state.tabs, _blankTab()];
    state = TabManagerState(tabs: tabs, activeIndex: tabs.length - 1);
  }

  void setActive(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    state = state.copyWith(activeIndex: index);
  }

  void closeTab(int id) {
    final tabs = state.tabs.where((t) => t.id != id).toList();
    if (tabs.isEmpty) {
      state = TabManagerState(tabs: [_blankTab()], activeIndex: 0);
      return;
    }
    final newActive = state.activeIndex.clamp(0, tabs.length - 1);
    state = TabManagerState(tabs: tabs, activeIndex: newActive);
  }

  void attachController(int id, InAppWebViewController controller) {
    _update(id, (t) => t.copyWith(controller: controller));
  }

  void onUrlChanged(int id, WebUri? url) {
    final text = url?.toString() ?? '';
    _update(
      id,
      (t) => t.copyWith(url: text, isSecure: text.startsWith('https://')),
    );
  }

  void onTitleChanged(int id, String? title) {
    if (title == null || title.isEmpty) return;
    _update(id, (t) => t.copyWith(title: title));
  }

  void onProgressChanged(int id, int progress) {
    _update(id, (t) => t.copyWith(progress: progress / 100.0));
  }

  /// Navigate the active tab to [input] (a URL or a search query). For a blank
  /// tab this seeds `url`, which builds the WebView with an initial request;
  /// for a live tab it drives the existing controller.
  void navigateActive(String input) {
    final uri = normalizeToUri(input);
    final tab = state.activeTab;
    final controller = tab.controller;
    if (controller == null) {
      _update(
        tab.id,
        (t) => t.copyWith(
          url: uri.toString(),
          isSecure: uri.toString().startsWith('https://'),
        ),
      );
    } else {
      controller.loadUrl(urlRequest: PrivacyConfig.buildUrlRequest(uri));
    }
  }

  void reloadActive() => state.activeTab.controller?.reload();

  void stopActive() => state.activeTab.controller?.stopLoading();

  /// Panic hook: drop every tab and reset to one blank tab (PROMPT.md §4.3 #3-4).
  /// The heavy WebView wiping is done by [PanicService] via [InAppWebViewWipeableTab].
  void resetToBlank() {
    _nextId = 0;
    state = TabManagerState(tabs: [_blankTab()], activeIndex: 0);
  }

  /// Live wipe targets for the panic service — one per tab that has a controller.
  List<WipeableTab> wipeTargets() {
    return [
      for (final tab in state.tabs)
        if (tab.controller != null) InAppWebViewWipeableTab(tab.controller!),
    ];
  }

  void _update(int id, BrowserTab Function(BrowserTab) transform) {
    final tabs = [
      for (final t in state.tabs) t.id == id ? transform(t) : t,
    ];
    state = state.copyWith(tabs: tabs);
  }
}

final tabManagerProvider =
    NotifierProvider<TabManager, TabManagerState>(TabManager.new);

/// Adapts an [InAppWebViewController] to the [WipeableTab] contract consumed by
/// [PanicService]. Lives here because it wraps the per-tab controller.
class InAppWebViewWipeableTab implements WipeableTab {
  InAppWebViewWipeableTab(this.controller);

  final InAppWebViewController controller;

  @override
  Future<void> stopLoading() => controller.stopLoading();

  @override
  Future<void> clearHistory() => controller.clearHistory();

  @override
  Future<void> clearWebStorage() async {
    await controller.evaluateJavascript(
      source: 'try{localStorage.clear();sessionStorage.clear();}catch(e){}',
    );
  }
}

/// Turns arbitrary address-bar input into a [WebUri]:
/// - explicit http(s) URLs pass through;
/// - things that look like a domain get `https://` prepended;
/// - everything else becomes a DuckDuckGo search (privacy-friendly default).
WebUri normalizeToUri(String input) {
  final text = input.trim();
  if (text.isEmpty) return WebUri('about:blank');
  if (text.startsWith('http://') || text.startsWith('https://')) {
    return WebUri(text);
  }
  final looksLikeDomain =
      !text.contains(' ') && RegExp(r'^[^\s/]+\.[^\s/]+').hasMatch(text);
  if (looksLikeDomain) return WebUri('https://$text');
  return WebUri('https://duckduckgo.com/?q=${Uri.encodeQueryComponent(text)}');
}
