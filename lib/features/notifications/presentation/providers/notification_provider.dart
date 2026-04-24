import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notification.dart';

export '../../domain/entities/notification.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final NotificationType? activeFilter;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.activeFilter,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

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
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Swap this block for: final res = await dio.get('/notifications');
      // and map res.data to AppNotification list.
      await Future.delayed(const Duration(milliseconds: 300));
      final now = DateTime.now();
      final items = _buildMockNotifications(now);
      state = state.copyWith(notifications: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void markAsRead(String id) {
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList(),
    );
  }

  void markAllAsRead() {
    state = state.copyWith(
      notifications:
          state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
  }

  void setFilter(NotificationType? filter) {
    if (filter == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(activeFilter: filter);
    }
  }
}

// ── Mock data ─────────────────────────────────────────────────────────────────

List<AppNotification> _buildMockNotifications(DateTime now) {
  return [
    AppNotification(
      id: 'n1',
      type: NotificationType.follow,
      actorName: 'محمد العمري',
      actorAvatarUrl: null,
      actorPermalink: '@mohamad_alomari',
      isRead: false,
      createdAt: now.subtract(const Duration(minutes: 5)),
    ),
    AppNotification(
      id: 'n2',
      type: NotificationType.like,
      actorName: 'سارة خليل',
      actorAvatarUrl: null,
      actorPermalink: '@sara_khalil',
      trackTitle: 'ليالي القاهرة',
      isRead: false,
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
    AppNotification(
      id: 'n3',
      type: NotificationType.comment,
      actorName: 'كريم عوض',
      actorAvatarUrl: null,
      actorPermalink: '@kareem_awad',
      trackTitle: 'ليالي القاهرة',
      commentText: 'Amazing track!',
      isRead: false,
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 'n4',
      type: NotificationType.repost,
      actorName: 'لمى الشريف',
      actorAvatarUrl: null,
      actorPermalink: '@lama_sharif',
      trackTitle: 'روح الشرق',
      isRead: true,
      createdAt: now.subtract(const Duration(hours: 6)),
    ),
    AppNotification(
      id: 'n5',
      type: NotificationType.follow,
      actorName: 'أحمد رضا',
      actorAvatarUrl: null,
      actorPermalink: '@ahmed_reda',
      isRead: true,
      createdAt: now.subtract(const Duration(hours: 10)),
    ),
    AppNotification(
      id: 'n6',
      type: NotificationType.comment,
      actorName: 'نور حسن',
      actorAvatarUrl: null,
      actorPermalink: '@nour_hassan',
      trackTitle: 'نبض المدينة',
      commentText: 'بتجنن والله!',
      isRead: false,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'n7',
      type: NotificationType.like,
      actorName: 'ياسمين فاروق',
      actorAvatarUrl: null,
      actorPermalink: '@yasmin_farouk',
      trackTitle: 'روح الشرق',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    AppNotification(
      id: 'n8',
      type: NotificationType.repost,
      actorName: 'عمر الجمال',
      actorAvatarUrl: null,
      actorPermalink: '@omar_gamal',
      trackTitle: 'نبض المدينة',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 3)),
    ),
    AppNotification(
      id: 'n9',
      type: NotificationType.follow,
      actorName: 'دينا مصطفى',
      actorAvatarUrl: null,
      actorPermalink: '@dina_mostafa',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 5)),
    ),
    AppNotification(
      id: 'n10',
      type: NotificationType.comment,
      actorName: 'خالد سعيد',
      actorAvatarUrl: null,
      actorPermalink: '@khaled_saeed',
      trackTitle: 'ليالي القاهرة',
      commentText: 'ده فن حقيقي',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 6)),
    ),
  ];
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(),
);
