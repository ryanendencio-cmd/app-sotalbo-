import 'package:flutter_test/flutter_test.dart';
import 'package:buildtrack/services/api_service.dart';

void main() {
  group('ApiService.resolveBaseUrl', () {
    test('uses the configured backend URL and removes trailing slashes', () {
      expect(
        ApiService.resolveBaseUrl(
          configured: 'https://api.example.com/api///',
          isReleaseMode: true,
          isAndroid: true,
          androidHost: '10.0.2.2',
        ),
        'https://api.example.com/api',
      );
    });

    test('requires a backend URL for release builds', () {
      expect(
        () => ApiService.resolveBaseUrl(
          configured: '',
          isReleaseMode: true,
          isAndroid: true,
          androidHost: '10.0.2.2',
        ),
        throwsStateError,
      );
    });

    test('uses the configured host for local Android development', () {
      expect(
        ApiService.resolveBaseUrl(
          configured: '',
          isReleaseMode: false,
          isAndroid: true,
          androidHost: '192.168.1.20',
        ),
        'http://192.168.1.20:5000/api',
      );
    });
  });
}
