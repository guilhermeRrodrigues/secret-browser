import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'panic_service.dart';

/// Central privacy configuration for every [InAppWebView] in the app.
///
/// The guiding principle (see PROMPT.md §10) is *privacy above convenience*:
/// nothing about the user's browsing is written to disk. Cookies and storage
/// live only in memory and are destroyed on a wipe. This class also exposes the
/// preventive wipe that runs at startup so a crash can never leave stale data
/// behind.
///
/// Honest limit: this guarantees *local* anonymity only. It does not hide the
/// user's IP from sites or their ISP. Network anonymity (Tor/VPN) is roadmap,
/// not implemented — see README.
class PrivacyConfig {
  const PrivacyConfig._();

  /// Do-Not-Track request header. In flutter_inappwebview v6 custom headers are
  /// set on the [URLRequest], not on [InAppWebViewSettings].
  static const Map<String, String> dntHeaders = <String, String>{'DNT': '1'};

  /// The single source of truth for anonymous WebView settings.
  ///
  /// - `incognito: true` keeps cookies/storage in memory (no disk profile).
  /// - `cacheEnabled: false` avoids an on-disk HTTP cache. (The deprecated
  ///   `clearCache` setting is intentionally *not* used — actual clearing goes
  ///   through the static [InAppWebViewController.clearAllCache].)
  /// - `databaseEnabled: false` disables the legacy Web SQL database on disk.
  /// - `thirdPartyCookiesEnabled: false` blocks third-party cookies.
  /// - `isInspectable: false` disables remote inspection of a privacy surface.
  ///
  /// DOM storage is left enabled at runtime so sites function; it never touches
  /// disk under incognito and is cleared on every wipe (PROMPT.md §4.1).
  static InAppWebViewSettings buildSettings() {
    return InAppWebViewSettings(
      incognito: true,
      cacheEnabled: false,
      databaseEnabled: false,
      thirdPartyCookiesEnabled: false,
      isInspectable: false,
      javaScriptEnabled: true,
      transparentBackground: false,
    );
  }

  /// Builds a [URLRequest] for [url] carrying the DNT header.
  static URLRequest buildUrlRequest(WebUri url) {
    return URLRequest(url: url, headers: dntHeaders);
  }
}

/// App-wide, WebView-instance-independent cleaners (cookies, cache, web
/// storage). These wrap the plugin's global managers. In v6:
/// - [CookieManager.deleteAllCookies] is per-instance and async.
/// - [InAppWebViewController.clearAllCache] is **static**.
/// - [WebStorageManager.deleteAllData] clears Application Cache, Web SQL and
///   HTML5 Web Storage.
///
/// Note (GitHub #511/#1532): incognito profile isolation has known bugs on
/// macOS/Windows, so we always clear these explicitly rather than trusting the
/// incognito flag alone.
class InAppWebViewPrivacyCleaner implements PrivacyCleaner {
  const InAppWebViewPrivacyCleaner();

  @override
  Future<void> deleteAllCookies() async {
    await CookieManager.instance().deleteAllCookies();
  }

  @override
  Future<void> clearAllCache() async {
    await InAppWebViewController.clearAllCache();
  }

  @override
  Future<void> deleteWebStorage() async {
    await WebStorageManager.instance().deleteAllData();
  }
}

/// Runs a best-effort wipe of all persisted browsing artifacts. Every step is
/// guarded so one failing manager never blocks the others — this is used both
/// at startup (preventive) and can be reused by the panic wipe.
///
/// Returns normally even if some steps fail; the wipe must never abort halfway
/// (PROMPT.md §10).
Future<void> preventiveWipe({
  InAppWebViewPrivacyCleaner cleaner = const InAppWebViewPrivacyCleaner(),
}) async {
  Future<void> guard(String label, Future<void> Function() step) async {
    try {
      await step();
    } catch (error, stack) {
      // Never abort a wipe on failure — log and continue.
      debugPrint('preventiveWipe: "$label" failed: $error\n$stack');
    }
  }

  await guard('deleteAllCookies', cleaner.deleteAllCookies);
  await guard('clearAllCache', cleaner.clearAllCache);
  await guard('deleteWebStorage', cleaner.deleteWebStorage);
}
