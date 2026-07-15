import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/privacy_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Preventive wipe on boot: guarantees a clean state even after a crash left
  // stale data behind (PROMPT.md §4.1). Guarded internally, so it never blocks
  // startup — fire and forget.
  unawaited(preventiveWipe());

  runApp(const ProviderScope(child: SecretBrowserApp()));
}
