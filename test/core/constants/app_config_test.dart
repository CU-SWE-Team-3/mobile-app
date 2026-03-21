import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/core/constants/app_config.dart';

void main() {
  group('AppConfig', () {
    test('useMockData should be true', () {
      expect(AppConfig.useMockData, true);
    });

    test('baseUrl should be correct', () {
      expect(AppConfig.baseUrl, 'http://localhost:3000/api');
    });
  });
}