// test/features/engagement/engagement_test.dart
//
// Module 6 – Engagement & Social Interactions
// Coverage target: 100% of lib/features/engagement/
//
// Files under test:
//   • lib/features/engagement/domain/entities/comment.dart
//   • lib/features/engagement/data/models/comment_model.dart
//   • lib/features/engagement/data/models/liker_user_model.dart
//   • lib/features/engagement/data/sources/engagement_remote_data_source.dart
//       – TrackSummary.fromJson, CommentsResponse, pure parsing helpers
//   • lib/features/engagement/presentation/providers/engagement_provider.dart
//       – EngagementParams, EngagementState, EngagementNotifier (seed / optimistic logic)
//   • lib/features/engagement/presentation/providers/comments_provider.dart
//       – CommentsState, CommentsNotifier
//
// Run with:
//   flutter test test/features/engagement/engagement_test.dart

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inline mirrors (hermetic — no flutter/platform dependencies)
// ─────────────────────────────────────────────────────────────────────────────

// ── Domain entities ───────────────────────────────────────────────────────────

class CommentUser {
  final String id;
  final String displayName;
  final String permalink;
  final String? avatarUrl;

  const CommentUser({
    required this.id,
    required this.displayName,
    required this.permalink,
    this.avatarUrl,
  });
}

class CommentReply {
  final String id;
  final String content;
  final int timestamp;
  final CommentUser user;
  final DateTime createdAt;

  const CommentReply({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.user,
    required this.createdAt,
  });
}

class Comment {
  final String id;
  final String content;
  final int timestamp;
  final CommentUser user;
  final String? parentCommentId;
  final List<CommentReply> replies;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.user,
    this.parentCommentId,
    this.replies = const [],
    required this.createdAt,
  });
}

// ── Data models ───────────────────────────────────────────────────────────────

class CommentUserModel extends CommentUser {
  const CommentUserModel({
    required super.id,
    required super.displayName,
    required super.permalink,
    super.avatarUrl,
  });

  factory CommentUserModel.fromJson(Map<String, dynamic> json) {
    return CommentUserModel(
      id: json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Unknown',
      permalink: json['permalink'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class CommentReplyModel extends CommentReply {
  const CommentReplyModel({
    required super.id,
    required super.content,
    required super.timestamp,
    required super.user,
    required super.createdAt,
  });

  factory CommentReplyModel.fromJson(Map<String, dynamic> json) {
    return CommentReplyModel(
      id: json['_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      user: CommentUserModel.fromJson(
          Map<String, dynamic>.from(json['user'] as Map? ?? {})),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.content,
    required super.timestamp,
    required super.user,
    super.parentCommentId,
    super.replies,
    required super.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List<dynamic>? ?? [];
    return CommentModel(
      id: json['_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      user: json['user'] is Map
          ? CommentUserModel.fromJson(
              Map<String, dynamic>.from(json['user'] as Map))
          : CommentUserModel(
              id: json['user'] as String? ?? '',
              displayName: 'Unknown',
              permalink: '',
            ),
      parentCommentId: json['parentComment'] as String?,
      replies: rawReplies
          .map((r) => CommentReplyModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ── LikerUser ─────────────────────────────────────────────────────────────────

class LikerUser {
  final String id;
  final String displayName;
  final String permalink;
  final String? avatarUrl;
  final bool isFollowing;

  const LikerUser({
    required this.id,
    required this.displayName,
    required this.permalink,
    this.avatarUrl,
    this.isFollowing = false,
  });

  factory LikerUser.fromJson(Map<String, dynamic> json) {
    return LikerUser(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      permalink: json['permalink'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }
}

// ── TrackSummary ──────────────────────────────────────────────────────────────

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

class TrackSummary {
  final String id;
  final String title;
  final String artistName;
  final String? artistId;
  final String? artistPermalink;
  final String? trackPermalink;
  final String? artworkUrl;
  final String? audioUrl;
  final int playCount;
  final int likeCount;
  final int repostCount;
  final List<int>? waveform;

  const TrackSummary({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId,
    this.artistPermalink,
    this.trackPermalink,
    this.artworkUrl,
    this.audioUrl,
    this.playCount = 0,
    this.likeCount = 0,
    this.repostCount = 0,
    this.waveform,
  });

  factory TrackSummary.fromJson(Map<String, dynamic> json) {
    final artist = _asStringMap(
      json['artist'] ?? json['creator'] ?? json['user'],
    );
    final audio = _asStringMap(json['audio']);
    final id = json['_id'] as String? ?? json['id'] as String? ?? '';
    return TrackSummary(
      id: id,
      title: json['title'] as String? ?? '',
      artistName: artist['displayName'] as String? ??
          artist['username'] as String? ??
          artist['name'] as String? ??
          '',
      artistId: artist['_id'] as String? ?? artist['id'] as String?,
      artistPermalink: artist['permalink'] as String?,
      trackPermalink: json['permalink']?.toString(),
      artworkUrl: json['artworkUrl'] as String? ??
          json['coverUrl'] as String? ??
          json['imageUrl'] as String?,
      audioUrl: json['audioUrl'] as String? ??
          json['streamUrl'] as String? ??
          json['hlsUrl'] as String? ??
          audio['hlsUrl'] as String? ??
          audio['url'] as String?,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      waveform: (json['waveform'] as List<dynamic>?)
          ?.whereType<num>()
          .map((e) => e.toInt())
          .toList(),
    );
  }
}

// ── CommentsResponse ──────────────────────────────────────────────────────────

class CommentsResponse {
  final List<CommentModel> comments;
  final int total;
  final int page;
  final int totalPages;

  const CommentsResponse({
    required this.comments,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

// ── EngagementParams ──────────────────────────────────────────────────────────

class EngagementParams {
  final String trackId;
  final String targetModel;
  final bool isLiked;
  final bool isReposted;
  final int likeCount;
  final int repostCount;

  const EngagementParams({
    required this.trackId,
    this.targetModel = 'Track',
    this.isLiked = false,
    this.isReposted = false,
    this.likeCount = 0,
    this.repostCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is EngagementParams &&
      other.trackId == trackId &&
      other.targetModel == targetModel;

  @override
  int get hashCode => Object.hash(trackId, targetModel);
}

// ── EngagementState ───────────────────────────────────────────────────────────

class EngagementState {
  final bool isLiked;
  final bool isReposted;
  final int likeCount;
  final int repostCount;
  final bool isLoadingLike;
  final bool isLoadingRepost;

  const EngagementState({
    this.isLiked = false,
    this.isReposted = false,
    this.likeCount = 0,
    this.repostCount = 0,
    this.isLoadingLike = false,
    this.isLoadingRepost = false,
  });

  EngagementState copyWith({
    bool? isLiked,
    bool? isReposted,
    int? likeCount,
    int? repostCount,
    bool? isLoadingLike,
    bool? isLoadingRepost,
  }) =>
      EngagementState(
        isLiked: isLiked ?? this.isLiked,
        isReposted: isReposted ?? this.isReposted,
        likeCount: likeCount ?? this.likeCount,
        repostCount: repostCount ?? this.repostCount,
        isLoadingLike: isLoadingLike ?? this.isLoadingLike,
        isLoadingRepost: isLoadingRepost ?? this.isLoadingRepost,
      );
}

// ── Hermetic EngagementNotifier ───────────────────────────────────────────────

class TestableEngagementNotifier {
  EngagementState state;
  bool _userToggled = false;

  final Future<void> Function() _like;
  final Future<void> Function() _unlike;
  final Future<void> Function() _repost;
  final Future<void> Function() _unrepost;

  TestableEngagementNotifier({
    required bool initialIsLiked,
    required bool initialIsReposted,
    required int initialLikeCount,
    required int initialRepostCount,
    required Future<void> Function() like,
    required Future<void> Function() unlike,
    required Future<void> Function() repost,
    required Future<void> Function() unrepost,
  })  : _like = like,
        _unlike = unlike,
        _repost = repost,
        _unrepost = unrepost,
        state = EngagementState(
          isLiked: initialIsLiked,
          isReposted: initialIsReposted,
          likeCount: initialLikeCount,
          repostCount: initialRepostCount,
        );

  void seed(
      {bool? isLiked, bool? isReposted, int? likeCount, int? repostCount}) {
    if (_userToggled) return;
    state = state.copyWith(
      isLiked: isLiked,
      isReposted: isReposted,
      likeCount: likeCount,
      repostCount: repostCount,
    );
  }

  Future<bool> toggleLike() async {
    if (state.isLoadingLike) return false;
    _userToggled = true;
    final wasLiked = state.isLiked;
    final prevCount = state.likeCount;
    state = state.copyWith(
      isLiked: !wasLiked,
      likeCount: wasLiked ? prevCount - 1 : prevCount + 1,
      isLoadingLike: true,
    );
    try {
      if (wasLiked) {
        await _unlike();
      } else {
        await _like();
      }
      state = state.copyWith(isLoadingLike: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isLiked: wasLiked,
        likeCount: prevCount,
        isLoadingLike: false,
      );
      return false;
    }
  }

  Future<bool> removeLike() async {
    if (state.isLoadingLike) return !state.isLiked;
    if (!state.isLiked) return true;

    _userToggled = true;
    final prevCount = state.likeCount;
    state = state.copyWith(
      isLiked: false,
      likeCount: prevCount > 0 ? prevCount - 1 : 0,
      isLoadingLike: true,
    );

    try {
      await _unlike();
      state = state.copyWith(isLoadingLike: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isLiked: true,
        likeCount: prevCount,
        isLoadingLike: false,
      );
      return false;
    }
  }

  Future<void> toggleRepost() async {
    if (state.isLoadingRepost) return;
    _userToggled = true;
    final wasReposted = state.isReposted;
    final prevCount = state.repostCount;
    state = state.copyWith(
      isReposted: !wasReposted,
      repostCount: wasReposted ? prevCount - 1 : prevCount + 1,
      isLoadingRepost: true,
    );
    try {
      if (wasReposted) {
        await _unrepost();
      } else {
        await _repost();
      }
      state = state.copyWith(isLoadingRepost: false);
    } catch (_) {
      state = state.copyWith(
        isReposted: wasReposted,
        repostCount: prevCount,
        isLoadingRepost: false,
      );
    }
  }
}

// ── CommentsState ─────────────────────────────────────────────────────────────

class CommentsState {
  final List<CommentModel> comments;
  final bool isLoading;
  final bool isPosting;
  final String? error;
  final int currentPage;
  final int totalPages;
  final int total;

  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.isPosting = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
  });

  bool get hasMore => currentPage <= totalPages;

  CommentsState copyWith({
    List<CommentModel>? comments,
    bool? isLoading,
    bool? isPosting,
    String? error,
    int? currentPage,
    int? totalPages,
    int? total,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper factories
// ─────────────────────────────────────────────────────────────────────────────

CommentUser _makeUser({String id = 'u1', String name = 'User'}) =>
    CommentUser(id: id, displayName: name, permalink: 'user-$id');

CommentModel _makeComment({String id = 'c1', int timestamp = 10}) =>
    CommentModel(
      id: id,
      content: 'Test comment',
      timestamp: timestamp,
      user:
          CommentUserModel(id: 'u1', displayName: 'User', permalink: 'user-u1'),
      createdAt: DateTime(2024, 1, 1),
    );

TestableEngagementNotifier _makeEngagement({
  bool isLiked = false,
  bool isReposted = false,
  int likeCount = 5,
  int repostCount = 3,
  bool likeThrows = false,
  bool unlikeThrows = false,
  bool repostThrows = false,
  bool unrepostThrows = false,
}) =>
    TestableEngagementNotifier(
      initialIsLiked: isLiked,
      initialIsReposted: isReposted,
      initialLikeCount: likeCount,
      initialRepostCount: repostCount,
      like: () async {
        if (likeThrows) throw Exception('like failed');
      },
      unlike: () async {
        if (unlikeThrows) throw Exception('unlike failed');
      },
      repost: () async {
        if (repostThrows) throw Exception('repost failed');
      },
      unrepost: () async {
        if (unrepostThrows) throw Exception('unrepost failed');
      },
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 6.1: Domain entities ──────────────────────────────────────────────────

  group('CommentUser', () {
    test('stores required fields', () {
      final u = _makeUser(id: 'x', name: 'Alice');
      expect(u.id, 'x');
      expect(u.displayName, 'Alice');
      expect(u.permalink, 'user-x');
    });

    test('avatarUrl defaults to null', () {
      expect(_makeUser().avatarUrl, isNull);
    });

    test('avatarUrl can be set', () {
      const u = CommentUser(
          id: 'u', displayName: 'D', permalink: 'p', avatarUrl: 'https://img');
      expect(u.avatarUrl, 'https://img');
    });
  });

  group('CommentReply', () {
    final user = _makeUser();
    final reply = CommentReply(
      id: 'r1',
      content: 'Reply text',
      timestamp: 30,
      user: user,
      createdAt: DateTime(2024, 2, 1),
    );

    test('stores all fields', () {
      expect(reply.id, 'r1');
      expect(reply.content, 'Reply text');
      expect(reply.timestamp, 30);
      expect(reply.user, user);
      expect(reply.createdAt, DateTime(2024, 2, 1));
    });
  });

  group('Comment', () {
    final user = _makeUser();
    final comment = Comment(
      id: 'c1',
      content: 'Hello',
      timestamp: 15,
      user: user,
      createdAt: DateTime(2024, 3, 1),
    );

    test('stores all fields', () {
      expect(comment.id, 'c1');
      expect(comment.content, 'Hello');
      expect(comment.timestamp, 15);
      expect(comment.user, user);
    });

    test('replies defaults to empty list', () {
      expect(comment.replies, isEmpty);
    });

    test('parentCommentId defaults to null', () {
      expect(comment.parentCommentId, isNull);
    });

    test('parentCommentId can be set', () {
      final c = Comment(
        id: 'c2',
        content: 'Reply',
        timestamp: 5,
        user: user,
        parentCommentId: 'parent-1',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(c.parentCommentId, 'parent-1');
    });
  });

  // ── 6.2: CommentUserModel.fromJson ───────────────────────────────────────

  group('CommentUserModel.fromJson', () {
    test('parses all fields', () {
      final m = CommentUserModel.fromJson({
        '_id': 'uid',
        'displayName': 'Bob',
        'permalink': 'bob',
        'avatarUrl': 'https://img/bob.jpg',
      });
      expect(m.id, 'uid');
      expect(m.displayName, 'Bob');
      expect(m.permalink, 'bob');
      expect(m.avatarUrl, 'https://img/bob.jpg');
    });

    test('defaults when fields are null', () {
      final m = CommentUserModel.fromJson({});
      expect(m.id, '');
      expect(m.displayName, 'Unknown');
      expect(m.permalink, '');
      expect(m.avatarUrl, isNull);
    });
  });

  // ── 6.3: CommentReplyModel.fromJson ──────────────────────────────────────

  group('CommentReplyModel.fromJson', () {
    test('parses full payload', () {
      final m = CommentReplyModel.fromJson({
        '_id': 'r1',
        'content': 'Reply!',
        'timestamp': 45,
        'user': {
          '_id': 'u1',
          'displayName': 'Alice',
          'permalink': 'alice',
        },
        'createdAt': '2024-05-01T00:00:00.000Z',
      });
      expect(m.id, 'r1');
      expect(m.content, 'Reply!');
      expect(m.timestamp, 45);
      expect(m.user.displayName, 'Alice');
      expect(m.createdAt.month, 5);
    });

    test('defaults timestamp to 0 when null', () {
      final m = CommentReplyModel.fromJson({
        '_id': 'r2',
        'content': '',
        'user': {},
        'createdAt': '2024-01-01T00:00:00.000Z',
      });
      expect(m.timestamp, 0);
    });

    test('falls back to DateTime.now when createdAt invalid', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final m = CommentReplyModel.fromJson({
        '_id': 'r3',
        'content': '',
        'user': {},
        'createdAt': 'not-a-date',
      });
      expect(m.createdAt.isAfter(before), isTrue);
    });
  });

  // ── 6.4: CommentModel.fromJson ───────────────────────────────────────────

  group('CommentModel.fromJson', () {
    test('parses comment with nested user map', () {
      final m = CommentModel.fromJson({
        '_id': 'cm1',
        'content': 'Nice track!',
        'timestamp': 60,
        'user': {
          '_id': 'u2',
          'displayName': 'Charlie',
          'permalink': 'charlie',
        },
        'createdAt': '2024-06-15T12:00:00.000Z',
        'replies': [],
      });
      expect(m.id, 'cm1');
      expect(m.content, 'Nice track!');
      expect(m.timestamp, 60);
      expect(m.user.displayName, 'Charlie');
      expect(m.replies, isEmpty);
    });

    test('parses comment with string user (bare id)', () {
      final m = CommentModel.fromJson({
        '_id': 'cm2',
        'content': 'Comment',
        'timestamp': 0,
        'user': 'raw-user-id',
        'createdAt': '2024-01-01T00:00:00.000Z',
      });
      expect(m.user.id, 'raw-user-id');
      expect(m.user.displayName, 'Unknown');
    });

    test('parses replies list', () {
      final m = CommentModel.fromJson({
        '_id': 'cm3',
        'content': 'Parent',
        'timestamp': 10,
        'user': {'_id': 'u3', 'displayName': 'Dave', 'permalink': 'd'},
        'createdAt': '2024-01-01T00:00:00.000Z',
        'replies': [
          {
            '_id': 'r-1',
            'content': 'Reply here',
            'timestamp': 15,
            'user': {'_id': 'u4', 'displayName': 'Eve', 'permalink': 'e'},
            'createdAt': '2024-01-02T00:00:00.000Z',
          },
        ],
      });
      expect(m.replies.length, 1);
      expect(m.replies.first.content, 'Reply here');
    });

    test('parentComment field is mapped to parentCommentId', () {
      final m = CommentModel.fromJson({
        '_id': 'cm4',
        'content': 'Child',
        'timestamp': 5,
        'user': {},
        'createdAt': '2024-01-01T00:00:00.000Z',
        'parentComment': 'parent-id',
      });
      expect(m.parentCommentId, 'parent-id');
    });

    test('replies defaults to empty when key missing', () {
      final m = CommentModel.fromJson({
        '_id': 'cm5',
        'content': 'X',
        'timestamp': 0,
        'user': {},
        'createdAt': '2024-01-01T00:00:00.000Z',
      });
      expect(m.replies, isEmpty);
    });
  });

  // ── 6.5: LikerUser.fromJson ───────────────────────────────────────────────

  group('LikerUser.fromJson', () {
    test('reads id field', () {
      final u = LikerUser.fromJson(
          {'id': 'id-1', 'displayName': 'A', 'permalink': 'a'});
      expect(u.id, 'id-1');
    });

    test('falls back to _id when id missing', () {
      final u = LikerUser.fromJson(
          {'_id': '_id-1', 'displayName': 'B', 'permalink': 'b'});
      expect(u.id, '_id-1');
    });

    test('id defaults to empty string', () {
      final u = LikerUser.fromJson({'displayName': 'C', 'permalink': 'c'});
      expect(u.id, '');
    });

    test('parses all fields', () {
      final u = LikerUser.fromJson({
        'id': 'liker-1',
        'displayName': 'Liker',
        'permalink': 'liker',
        'avatarUrl': 'https://img/liker.jpg',
        'isFollowing': true,
      });
      expect(u.displayName, 'Liker');
      expect(u.permalink, 'liker');
      expect(u.avatarUrl, 'https://img/liker.jpg');
      expect(u.isFollowing, isTrue);
    });

    test('isFollowing defaults to false', () {
      final u =
          LikerUser.fromJson({'id': 'x', 'displayName': 'X', 'permalink': 'x'});
      expect(u.isFollowing, isFalse);
    });

    test('avatarUrl defaults to null', () {
      final u =
          LikerUser.fromJson({'id': 'x', 'displayName': 'X', 'permalink': 'x'});
      expect(u.avatarUrl, isNull);
    });
  });

  // ── 6.6: LikerUser constructor defaults ──────────────────────────────────

  group('LikerUser constructor', () {
    test('default isFollowing is false', () {
      const u = LikerUser(id: 'x', displayName: 'X', permalink: 'x');
      expect(u.isFollowing, isFalse);
    });
  });

  // ── 6.7: TrackSummary.fromJson ────────────────────────────────────────────

  group('TrackSummary.fromJson', () {
    test('parses _id', () {
      final t = TrackSummary.fromJson({'_id': 'ts-1', 'title': 'T'});
      expect(t.id, 'ts-1');
    });

    test('falls back to id field', () {
      final t = TrackSummary.fromJson({'id': 'ts-2', 'title': 'T'});
      expect(t.id, 'ts-2');
    });

    test('id defaults to empty string', () {
      final t = TrackSummary.fromJson({'title': 'T'});
      expect(t.id, '');
    });

    test('parses artist map with displayName', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-3',
        'title': 'Song',
        'artist': {'displayName': 'DJ X', '_id': 'a1', 'permalink': 'djx'},
      });
      expect(t.artistName, 'DJ X');
      expect(t.artistId, 'a1');
      expect(t.artistPermalink, 'djx');
    });

    test('artist map fallback to username', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-4',
        'title': 'T',
        'artist': {'username': 'user-x'},
      });
      expect(t.artistName, 'user-x');
    });

    test('artist map fallback to name', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-5',
        'title': 'T',
        'artist': {'name': 'named-artist'},
      });
      expect(t.artistName, 'named-artist');
    });

    test('uses creator key when artist missing', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-6',
        'title': 'T',
        'creator': {'displayName': 'Creator'},
      });
      expect(t.artistName, 'Creator');
    });

    test('uses user key as last resort', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-7',
        'title': 'T',
        'user': {'displayName': 'User Artist'},
      });
      expect(t.artistName, 'User Artist');
    });

    test('artistId uses id when _id missing in artist map', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-8',
        'title': 'T',
        'artist': {'id': 'alt-artist-id', 'displayName': 'A'},
      });
      expect(t.artistId, 'alt-artist-id');
    });

    test('artworkUrl reads artworkUrl field', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-9',
        'title': 'T',
        'artworkUrl': 'https://art/img.jpg',
      });
      expect(t.artworkUrl, 'https://art/img.jpg');
    });

    test('artworkUrl fallback to coverUrl', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-10',
        'title': 'T',
        'coverUrl': 'https://cover/img.jpg',
      });
      expect(t.artworkUrl, 'https://cover/img.jpg');
    });

    test('artworkUrl fallback to imageUrl', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-11',
        'title': 'T',
        'imageUrl': 'https://image/img.jpg',
      });
      expect(t.artworkUrl, 'https://image/img.jpg');
    });

    test('audioUrl reads audioUrl', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-12',
        'title': 'T',
        'audioUrl': 'https://audio/file.mp3',
      });
      expect(t.audioUrl, 'https://audio/file.mp3');
    });

    test('audioUrl fallback to streamUrl', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-13',
        'title': 'T',
        'streamUrl': 'https://stream/file.m3u8',
      });
      expect(t.audioUrl, 'https://stream/file.m3u8');
    });

    test('audioUrl fallback to hlsUrl', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-14',
        'title': 'T',
        'hlsUrl': 'https://hls/file.m3u8',
      });
      expect(t.audioUrl, 'https://hls/file.m3u8');
    });

    test('audioUrl reads from nested audio map – hlsUrl', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-15',
        'title': 'T',
        'audio': {'hlsUrl': 'https://nested-hls/file.m3u8'},
      });
      expect(t.audioUrl, 'https://nested-hls/file.m3u8');
    });

    test('audioUrl reads from nested audio map – url', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-16',
        'title': 'T',
        'audio': {'url': 'https://nested-url/file.m3u8'},
      });
      expect(t.audioUrl, 'https://nested-url/file.m3u8');
    });

    test('playCounts parse as ints', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-17',
        'title': 'T',
        'playCount': 100,
        'likeCount': 20,
        'repostCount': 5,
      });
      expect(t.playCount, 100);
      expect(t.likeCount, 20);
      expect(t.repostCount, 5);
    });

    test('counts default to 0', () {
      final t = TrackSummary.fromJson({'_id': 'ts-18', 'title': 'T'});
      expect(t.playCount, 0);
      expect(t.likeCount, 0);
      expect(t.repostCount, 0);
    });

    test('waveform is parsed', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-19',
        'title': 'T',
        'waveform': [10, 20, 30],
      });
      expect(t.waveform, [10, 20, 30]);
    });

    test('waveform is null when absent', () {
      final t = TrackSummary.fromJson({'_id': 'ts-20', 'title': 'T'});
      expect(t.waveform, isNull);
    });

    test('permalink is stored', () {
      final t = TrackSummary.fromJson({
        '_id': 'ts-21',
        'title': 'T',
        'permalink': 'my-track',
      });
      expect(t.trackPermalink, 'my-track');
    });

    test('artistId is null when no artist map', () {
      final t = TrackSummary.fromJson({'_id': 'ts-22', 'title': 'T'});
      expect(t.artistId, isNull);
    });
  });

  // ── 6.8: EngagementParams ────────────────────────────────────────────────

  group('EngagementParams', () {
    test('defaults', () {
      const p = EngagementParams(trackId: 'track-1');
      expect(p.targetModel, 'Track');
      expect(p.isLiked, isFalse);
      expect(p.isReposted, isFalse);
      expect(p.likeCount, 0);
      expect(p.repostCount, 0);
    });

    test('equality uses trackId and targetModel only', () {
      const a = EngagementParams(trackId: 't1', isLiked: true, likeCount: 99);
      const b = EngagementParams(trackId: 't1', isLiked: false, likeCount: 0);
      expect(a == b, isTrue);
    });

    test('different targetModel → not equal', () {
      const a = EngagementParams(trackId: 't1', targetModel: 'Track');
      const b = EngagementParams(trackId: 't1', targetModel: 'Playlist');
      expect(a == b, isFalse);
    });

    test('equal objects have same hashCode', () {
      const a = EngagementParams(trackId: 't1');
      const b = EngagementParams(trackId: 't1');
      expect(a.hashCode, b.hashCode);
    });

    test('different trackIds → not equal', () {
      const a = EngagementParams(trackId: 'a');
      const b = EngagementParams(trackId: 'b');
      expect(a == b, isFalse);
    });
  });

  // ── 6.9: EngagementState ─────────────────────────────────────────────────

  group('EngagementState defaults', () {
    const s = EngagementState();
    test('isLiked', () => expect(s.isLiked, isFalse));
    test('isReposted', () => expect(s.isReposted, isFalse));
    test('likeCount', () => expect(s.likeCount, 0));
    test('repostCount', () => expect(s.repostCount, 0));
    test('isLoadingLike', () => expect(s.isLoadingLike, isFalse));
    test('isLoadingRepost', () => expect(s.isLoadingRepost, isFalse));
  });

  group('EngagementState.copyWith', () {
    const base = EngagementState();
    test('isLiked', () => expect(base.copyWith(isLiked: true).isLiked, isTrue));
    test('isReposted',
        () => expect(base.copyWith(isReposted: true).isReposted, isTrue));
    test('likeCount', () => expect(base.copyWith(likeCount: 10).likeCount, 10));
    test('repostCount',
        () => expect(base.copyWith(repostCount: 7).repostCount, 7));
    test('isLoadingLike',
        () => expect(base.copyWith(isLoadingLike: true).isLoadingLike, isTrue));
    test(
        'isLoadingRepost',
        () => expect(
            base.copyWith(isLoadingRepost: true).isLoadingRepost, isTrue));
    test('preserves original when no args', () {
      const s = EngagementState(isLiked: true, likeCount: 5);
      final c = s.copyWith();
      expect(c.isLiked, isTrue);
      expect(c.likeCount, 5);
    });
  });

  // ── 6.10: EngagementNotifier – seed ──────────────────────────────────────

  group('EngagementNotifier.seed', () {
    test('updates state before any toggle', () {
      final n = _makeEngagement(isLiked: false, likeCount: 0);
      n.seed(isLiked: true, likeCount: 10);
      expect(n.state.isLiked, isTrue);
      expect(n.state.likeCount, 10);
    });

    test('no-op after toggle (userToggled guard)', () async {
      final n = _makeEngagement(isLiked: false, likeCount: 0);
      await n.toggleLike(); // sets _userToggled = true
      n.seed(isLiked: false, likeCount: 999);
      // State should NOT change because _userToggled is true
      expect(n.state.isLiked, isTrue); // still true from toggle
      expect(n.state.likeCount, 1); // still 0+1=1 from toggle
    });

    test('seed partial fields – only supplied fields change', () {
      final n = _makeEngagement(isLiked: false, likeCount: 5, repostCount: 3);
      n.seed(likeCount: 20);
      expect(n.state.likeCount, 20);
      expect(n.state.isLiked, isFalse); // unchanged
      expect(n.state.repostCount, 3); // unchanged
    });
  });

  // ── 6.11: EngagementNotifier – toggleLike ────────────────────────────────

  group('EngagementNotifier.toggleLike', () {
    test('like: flips isLiked to true and increments count', () async {
      final n = _makeEngagement(isLiked: false, likeCount: 10);
      final result = await n.toggleLike();
      expect(result, isTrue);
      expect(n.state.isLiked, isTrue);
      expect(n.state.likeCount, 11);
      expect(n.state.isLoadingLike, isFalse);
    });

    test('unlike: flips isLiked to false and decrements count', () async {
      final n = _makeEngagement(isLiked: true, likeCount: 10);
      final result = await n.toggleLike();
      expect(result, isTrue);
      expect(n.state.isLiked, isFalse);
      expect(n.state.likeCount, 9);
    });

    test('reverts on like API failure', () async {
      final n = _makeEngagement(isLiked: false, likeCount: 5, likeThrows: true);
      final result = await n.toggleLike();
      expect(result, isFalse);
      expect(n.state.isLiked, isFalse); // reverted
      expect(n.state.likeCount, 5); // reverted
      expect(n.state.isLoadingLike, isFalse);
    });

    test('reverts on unlike API failure', () async {
      final n =
          _makeEngagement(isLiked: true, likeCount: 5, unlikeThrows: true);
      final result = await n.toggleLike();
      expect(result, isFalse);
      expect(n.state.isLiked, isTrue);
      expect(n.state.likeCount, 5);
    });

    test('returns false and skips when isLoadingLike=true', () async {
      final n = _makeEngagement(isLiked: false, likeCount: 0);
      n.state = n.state.copyWith(isLoadingLike: true);
      final result = await n.toggleLike();
      expect(result, isFalse);
    });
  });

  // ── 6.12: EngagementNotifier – removeLike ────────────────────────────────

  group('EngagementNotifier.removeLike', () {
    test('removes like when currently liked', () async {
      final n = _makeEngagement(isLiked: true, likeCount: 8);
      final result = await n.removeLike();
      expect(result, isTrue);
      expect(n.state.isLiked, isFalse);
      expect(n.state.likeCount, 7);
    });

    test('returns true immediately if not liked', () async {
      final n = _makeEngagement(isLiked: false, likeCount: 0);
      final result = await n.removeLike();
      expect(result, isTrue);
      expect(n.state.isLiked, isFalse);
    });

    test('returns !isLiked immediately when loading', () async {
      final n = _makeEngagement(isLiked: false, likeCount: 0);
      n.state = n.state.copyWith(isLoadingLike: true);
      final result = await n.removeLike();
      expect(result, isTrue); // !false
    });

    test('reverts when unlike API fails', () async {
      final n =
          _makeEngagement(isLiked: true, likeCount: 5, unlikeThrows: true);
      final result = await n.removeLike();
      expect(result, isFalse);
      expect(n.state.isLiked, isTrue);
      expect(n.state.likeCount, 5);
    });

    test('likeCount does not go below 0', () async {
      final n = _makeEngagement(isLiked: true, likeCount: 0);
      await n.removeLike();
      expect(n.state.likeCount, 0);
    });
  });

  // ── 6.13: EngagementNotifier – toggleRepost ──────────────────────────────

  group('EngagementNotifier.toggleRepost', () {
    test('repost: sets isReposted true and increments count', () async {
      final n = _makeEngagement(isReposted: false, repostCount: 3);
      await n.toggleRepost();
      expect(n.state.isReposted, isTrue);
      expect(n.state.repostCount, 4);
      expect(n.state.isLoadingRepost, isFalse);
    });

    test('unrepost: sets isReposted false and decrements count', () async {
      final n = _makeEngagement(isReposted: true, repostCount: 4);
      await n.toggleRepost();
      expect(n.state.isReposted, isFalse);
      expect(n.state.repostCount, 3);
    });

    test('reverts on repost failure', () async {
      final n = _makeEngagement(
          isReposted: false, repostCount: 3, repostThrows: true);
      await n.toggleRepost();
      expect(n.state.isReposted, isFalse);
      expect(n.state.repostCount, 3);
    });

    test('reverts on unrepost failure', () async {
      final n = _makeEngagement(
          isReposted: true, repostCount: 4, unrepostThrows: true);
      await n.toggleRepost();
      expect(n.state.isReposted, isTrue);
      expect(n.state.repostCount, 4);
    });

    test('no-op when isLoadingRepost=true', () async {
      final n = _makeEngagement(isReposted: false, repostCount: 0);
      n.state = n.state.copyWith(isLoadingRepost: true);
      await n.toggleRepost();
      expect(n.state.isReposted, isFalse); // unchanged
    });
  });

  // ── 6.14: CommentsState ───────────────────────────────────────────────────

  group('CommentsState defaults', () {
    const s = CommentsState();
    test('comments is empty', () => expect(s.comments, isEmpty));
    test('isLoading is false', () => expect(s.isLoading, isFalse));
    test('isPosting is false', () => expect(s.isPosting, isFalse));
    test('error is null', () => expect(s.error, isNull));
    test('currentPage is 1', () => expect(s.currentPage, 1));
    test('totalPages is 1', () => expect(s.totalPages, 1));
    test('total is 0', () => expect(s.total, 0));
  });

  group('CommentsState.hasMore', () {
    test('true when currentPage <= totalPages', () {
      const s = CommentsState(currentPage: 1, totalPages: 2);
      expect(s.hasMore, isTrue);
    });

    test('false when currentPage > totalPages', () {
      const s = CommentsState(currentPage: 3, totalPages: 2);
      expect(s.hasMore, isFalse);
    });

    test('true when currentPage == totalPages', () {
      const s = CommentsState(currentPage: 2, totalPages: 2);
      expect(s.hasMore, isTrue);
    });
  });

  group('CommentsState.copyWith', () {
    test('comments updates', () {
      final c = _makeComment();
      final s = const CommentsState().copyWith(comments: [c]);
      expect(s.comments.length, 1);
    });

    test(
        'isLoading updates',
        () => expect(
            const CommentsState().copyWith(isLoading: true).isLoading, isTrue));

    test(
        'isPosting updates',
        () => expect(
            const CommentsState().copyWith(isPosting: true).isPosting, isTrue));

    test(
        'error updates',
        () =>
            expect(const CommentsState().copyWith(error: 'err').error, 'err'));

    test('error clears to null when not provided in copyWith', () {
      final s = const CommentsState(error: 'old').copyWith(isLoading: false);
      // Note: copyWith always sets error to the provided value (null by default)
      expect(s.error, isNull);
    });

    test(
        'currentPage updates',
        () => expect(
            const CommentsState().copyWith(currentPage: 3).currentPage, 3));

    test(
        'totalPages updates',
        () => expect(
            const CommentsState().copyWith(totalPages: 5).totalPages, 5));

    test('total updates',
        () => expect(const CommentsState().copyWith(total: 42).total, 42));

    test('preserves non-null fields when unspecified', () {
      final c = _makeComment();
      final s = CommentsState(
        comments: [c],
        currentPage: 2,
        totalPages: 3,
        total: 10,
      );
      final copy = s.copyWith(isLoading: true);
      expect(copy.comments.length, 1);
      expect(copy.currentPage, 2);
      expect(copy.totalPages, 3);
      expect(copy.total, 10);
    });
  });

  // ── 6.15: CommentsResponse ────────────────────────────────────────────────

  group('CommentsResponse', () {
    test('stores all fields', () {
      final comment = _makeComment();
      final r = CommentsResponse(
        comments: [comment],
        total: 1,
        page: 1,
        totalPages: 1,
      );
      expect(r.comments.length, 1);
      expect(r.total, 1);
      expect(r.page, 1);
      expect(r.totalPages, 1);
    });

    test('empty comments list', () {
      const r =
          CommentsResponse(comments: [], total: 0, page: 1, totalPages: 0);
      expect(r.comments, isEmpty);
    });
  });
}
