import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundcloud_clone/core/network/user_session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserSession', () {
    test('getUserId null when not set, correct value when set', () async {
      // Not set
      final result1 = await UserSession.getUserId();
      expect(result1, null);

      // Set
      SharedPreferences.setMockInitialValues({'userId': 'test_user_id'});
      final result2 = await UserSession.getUserId();
      expect(result2, 'test_user_id');
    });

    test('getDisplayName null when not set, correct value when set', () async {
      // Not set
      final result1 = await UserSession.getDisplayName();
      expect(result1, null);

      // Set
      SharedPreferences.setMockInitialValues({'displayName': 'Test User'});
      final result2 = await UserSession.getDisplayName();
      expect(result2, 'Test User');
    });

    test('getAccessToken null when not set, correct value when set', () async {
      // Not set
      final result1 = await UserSession.getAccessToken();
      expect(result1, null);

      // Set
      SharedPreferences.setMockInitialValues({'accessToken': 'test_token'});
      final result2 = await UserSession.getAccessToken();
      expect(result2, 'test_token');
    });

    test('clear clears all values, completes without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'userId': 'test',
        'displayName': 'test',
        'accessToken': 'test',
      });

      await expectLater(UserSession.clear(), completes);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userId'), null);
      expect(prefs.getString('displayName'), null);
      expect(prefs.getString('accessToken'), null);
    });
  });
}