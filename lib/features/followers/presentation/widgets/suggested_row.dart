import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/profile_navigation.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _SuggestedUser {
  final String id;
  final String displayName;
  final String permalink;
  final String? avatarUrl;
  final int followerCount;
  final bool? isBlocked;

  _SuggestedUser({
    required this.id,
    required this.displayName,
    required this.permalink,
    required this.avatarUrl,
    required this.followerCount,
    this.isBlocked,
  });

  factory _SuggestedUser.fromJson(Map<String, dynamic> json) {
    final fc = json['followerCount'];
    final blockedRaw = json['isBlocked'] ??
        json['blocked'] ??
        json['isBlockedByMe'] ??
        json['blockedByMe'];
    return _SuggestedUser(
      id: _readString(json['_id']).isNotEmpty
          ? _readString(json['_id'])
          : _readString(json['id']),
      displayName: _firstString([
        json['displayName'],
        json['username'],
        json['name'],
      ]),
      permalink: _firstString([
        json['permalink'],
        json['username'],
        json['_id'],
        json['id'],
      ]),
      avatarUrl: _nullableString([
        json['avatarUrl'],
        json['profileImageUrl'],
        json['photoUrl'],
      ]),
      followerCount: fc is int ? fc : int.tryParse(fc?.toString() ?? '') ?? 0,
      isBlocked: blockedRaw == true || blockedRaw?.toString() == 'true',
    );
  }

  _SuggestedUser copyWith({bool? isBlocked}) {
    return _SuggestedUser(
      id: id,
      displayName: displayName,
      permalink: permalink,
      avatarUrl: avatarUrl,
      followerCount: followerCount,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _readString(dynamic value) => value?.toString().trim() ?? '';

String _firstString(List<dynamic> values) {
  for (final value in values) {
    final text = _readString(value);
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

String? _nullableString(List<dynamic> values) {
  final text = _firstString(values);
  return text.isEmpty ? null : text;
}

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M followers';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K followers';
  return '$count followers';
}

List<dynamic> _extractBlockedList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is! Map) return const [];
  final data = raw['data'];
  if (data is List) return data;
  if (data is Map) {
    for (final key in const ['blockedUsers', 'users', 'blocked']) {
      final value = data[key];
      if (value is List) return value;
    }
  }
  for (final key in const ['blockedUsers', 'users', 'blocked']) {
    final value = raw[key];
    if (value is List) return value;
  }
  return const [];
}

String _blockedUserId(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return raw;
  if (raw is! Map) return raw.toString();
  final map = Map<String, dynamic>.from(raw);
  for (final key in const ['_id', 'id', 'userId', 'blockedUserId']) {
    final value = map[key]?.toString() ?? '';
    if (value.isNotEmpty) return value;
  }
  for (final key in const ['blockedUser', 'user', 'target']) {
    final value = map[key];
    if (value is Map) {
      final id = _blockedUserId(value);
      if (id.isNotEmpty) return id;
    } else {
      final id = value?.toString() ?? '';
      if (id.isNotEmpty) return id;
    }
  }
  return '';
}

// ── Widget ────────────────────────────────────────────────────────────────────

class SuggestedRow extends ConsumerStatefulWidget {
  final String? title;
  final bool compact;

  const SuggestedRow({super.key, this.title, this.compact = false});

  @override
  ConsumerState<SuggestedRow> createState() => _SuggestedRowState();
}

class _SuggestedRowState extends ConsumerState<SuggestedRow> {
  List<_SuggestedUser> _users = [];
  final Map<String, bool> _followingMap = {};
  final Map<String, bool> _loadingMap = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggested();
  }

  Future<void> _fetchSuggested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getString('userId') ?? '';
      final blockedIds = await _fetchBlockedIds();
      final response = await dioClient.dio
          .get('/network/suggested', queryParameters: {'page': 1, 'limit': 20});
      final raw = response.data['data'];
      final List<dynamic> data = (raw is List) ? raw : [];
      if (mounted) {
        setState(() {
          _users = data
              .map(_asStringMap)
              .where((e) => e.isNotEmpty)
              .map(_SuggestedUser.fromJson)
              .map((u) => blockedIds.contains(u.id)
                  ? u.copyWith(isBlocked: true)
                  : u)
              .where((u) => u.id.isNotEmpty && u.id != myId)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('=== SUGGESTED FETCH ERROR: $e\n$st');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<Set<String>> _fetchBlockedIds() async {
    try {
      final response = await dioClient.dio.get('/network/blocked-users');
      return _extractBlockedList(response.data)
          .map(_blockedUserId)
          .where((id) => id.isNotEmpty)
          .toSet();
    } on DioException {
      return {};
    }
  }

  Future<void> _toggleFollow(String userId) async {
    if (_loadingMap[userId] == true) return;
    final isFollowing = _followingMap[userId] ?? false;

    setState(() => _loadingMap[userId] = true);
    try {
      if (isFollowing) {
        await dioClient.dio.delete('/network/$userId/follow');
      } else {
        await dioClient.dio.post('/network/$userId/follow');
      }
      if (mounted) {
        setState(() => _followingMap[userId] = !isFollowing);
      }
    } on DioException {
      // silently ignore — button reverts to previous state
    } finally {
      if (mounted) setState(() => _loadingMap[userId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: widget.compact ? 206 : 210,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                )
              : _hasError
                  ? const Center(
                      child: Text(
                        "Couldn't load suggestions",
                        style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _users.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(width: widget.compact ? 28 : 10),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final isFollowing = _followingMap[user.id] ?? false;
                        final isButtonLoading = _loadingMap[user.id] ?? false;
                        return _UserCard(
                          user: user,
                          isFollowing: isFollowing,
                          isButtonLoading: isButtonLoading,
                          onToggle: () => _toggleFollow(user.id),
                          compact: widget.compact,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final _SuggestedUser user;
  final bool isFollowing;
  final bool isButtonLoading;
  final VoidCallback onToggle;
  final bool compact;

  const _UserCard({
    required this.user,
    required this.isFollowing,
    required this.isButtonLoading,
    required this.onToggle,
    required this.compact,
  });

  // Deterministic color from the user's display name initial
  Color get _fallbackColor {
    const colors = [
      Color(0xFF6C63FF), Color(0xFFE53935), Color(0xFF37474F),
      Color(0xFF00897B), Color(0xFF1E88E5), Color(0xFF8E24AA),
      Color(0xFF43A047), Color(0xFFFF5500),
    ];
    final seed = user.displayName.isNotEmpty ? user.displayName : user.id;
    return colors[seed.codeUnitAt(0) % colors.length];
  }

  bool _isDefaultAvatar(String? url) =>
      url == null || url.isEmpty || url.contains('default-avatar');

  @override
  Widget build(BuildContext context) {
    final showImage = !_isDefaultAvatar(user.avatarUrl);
    final avatarSize = compact ? 118.0 : 50.0;

    return GestureDetector(
      onTap: () => navigateToUserProfile(
        context,
        userId: user.id,
        permalink: user.permalink,
        displayName: user.displayName,
      ),
      child: Container(
      width: compact ? 132 : 130,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 12,
        vertical: compact ? 0 : 12,
      ),
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment:
            compact ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor:
                showImage ? Colors.transparent : (compact ? const Color(0xFF303030) : _fallbackColor),
            foregroundColor: const Color(0xFFCFCFCF),
            child: showImage
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.avatarUrl!,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : compact
                    ? const Icon(Icons.person, size: 96)
                    : Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
          SizedBox(height: compact ? 14 : 10),

          // Display name
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 15 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (compact) const SizedBox(height: 14),
          if (compact)
            user.isBlocked == true
                ? const Icon(
                    Icons.block,
                    color: Color(0xFFD6D6D6),
                    size: 30,
                  )
                : SizedBox(
                    width: 94,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: isButtonLoading ? null : onToggle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing
                            ? const Color(0xFFFF5500)
                            : Colors.white,
                        disabledBackgroundColor: isFollowing
                            ? const Color(0xFFFF5500)
                            : Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: isButtonLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    isFollowing ? Colors.white : Colors.black,
                              ),
                            )
                          : Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: TextStyle(
                                color:
                                    isFollowing ? Colors.white : Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
          if (!compact) const SizedBox(height: 2),

          if (!compact)
            Text(
              '@${user.permalink}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
            ),
          if (!compact) const SizedBox(height: 2),

          if (!compact)
            Text(
              _formatCount(user.followerCount),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
            ),
          if (!compact) const SizedBox(height: 10),

          if (!compact)
            SizedBox(
              width: double.infinity,
              height: 30,
              child: ElevatedButton(
                onPressed: isButtonLoading ? null : onToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFollowing ? const Color(0xFFFF5500) : Colors.white,
                  disabledBackgroundColor:
                      isFollowing ? const Color(0xFFFF5500) : Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: isButtonLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing ? Colors.white : Colors.black,
                        ),
                      )
                    : Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: isFollowing ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}
