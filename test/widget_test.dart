import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_browser/app.dart';

void main() {
  testWidgets('boots to a blank anonymous start tab with the panic button',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SecretBrowserApp()));
    await tester.pump();

    // Start page brand + anonymous indicator are shown.
    expect(find.text('Secret Browser'), findsOneWidget);
    expect(find.text('Anônimo'), findsOneWidget);

    // The floating panic "X" is present (and it's the only close icon so far).
    expect(find.byIcon(Icons.close), findsOneWidget);

    // One tab to start with.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('the new-tab button opens another in-memory tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SecretBrowserApp()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Tab counter reflects the second tab.
    expect(find.text('2'), findsOneWidget);
  });
}
