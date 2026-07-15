import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secret_browser/app.dart';
import 'package:secret_browser/core/platform_exit.dart';
import 'package:secret_browser/core/privacy_config.dart';

/// Records closeApp instead of terminating, so the panic path can be observed
/// end-to-end without killing the test process.
class _RecordingCloser implements AppCloser {
  int calls = 0;
  @override
  Future<void> closeApp() async => calls++;
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 200);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads a real site then panic-wipes and resets', (tester) async {
    // The preventive wipe runs against the real macOS WebView managers.
    await preventiveWipe();

    final closer = _RecordingCloser();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appCloserProvider.overrideWithValue(closer)],
        child: const SecretBrowserApp(),
      ),
    );
    await tester.pump();

    // Boots to a blank anonymous start tab.
    expect(find.text('Secret Browser'), findsOneWidget);
    expect(find.byType(InAppWebView), findsNothing);

    // Navigate to a real site via the address bar.
    await tester.enterText(
        find.byKey(const Key('addressBarField')), 'https://example.com');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();

    // A live WebView is created for the tab and the page loads.
    expect(find.byType(InAppWebView), findsOneWidget);
    await _pumpFor(tester, const Duration(seconds: 5));

    // Panic: tap the floating X. The real cookie/cache/storage cleaners run.
    await tester.tap(find.byKey(const Key('panicButton')));
    await _pumpFor(tester, const Duration(seconds: 3));

    // Wipe path executed: app was asked to close exactly once...
    expect(closer.calls, 1);
    // ...and state reset to a single blank start tab (WebView gone).
    expect(find.byType(InAppWebView), findsNothing);
    expect(find.text('Secret Browser'), findsOneWidget);
  });
}
