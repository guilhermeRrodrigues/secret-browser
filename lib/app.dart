import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/keyboard_shortcuts.dart';
import 'core/panic_service.dart';
import 'core/platform_exit.dart';
import 'core/privacy_config.dart';
import 'features/browser/browser_screen.dart';
import 'features/browser/tab_manager.dart';
import 'features/panic/panic_overlay.dart';

/// Global navigator key — lets [DefaultAppCloser] reach the navigator to show
/// the iOS decoy screen without a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// The app-wide privacy cleaner (cookies/cache/web storage).
final privacyCleanerProvider = Provider<PrivacyCleaner>(
  (ref) => const InAppWebViewPrivacyCleaner(),
);

/// Closes (or, on iOS, hides) the app after a wipe.
final appCloserProvider = Provider<AppCloser>(
  (ref) => DefaultAppCloser(navigatorKey: appNavigatorKey),
);

/// The panic service, wired to the live tab list, the cleaner, the closer, and
/// the in-memory state reset.
final panicServiceProvider = Provider<PanicService>((ref) {
  final tabs = ref.read(tabManagerProvider.notifier);
  return PanicService(
    tabsProvider: tabs.wipeTargets,
    cleaner: ref.read(privacyCleanerProvider),
    closer: ref.read(appCloserProvider),
    onStateCleared: tabs.resetToBlank,
  );
});

/// Root of the app. Dark, minimalist theme (PROMPT.md §5).
class SecretBrowserApp extends StatelessWidget {
  const SecretBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C4DFF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Secret Browser',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const _Home(),
    );
  }
}

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void panic() => unawaited(ref.read(panicServiceProvider).trigger());
    return Scaffold(
      body: PanicShortcuts(
        onPanic: panic,
        child: PanicOverlay(
          onPanic: panic,
          child: const BrowserScreen(),
        ),
      ),
    );
  }
}
