import 'package:flutter_test/flutter_test.dart';
import 'package:secret_browser/core/panic_service.dart';
import 'package:secret_browser/core/platform_exit.dart';

/// Shared ordered log so tests can assert exactly which steps ran and when.
class _CallLog {
  final List<String> entries = <String>[];
  void add(String e) => entries.add(e);
}

class _FakeTab implements WipeableTab {
  _FakeTab(this.id, this._log, {this.throwOn = const <String>{}});

  final String id;
  final _CallLog _log;
  final Set<String> throwOn;

  @override
  Future<void> stopLoading() => _run('stopLoading');

  @override
  Future<void> clearHistory() => _run('clearHistory');

  @override
  Future<void> clearWebStorage() => _run('clearWebStorage');

  Future<void> _run(String step) async {
    _log.add('$id.$step');
    if (throwOn.contains(step)) {
      throw StateError('boom: $id.$step');
    }
  }
}

class _FakeCleaner implements PrivacyCleaner {
  _FakeCleaner(this._log, {this.throwOn = const <String>{}});

  final _CallLog _log;
  final Set<String> throwOn;

  @override
  Future<void> deleteAllCookies() => _run('deleteAllCookies');

  @override
  Future<void> clearAllCache() => _run('clearAllCache');

  @override
  Future<void> deleteWebStorage() => _run('deleteWebStorage');

  Future<void> _run(String step) async {
    _log.add('cleaner.$step');
    if (throwOn.contains(step)) {
      throw StateError('boom: cleaner.$step');
    }
  }
}

class _FakeCloser implements AppCloser {
  _FakeCloser(this._log, {this.shouldThrow = false});

  final _CallLog _log;
  final bool shouldThrow;
  int calls = 0;

  @override
  Future<void> closeApp() async {
    calls++;
    _log.add('closeApp');
    if (shouldThrow) {
      throw StateError('boom: closeApp');
    }
  }
}

void main() {
  group('PanicService.trigger', () {
    test('runs every step in order for each tab, then globals, then close',
        () async {
      final log = _CallLog();
      final tabs = [_FakeTab('t1', log), _FakeTab('t2', log)];
      var stateCleared = 0;
      final service = PanicService(
        tabsProvider: () => tabs,
        cleaner: _FakeCleaner(log),
        closer: _FakeCloser(log),
        onStateCleared: () {
          log.add('onStateCleared');
          stateCleared++;
        },
      );

      await service.trigger();

      expect(log.entries, [
        't1.stopLoading',
        't1.clearHistory',
        't1.clearWebStorage',
        't2.stopLoading',
        't2.clearHistory',
        't2.clearWebStorage',
        'cleaner.deleteAllCookies',
        'cleaner.clearAllCache',
        'cleaner.deleteWebStorage',
        'onStateCleared',
        'closeApp',
      ]);
      expect(stateCleared, 1);
    });

    test('with no tabs still clears globals and closes', () async {
      final log = _CallLog();
      final service = PanicService(
        tabsProvider: () => const [],
        cleaner: _FakeCleaner(log),
        closer: _FakeCloser(log),
        onStateCleared: () => log.add('onStateCleared'),
      );

      await service.trigger();

      expect(log.entries, [
        'cleaner.deleteAllCookies',
        'cleaner.clearAllCache',
        'cleaner.deleteWebStorage',
        'onStateCleared',
        'closeApp',
      ]);
    });

    test('a failing per-tab step does not abort the wipe (still closes)',
        () async {
      final log = _CallLog();
      final closer = _FakeCloser(log);
      final tabs = [
        _FakeTab('t1', log, throwOn: {'clearHistory'}),
        _FakeTab('t2', log),
      ];
      final service = PanicService(
        tabsProvider: () => tabs,
        cleaner: _FakeCleaner(log),
        closer: closer,
      );

      await service.trigger();

      // The throwing step ran, and everything after it still ran.
      expect(log.entries, containsAllInOrder([
        't1.clearHistory',
        't1.clearWebStorage', // continued after the failure
        't2.stopLoading',
        'cleaner.deleteAllCookies',
        'closeApp',
      ]));
      expect(closer.calls, 1);
    });

    test('a failing global cleaner does not stop later cleaners or close',
        () async {
      final log = _CallLog();
      final closer = _FakeCloser(log);
      final service = PanicService(
        tabsProvider: () => const [],
        cleaner: _FakeCleaner(log, throwOn: {'clearAllCache'}),
        closer: closer,
      );

      await service.trigger();

      expect(log.entries, [
        'cleaner.deleteAllCookies',
        'cleaner.clearAllCache', // threw
        'cleaner.deleteWebStorage', // still ran
        'closeApp',
      ]);
      expect(closer.calls, 1);
    });

    test('a failing closeApp does not throw out of trigger', () async {
      final log = _CallLog();
      final service = PanicService(
        tabsProvider: () => const [],
        cleaner: _FakeCleaner(log),
        closer: _FakeCloser(log, shouldThrow: true),
      );

      // Must complete normally despite closeApp throwing.
      await expectLater(service.trigger(), completes);
    });

    test('is idempotent: a second trigger is a no-op', () async {
      final log = _CallLog();
      final closer = _FakeCloser(log);
      final service = PanicService(
        tabsProvider: () => const [],
        cleaner: _FakeCleaner(log),
        closer: closer,
      );

      await service.trigger();
      await service.trigger();

      expect(closer.calls, 1);
      expect(service.inProgress, isTrue);
    });

    test('onStateCleared throwing does not prevent closeApp', () async {
      final log = _CallLog();
      final closer = _FakeCloser(log);
      final service = PanicService(
        tabsProvider: () => const [],
        cleaner: _FakeCleaner(log),
        closer: closer,
        onStateCleared: () => throw StateError('boom: state'),
      );

      await service.trigger();

      expect(closer.calls, 1);
    });
  });
}
