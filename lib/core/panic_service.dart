import 'dart:async';

import 'package:flutter/foundation.dart';

import 'platform_exit.dart';

/// A browser tab that can be wiped. Implemented at runtime by an adapter around
/// `InAppWebViewController`; faked in tests. Keeping this an abstraction is what
/// makes the wipe unit-testable without a live WebView (PROMPT.md §3, test list).
abstract class WipeableTab {
  /// Stop any in-flight page load.
  Future<void> stopLoading();

  /// Clear this WebView's back/forward history.
  Future<void> clearHistory();

  /// Clear `localStorage`/`sessionStorage` for the current document.
  Future<void> clearWebStorage();
}

/// App-wide (WebView-independent) privacy cleaners: cookies, cache and web
/// storage. Implemented by `InAppWebViewPrivacyCleaner` in privacy_config.dart;
/// faked in tests.
abstract class PrivacyCleaner {
  Future<void> deleteAllCookies();
  Future<void> clearAllCache();
  Future<void> deleteWebStorage();
}

/// The heart of the app: wipe everything, then close.
///
/// [trigger] runs the wipe steps in a fixed order (PROMPT.md §4.3). Every step
/// is individually guarded: if one fails, the rest still run and the app still
/// closes. The wipe must **never** abort halfway (PROMPT.md §10). A single tap
/// or the keyboard shortcut calls [trigger] with no confirmation dialog.
class PanicService {
  PanicService({
    required this.tabsProvider,
    required this.cleaner,
    required this.closer,
    this.onStateCleared,
  });

  /// Supplies the live list of wipeable tabs at trigger time.
  final List<WipeableTab> Function() tabsProvider;

  /// App-wide cookie/cache/storage cleaner.
  final PrivacyCleaner cleaner;

  /// Closes (or, on iOS, hides) the app after the wipe.
  final AppCloser closer;

  /// Called after storage is wiped to clear in-memory app state (tab list,
  /// current URL/title/favicon) before the app closes.
  final VoidCallback? onStateCleared;

  bool _inProgress = false;

  /// True once a wipe has started. Latched so a second trigger is a no-op
  /// (prevents re-entrancy from a double tap + shortcut firing together).
  bool get inProgress => _inProgress;

  /// Wipe all browsing data and close the app. Safe to call more than once.
  Future<void> trigger() async {
    if (_inProgress) return;
    _inProgress = true;

    // 1-2. Per tab: stop loading, clear history, clear DOM storage.
    for (final tab in tabsProvider()) {
      await _guard('tab.stopLoading', tab.stopLoading);
      await _guard('tab.clearHistory', tab.clearHistory);
      await _guard('tab.clearWebStorage', tab.clearWebStorage);
    }

    // 2 (global). Cookies, cache and web storage are app-wide, not per-tab.
    await _guard('deleteAllCookies', cleaner.deleteAllCookies);
    await _guard('clearAllCache', cleaner.clearAllCache);
    await _guard('deleteWebStorage', cleaner.deleteWebStorage);

    // 3-4. Drop controllers/tabs and reset app state (URL, title, favicon).
    _guardSync('onStateCleared', () => onStateCleared?.call());

    // 5. Close (or, on iOS, show the decoy). Guarded like everything else.
    await _guard('closeApp', closer.closeApp);
  }

  Future<void> _guard(String label, Future<void> Function() step) async {
    try {
      await step();
    } catch (error, stack) {
      // Log and continue — a wipe never aborts on a single failure.
      debugPrint('PanicService: step "$label" failed: $error\n$stack');
    }
  }

  void _guardSync(String label, void Function() step) {
    try {
      step();
    } catch (error, stack) {
      debugPrint('PanicService: step "$label" failed: $error\n$stack');
    }
  }
}
