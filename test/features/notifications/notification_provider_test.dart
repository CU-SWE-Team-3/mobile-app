import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/notifications/presentation/providers/notification_provider.dart';

class _MockDioClient extends Mock implements DioClient {}

class _MockDio extends Mock implements Dio {}

Response<dynamic> _response(dynamic data, {String path = ''}) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

DioException _dioError(String path) => DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        data: {'message': 'server error'},
      ),
    );

Map<String, dynamic> _notificationJson({
  String id = 'n1',
  String type = 'LIKE',
  bool isRead = false,
  int actorCount = 1,
  String actorId = 'u1',
  String actorName = 'Mona',
  String actorPermalink = '@mona',
  String? trackTitle = 'Night Drive',
  String? commentText,
  DateTime? createdAt,
}) =>
    {
      '_id': id,
      'type': type,
      'actors': [
        {
          '_id': actorId,
          'displayName': actorName,
          'avatarUrl': 'https://example.com/avatar.png',
          'permalink': actorPermalink,
        }
      ],
      'actorCount': actorCount,
      'target': {'title': trackTitle},
      'contentSnippet': commentText,
      'isRead': isRead,
      'createdAt': (createdAt ?? DateTime(2026, 5, 3)).toIso8601String(),
    };

NotificationNotifier _notifier(_MockDio dio) {
  final client = _MockDioClient();
  when(() => client.dio).thenReturn(dio);
  when(() => dio.options).thenReturn(BaseOptions());
  return NotificationNotifier(client);
}

void main() {
  late _MockDio dio;
  late NotificationNotifier notifier;

  setUp(() {
    dio = _MockDio();
    notifier = _notifier(dio);
  });

  group('NotificationType', () {
    test('parses all backend enum values and falls back to system', () {
      expect(NotificationType.fromString('FOLLOW'), NotificationType.follow);
      expect(NotificationType.fromString('LIKE'), NotificationType.like);
      expect(NotificationType.fromString('REPOST'), NotificationType.repost);
      expect(NotificationType.fromString('COMMENT'), NotificationType.comment);
      expect(NotificationType.fromString('MESSAGE'), NotificationType.message);
      expect(NotificationType.fromString('NEW_TRACK'), NotificationType.newTrack);
      expect(
        NotificationType.fromString('NEW_PLAYLIST'),
        NotificationType.newPlaylist,
      );
      expect(NotificationType.fromString('MENTION'), NotificationType.mention);
      expect(NotificationType.fromString('unexpected'), NotificationType.system);
    });
  });

  group('AppNotification', () {
    test('fromJson maps actor, target, count, read state, and timestamp', () {
      final item = AppNotification.fromJson(_notificationJson(
        type: 'COMMENT',
        actorCount: 3,
        commentText: 'Great drop',
      ));

      expect(item.id, 'n1');
      expect(item.type, NotificationType.comment);
      expect(item.actorId, 'u1');
      expect(item.actorName, 'Mona');
      expect(item.actorAvatarUrl, 'https://example.com/avatar.png');
      expect(item.actorPermalink, '@mona');
      expect(item.actorCount, 3);
      expect(item.trackTitle, 'Night Drive');
      expect(item.commentText, 'Great drop');
      expect(item.isRead, isFalse);
      expect(item.createdAt, DateTime(2026, 5, 3));
    });

    test('fromJson supports alternate ids and missing actor data', () {
      final item = AppNotification.fromJson({
        'notificationId': 'fallback-id',
        'type': 'UNKNOWN',
        'createdAt': '2026-05-03T00:00:00.000',
      });

      expect(item.id, 'fallback-id');
      expect(item.type, NotificationType.system);
      expect(item.actorId, '');
      expect(item.actorName, 'Unknown');
      expect(item.actorCount, 0);
      expect(item.isRead, isFalse);
    });

    test('copyWith replaces every mutable field and preserves omitted values', () {
      final original = AppNotification.fromJson(_notificationJson());
      final updated = original.copyWith(
        id: 'n2',
        type: NotificationType.follow,
        actorId: 'u2',
        actorName: 'Omar',
        actorAvatarUrl: 'https://example.com/omar.png',
        actorPermalink: '@omar',
        actorCount: 2,
        trackTitle: 'Sunrise',
        commentText: 'hello',
        isRead: true,
        createdAt: DateTime(2026, 5, 2),
      );

      expect(updated.id, 'n2');
      expect(updated.type, NotificationType.follow);
      expect(updated.actorId, 'u2');
      expect(updated.actorName, 'Omar');
      expect(updated.actorAvatarUrl, 'https://example.com/omar.png');
      expect(updated.actorPermalink, '@omar');
      expect(updated.actorCount, 2);
      expect(updated.trackTitle, 'Sunrise');
      expect(updated.commentText, 'hello');
      expect(updated.isRead, isTrue);
      expect(updated.createdAt, DateTime(2026, 5, 2));
      expect(original.copyWith().id, original.id);
    });
  });

  group('NotificationState', () {
    test('uses server unread count before local count and filters by type', () {
      final like = AppNotification.fromJson(_notificationJson(id: 'like'));
      final readComment = AppNotification.fromJson(_notificationJson(
        id: 'comment',
        type: 'COMMENT',
        isRead: true,
      ));
      final state = NotificationState(
        notifications: [like, readComment],
        activeFilter: NotificationType.comment,
        serverUnreadCount: 9,
      );

      expect(state.unreadCount, 9);
      expect(state.filtered, [readComment]);
      expect(
        state.copyWith(serverUnreadCount: null).unreadCount,
        9,
        reason: 'copyWith keeps the existing server count when omitted',
      );
      expect(
        NotificationState(notifications: [like, readComment]).unreadCount,
        1,
      );
    });

    test('copyWith can clear error and filter', () {
      const state = NotificationState(
        error: 'boom',
        activeFilter: NotificationType.like,
      );

      final updated = state.copyWith(clearError: true, clearFilter: true);

      expect(updated.error, isNull);
      expect(updated.activeFilter, isNull);
    });
  });

  group('NotificationNotifier network reads', () {
    test('fetchNotifications loads unique items and keeps locally read ids read',
        () async {
      when(() => dio.patch('/notifications/n1/read'))
          .thenAnswer((_) async => _response({}));
      notifier.socketAddNotification(_notificationJson(id: 'n1'));
      await notifier.markAsRead('n1');

      when(() => dio.get('/notifications')).thenAnswer(
        (_) async => _response({
          'data': {
            'notifications': [
              _notificationJson(id: 'n1', isRead: false),
              _notificationJson(id: 'n2', type: 'FOLLOW'),
              _notificationJson(id: 'n2', type: 'FOLLOW'),
            ],
          },
        }),
      );

      await notifier.fetchNotifications();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.notifications.map((n) => n.id), ['n1', 'n2']);
      expect(notifier.state.notifications.first.isRead, isTrue);
    });

    test('fetchNotifications records errors and stops loading', () async {
      when(() => dio.get('/notifications')).thenThrow(_dioError('/notifications'));

      await notifier.fetchNotifications();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, contains('DioException'));
    });

    test('fetchUnreadCount stores server count and ignores failures', () async {
      when(() => dio.get('/notifications/unread-count')).thenAnswer(
        (_) async => _response({
          'data': {'unreadCount': 4},
        }),
      );

      await notifier.fetchUnreadCount();

      expect(notifier.state.serverUnreadCount, 4);

      when(() => dio.get('/notifications/unread-count'))
          .thenThrow(_dioError('/notifications/unread-count'));
      await notifier.fetchUnreadCount();

      expect(notifier.state.serverUnreadCount, 4);
    });

    test('registerFcmToken posts token and swallows failures', () async {
      when(() => dio.post('/notifications/fcm-token', data: any(named: 'data')))
          .thenAnswer((_) async => _response({}));

      await notifier.registerFcmToken('abc');

      final firstBody = verify(() => dio.post('/notifications/fcm-token',
          data: captureAny(named: 'data'))).captured.single;
      expect(firstBody, {'token': 'abc'});

      when(() => dio.post('/notifications/fcm-token', data: any(named: 'data')))
          .thenThrow(_dioError('/notifications/fcm-token'));

      await notifier.registerFcmToken('bad');
      final secondBody = verify(() => dio.post('/notifications/fcm-token',
          data: captureAny(named: 'data'))).captured.single;
      expect(secondBody, {'token': 'bad'});
    });
  });

  group('NotificationNotifier mutations', () {
    setUp(() {
      notifier.socketAddNotification(_notificationJson(id: 'n1'));
      notifier.socketAddNotification(_notificationJson(id: 'n2', type: 'COMMENT'));
    });

    test('markAsRead is optimistic, decrements count, and patches server',
        () async {
      notifier.state = notifier.state.copyWith(serverUnreadCount: 2);
      when(() => dio.patch('/notifications/n1/read'))
          .thenAnswer((_) async => _response({}));

      await notifier.markAsRead('n1');

      expect(notifier.state.notifications.firstWhere((n) => n.id == 'n1').isRead,
          isTrue);
      expect(notifier.state.serverUnreadCount, 1);
      verify(() => dio.patch('/notifications/n1/read')).called(1);
    });

    test('markAsRead ignores empty ids and keeps optimistic update on failure',
        () async {
      await notifier.markAsRead('');
      verifyNever(() => dio.patch(any()));

      when(() => dio.patch('/notifications/n1/read'))
          .thenThrow(_dioError('/notifications/n1/read'));
      await notifier.markAsRead('n1');

      expect(notifier.state.notifications.firstWhere((n) => n.id == 'n1').isRead,
          isTrue);
    });

    test('markAllAsRead updates all items and zeroes server count on success',
        () async {
      notifier.state = notifier.state.copyWith(serverUnreadCount: 2);
      when(() => dio.patch('/notifications/mark-read'))
          .thenAnswer((_) async => _response({}));

      await notifier.markAllAsRead();

      expect(notifier.state.notifications.every((n) => n.isRead), isTrue);
      expect(notifier.state.serverUnreadCount, 0);
    });

    test('markAllAsRead leaves state unchanged on failure', () async {
      when(() => dio.patch('/notifications/mark-read'))
          .thenThrow(_dioError('/notifications/mark-read'));

      await notifier.markAllAsRead();

      expect(notifier.state.notifications.where((n) => !n.isRead).length, 2);
    });

    test('deleteNotification removes item and decrements unread count on success',
        () async {
      notifier.state = notifier.state.copyWith(serverUnreadCount: 2);
      when(() => dio.delete('/notifications/n1'))
          .thenAnswer((_) async => _response({}));

      await notifier.deleteNotification('n1');

      expect(notifier.state.notifications.map((n) => n.id), ['n2']);
      expect(notifier.state.serverUnreadCount, 1);
    });

    test('deleteNotification leaves state unchanged on failure', () async {
      when(() => dio.delete('/notifications/n1'))
          .thenThrow(_dioError('/notifications/n1'));

      await notifier.deleteNotification('n1');

      expect(notifier.state.notifications.map((n) => n.id), ['n2', 'n1']);
    });

    test('setFilter applies and clears filters', () {
      notifier.setFilter(NotificationType.comment);
      expect(notifier.state.filtered.map((n) => n.id), ['n2']);

      notifier.setFilter(null);
      expect(notifier.state.activeFilter, isNull);
    });
  });

  group('NotificationNotifier socket events', () {
    test('adds newest first, deduplicates, ignores invalid data, and counts unread',
        () {
      notifier.socketAddNotification(_notificationJson(id: 'n1'));
      notifier.socketAddNotification(_notificationJson(id: 'n2', isRead: true));
      notifier.socketAddNotification(_notificationJson(id: 'n1', type: 'FOLLOW'));
      notifier.socketAddNotification({
        '_id': '',
        'type': 'LIKE',
        'createdAt': DateTime(2026, 5, 3).toIso8601String(),
      });
      notifier.socketAddNotification({'bad': Object()});

      expect(notifier.state.notifications.map((n) => n.id), ['n1', 'n2']);
      expect(notifier.state.notifications.first.type, NotificationType.follow);
      expect(notifier.state.serverUnreadCount, 1);
    });

    test('socket read, mark-all-read, and remove update state and counts', () {
      notifier.socketAddNotification(_notificationJson(id: 'n1'));
      notifier.socketAddNotification(_notificationJson(id: 'n2'));
      expect(notifier.state.serverUnreadCount, 2);

      notifier.socketMarkNotificationRead('n1');
      expect(notifier.state.notifications.firstWhere((n) => n.id == 'n1').isRead,
          isTrue);
      expect(notifier.state.serverUnreadCount, 1);

      notifier.socketRemoveNotification('n2');
      expect(notifier.state.notifications.map((n) => n.id), ['n1']);
      expect(notifier.state.serverUnreadCount, 0);

      notifier.socketAddNotification(_notificationJson(id: 'n3'));
      notifier.socketMarkAllRead();
      expect(notifier.state.notifications.every((n) => n.isRead), isTrue);
      expect(notifier.state.serverUnreadCount, 0);
    });
  });

  group('NotificationPreferences', () {
    test('fromJson defaults missing fields and toJson emits every setting', () {
      final prefs = NotificationPreferences.fromJson({
        'pushEnabled': false,
        'allowLikes': false,
        'messagePermission': 'Following',
      });

      expect(prefs.pushEnabled, isFalse);
      expect(prefs.allowLikes, isFalse);
      expect(prefs.allowComments, isTrue);
      expect(prefs.messagePermission, 'Following');
      expect(prefs.toJson(), {
        'pushEnabled': false,
        'allowLikes': false,
        'allowReposts': true,
        'allowComments': true,
        'allowFollows': true,
        'allowMessages': true,
        'allowNewTracks': true,
        'allowNewPlaylists': true,
        'allowMentions': true,
        'allowSystem': true,
        'messagePermission': 'Following',
      });
    });

    test('copyWith can update every preference', () {
      final prefs = NotificationPreferences.defaults.copyWith(
        pushEnabled: false,
        allowLikes: false,
        allowReposts: false,
        allowComments: false,
        allowFollows: false,
        allowMessages: false,
        allowNewTracks: false,
        allowNewPlaylists: false,
        allowMentions: false,
        allowSystem: false,
        messagePermission: 'Following',
      );

      expect(prefs.toJson().values.where((value) => value == false).length, 10);
      expect(prefs.messagePermission, 'Following');
    });
  });

  group('PreferencesNotifier', () {
    test('fetchPreferences loads server values and failure keeps defaults',
        () async {
      final prefsNotifier = PreferencesNotifier(_clientFor(dio));
      when(() => dio.get('/notifications/preferences')).thenAnswer(
        (_) async => _response({
          'data': {'pushEnabled': false, 'allowMessages': false},
        }),
      );

      await prefsNotifier.fetchPreferences();

      expect(prefsNotifier.state.isLoading, isFalse);
      expect(prefsNotifier.state.preferences.pushEnabled, isFalse);
      expect(prefsNotifier.state.preferences.allowMessages, isFalse);

      when(() => dio.get('/notifications/preferences'))
          .thenThrow(_dioError('/notifications/preferences'));
      await prefsNotifier.fetchPreferences();

      expect(prefsNotifier.state.isLoading, isFalse);
      expect(prefsNotifier.state.preferences.pushEnabled, isFalse);
    });

    test('updatePreferences saves optimistically and rolls back on failure',
        () async {
      final prefsNotifier = PreferencesNotifier(_clientFor(dio));
      final updated = NotificationPreferences.defaults.copyWith(
        allowLikes: false,
      );
      when(() => dio.patch('/notifications/preferences', data: any(named: 'data')))
          .thenAnswer((_) async => _response({}));

      expect(await prefsNotifier.updatePreferences(updated), isTrue);
      expect(prefsNotifier.state.preferences.allowLikes, isFalse);
      expect(prefsNotifier.state.isSaving, isFalse);

      final failed = updated.copyWith(allowComments: false);
      when(() => dio.patch('/notifications/preferences', data: any(named: 'data')))
          .thenThrow(_dioError('/notifications/preferences'));

      expect(await prefsNotifier.updatePreferences(failed), isFalse);
      expect(prefsNotifier.state.preferences, updated);
      expect(prefsNotifier.state.isSaving, isFalse);
    });
  });
}

DioClient _clientFor(_MockDio dio) {
  final client = _MockDioClient();
  when(() => client.dio).thenReturn(dio);
  return client;
}
