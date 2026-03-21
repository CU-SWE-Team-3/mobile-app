import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('appName should be SoundCloud', () {
      expect(AppConstants.appName, 'SoundCloud');
    });

    test('googleAndroidClientId should be correct', () {
      expect(AppConstants.googleAndroidClientId,
          '718123581836-1kee9i09ce4h2teu8rp6b722eppbdmeu.apps.googleusercontent.com');
    });

    test('tokenKey should be auth_token', () {
      expect(AppConstants.tokenKey, 'auth_token');
    });

    test('userKey should be current_user', () {
      expect(AppConstants.userKey, 'current_user');
    });

    test('pageSize should be 20', () {
      expect(AppConstants.pageSize, 20);
    });
  });
}