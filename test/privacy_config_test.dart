import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_browser/core/privacy_config.dart';

void main() {
  group('PrivacyConfig.buildSettings', () {
    late InAppWebViewSettings settings;

    setUp(() {
      settings = PrivacyConfig.buildSettings();
    });

    test('enables incognito (in-memory cookies/storage, no disk profile)', () {
      expect(settings.incognito, isTrue);
    });

    test('disables the on-disk HTTP cache', () {
      expect(settings.cacheEnabled, isFalse);
    });

    test('disables the legacy on-disk Web SQL database', () {
      expect(settings.databaseEnabled, isFalse);
    });

    test('blocks third-party cookies', () {
      expect(settings.thirdPartyCookiesEnabled, isFalse);
    });

    test('disables remote inspection of the privacy surface', () {
      expect(settings.isInspectable, isFalse);
    });

    test('keeps JavaScript on so sites function', () {
      expect(settings.javaScriptEnabled, isTrue);
    });
  });

  group('PrivacyConfig.dntHeaders', () {
    test('sends Do-Not-Track', () {
      expect(PrivacyConfig.dntHeaders, containsPair('DNT', '1'));
    });
  });

  group('PrivacyConfig.buildUrlRequest', () {
    test('carries the DNT header and the requested URL', () {
      final url = WebUri('https://example.com/');
      final request = PrivacyConfig.buildUrlRequest(url);

      expect(request.url, url);
      expect(request.headers, containsPair('DNT', '1'));
    });
  });
}
