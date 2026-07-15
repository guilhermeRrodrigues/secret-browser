import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Abstraction over "close the app" so [PanicService] never depends directly on
/// platform APIs and can be unit-tested with a fake.
abstract class AppCloser {
  /// Terminates (or, on iOS, hides) the app. Must not throw.
  Future<void> closeApp();
}

/// Platform-aware implementation of [AppCloser].
///
/// - **Android / Windows / macOS** → `SystemNavigator.pop()` then `exit(0)`:
///   the app really closes, as the user asked ("apagar tudo e fechar").
/// - **iOS** → we must NOT call `exit(0)`: Apple rejects apps that
///   self-terminate (it reads as a crash and is grounds for App Store
///   rejection). Instead we replace the UI with an innocuous [DecoyScreen]
///   (a plain calculator) so nothing browsed remains on screen.
///
/// The iOS decoy needs a way to reach the navigator; pass the app's
/// [navigatorKey]. See README for the platform rationale.
class DefaultAppCloser implements AppCloser {
  DefaultAppCloser({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<void> closeApp() async {
    if (Platform.isIOS) {
      _showDecoy();
      return;
    }
    // Android: finish the activity gracefully first.
    await SystemNavigator.pop();
    // Desktop (macOS/Windows) and any Android that survived pop(): hard stop.
    exit(0);
  }

  void _showDecoy() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DecoyScreen()),
      (route) => false,
    );
  }
}

/// iOS-only fallback shown instead of self-terminating: an inert, offline
/// calculator. It holds no browsing state and makes no network calls.
class DecoyScreen extends StatefulWidget {
  const DecoyScreen({super.key});

  @override
  State<DecoyScreen> createState() => _DecoyScreenState();
}

class _DecoyScreenState extends State<DecoyScreen> {
  String _display = '0';
  double? _accumulator;
  String? _pendingOp;
  bool _startNewEntry = true;

  void _onKey(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _display = '0';
          _accumulator = null;
          _pendingOp = null;
          _startNewEntry = true;
        case '+':
        case '−':
        case '×':
        case '÷':
          _applyPending();
          _pendingOp = key;
          _startNewEntry = true;
        case '=':
          _applyPending();
          _pendingOp = null;
          _startNewEntry = true;
        case '.':
          if (_startNewEntry) {
            _display = '0.';
            _startNewEntry = false;
          } else if (!_display.contains('.')) {
            _display = '$_display.';
          }
        default:
          if (_startNewEntry || _display == '0') {
            _display = key;
            _startNewEntry = false;
          } else {
            _display = '$_display$key';
          }
      }
    });
  }

  void _applyPending() {
    final current = double.tryParse(_display) ?? 0;
    final acc = _accumulator;
    if (_pendingOp == null || acc == null) {
      _accumulator = current;
      return;
    }
    final result = switch (_pendingOp) {
      '+' => acc + current,
      '−' => acc - current,
      '×' => acc * current,
      '÷' => current == 0 ? double.nan : acc / current,
      _ => current,
    };
    _accumulator = result;
    _display = _format(result);
  }

  String _format(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    const keys = <String>[
      'C', '÷', '×', '−',
      '7', '8', '9', '+',
      '4', '5', '6', '=',
      '1', '2', '3', '.',
      '0',
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(24),
                child: FittedBox(
                  child: Text(
                    _display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final key in keys)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade900,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                      onPressed: () => _onKey(key),
                      child: Text(key, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
