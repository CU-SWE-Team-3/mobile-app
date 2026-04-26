import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/notification.dart';
import 'package:flutter/foundation.dart';
export '../../domain/entities/notification.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final NotificationType? activeFilter;
  final int? serverUnreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.activeFilter,
    this.serverUnreadCount,
  });

  // Prefers the server-authoritative count; falls back to local count for
  // the paginated list (which may be incomplete).
  int get unreadCount =>
      serverUnreadCount ?? notifications.where((n) => !n.isRead).length;

  List<AppNotification> get filtered {
    final f = activeFilter;
    if (f == null) return notifications;
    return notifications.where((n) => n.type == f).toList();
  }

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    bool clearError = false,
    NotificationType? activeFilter,
    bool clearFilter = false,
    int? serverUnreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      serverUnreadCount: serverUnreadCount ?? this.serverUnreadCount,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class NotificationNotifier extends StateNotifier<NotificationState> {
  final DioClient _dioClient;

  NotificationNotifier(this._dioClient) : super(const NotificationState());

 Future<void> fetchNotifications() async {
  debugPrint('[Notifications] token: ${_dioClient.dio.options.headers['Authorization']}');
  state = state.copyWith(isLoading: true, clearError: true);
  try {
      final res = await _dioClient.dio.get('/notifications');
      final data = res.data['data'] as Map<String, dynamic>;
      final raw = data['notifications'] as List<dynamic>;
      final items = raw
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(notifications: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _dioClient.dio.get('/notifications/unread-count');
      final count =
          (res.data['data'] as Map<String, dynamic>)['unreadCount'] as int;
      state = state.copyWith(serverUnreadCount: count);
    } catch (e) {
      debugPrint('[Notifications] fetchUnreadCount failed: $e');
    }
  }

  // Registers the device's FCM push token with the backend so the server can
  // deliver push notifications to this device.
  //
  // TODO: Add firebase_messaging to pubspec.yaml, then retrieve the real token
  // and call this method from the splash page:
  //   FirebaseMessaging.instance.getToken().then((t) {
  //     if (t != null) notifier.registerFcmToken(t);
  //   });
  Future<void> registerFcmToken(String token) async {
    try {
      await _dioClient.dio.post(
        '/notifications/fcm-token',
        data: {'token': token},
      );
      debugPrint('[Notifications] FCM token registered');
    } catch (e) {
      debugPrint('[Notifications] registerFcmToken failed: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dioClient.dio.patch('/notifications/$id/read');
      final wasUnread =
          state.notifications.any((n) => n.id == id && !n.isRead);
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
        serverUnreadCount:
            (wasUnread && state.serverUnreadCount != null && state.serverUnreadCount! > 0)
                ? state.serverUnreadCount! - 1
                : state.serverUnreadCount,
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _dioClient.dio.patch('/notifications/mark-read');
      state = state.copyWith(
        notifications:
            state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
        serverUnreadCount: 0,
      );
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _dioClient.dio.delete('/notifications/$id');
      final wasUnread =
          state.notifications.any((n) => n.id == id && !n.isRead);
      state = state.copyWith(
        notifications: state.notifications.where((n) => n.id != id).toList(),
        serverUnreadCount:
            (wasUnread && state.serverUnreadCount != null && state.serverUnreadCount! > 0)
                ? state.serverUnreadCount! - 1
                : state.serverUnreadCount,
      );
    } catch (_) {}
  }

  void setFilter(NotificationType? filter) {
    if (filter == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(activeFilter: filter);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(ref.read(dioClientProvider)),
);

// ── Notification Preferences ───────────────────────────────────────────────────

class NotificationPreferences {
  final bool pushEnabled;
  final bool allowLikes;
  final bool allowReposts;
  final bool allowComments;
  final bool allowFollows;
  final bool allowMessages;
  final bool allowNewTracks;
  final bool allowNewPlaylists;
  final bool allowMentions;
  final bool allowSystem;

  const NotificationPreferences({
    required this.pushEnabled,
    required this.allowLikes,
    required this.allowReposts,
    required this.allowComments,
    required this.allowFollows,
    required this.allowMessages,
    required this.allowNewTracks,
    required this.allowNewPlaylists,
    required this.allowMentions,
    required this.allowSystem,
  });

  static const defaults = NotificationPreferences(
    pushEnabled: true,
    allowLikes: true,
    allowReposts: true,
    allowComments: true,
    allowFollows: true,
    allowMessages: true,
    allowNewTracks: true,
    allowNewPlaylists: true,
    allowMentions: true,
    allowSystem: true,
  );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      allowLikes: json['allowLikes'] as bool? ?? true,
      allowReposts: json['allowReposts'] as bool? ?? true,
      allowComments: json['allowComments'] as bool? ?? true,
      allowFollows: json['allowFollows'] as bool? ?? true,
      allowMessages: json['allowMessages'] as bool? ?? true,
      allowNewTracks: json['allowNewTracks'] as bool? ?? true,
      allowNewPlaylists: json['allowNewPlaylists'] as bool? ?? true,
      allowMentions: json['allowMentions'] as bool? ?? true,
      allowSystem: json['allowSystem'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'allowLikes': allowLikes,
        'allowReposts': allowReposts,
        'allowComments': allowComments,
        'allowFollows': allowFollows,
        'allowMessages': allowMessages,
        'allowNewTracks': allowNewTracks,
        'allowNewPlaylists': allowNewPlaylists,
        'allowMentions': allowMentions,
        'allowSystem': allowSystem,
      };

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? allowLikes,
    bool? allowReposts,
    bool? allowComments,
    bool? allowFollows,
    bool? allowMessages,
    bool? allowNewTracks,
    bool? allowNewPlaylists,
    bool? allowMentions,
    bool? allowSystem,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      allowLikes: allowLikes ?? this.allowLikes,
      allowReposts: allowReposts ?? this.allowReposts,
      allowComments: allowComments ?? this.allowComments,
      allowFollows: allowFollows ?? this.allowFollows,
      allowMessages: allowMessages ?? this.allowMessages,
      allowNewTracks: allowNewTracks ?? this.allowNewTracks,
      allowNewPlaylists: allowNewPlaylists ?? this.allowNewPlaylists,
      allowMentions: allowMentions ?? this.allowMentions,
      allowSystem: allowSystem ?? this.allowSystem,
    );
  }
}

class PreferencesState {
  final NotificationPreferences preferences;
  final bool isLoading;
  final bool isSaving;

  const PreferencesState({
    this.preferences = NotificationPreferences.defaults,
    this.isLoading = false,
    this.isSaving = false,
  });

  PreferencesState copyWith({
    NotificationPreferences? preferences,
    bool? isLoading,
    bool? isSaving,
  }) {
    return PreferencesState(
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class PreferencesNotifier extends StateNotifier<PreferencesState> {
  final DioClient _dioClient;

  PreferencesNotifier(this._dioClient) : super(const PreferencesState());

  Future<void> fetchPreferences() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _dioClient.dio.get('/notifications/preferences');
      final data = res.data['data'] as Map<String, dynamic>;
      state = state.copyWith(
        preferences: NotificationPreferences.fromJson(data),
        isLoading: false,
      );
    } catch (e) {
      // Falls back to defaults if the endpoint doesn't exist or errors.
      debugPrint('[Preferences] fetchPreferences failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // Returns false if the API call fails (caller should show error feedback).
  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    final previous = state.preferences;
    state = state.copyWith(preferences: prefs, isSaving: true);
    try {
      await _dioClient.dio.patch(
        '/notifications/preferences',
        data: prefs.toJson(),
      );
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      debugPrint('[Preferences] updatePreferences failed: $e');
      state = state.copyWith(preferences: previous, isSaving: false);
      return false;
    }
  }
}

final notificationPreferencesProvider =
    StateNotifierProvider<PreferencesNotifier, PreferencesState>(
  (ref) => PreferencesNotifier(ref.read(dioClientProvider)),
);
