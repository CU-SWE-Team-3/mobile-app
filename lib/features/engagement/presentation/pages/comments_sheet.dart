import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/comment_model.dart';
import '../providers/comments_provider.dart';

// ── Route page (used by go_router /comments) ─────────────────────────────────

class CommentsSheet extends ConsumerWidget {
  final String? trackId;
  final String? trackTitle;
  final String? trackArtist;
  final String? trackArtworkUrl;
  final int currentPositionSeconds;

  const CommentsSheet({
    super.key,
    this.trackId,
    this.trackTitle,
    this.trackArtist,
    this.trackArtworkUrl,
    this.currentPositionSeconds = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: _CommentsBody(
        trackId: trackId ?? '',
        trackTitle: trackTitle,
        trackArtist: trackArtist,
        trackArtworkUrl: trackArtworkUrl,
        currentPositionSeconds: currentPositionSeconds,
      ),
    );
  }
}

// ── Main body ────────────────────────────────────────────────────────────────

class _CommentsBody extends ConsumerStatefulWidget {
  final String trackId;
  final String? trackTitle;
  final String? trackArtist;
  final String? trackArtworkUrl;
  final int currentPositionSeconds;

  const _CommentsBody({
    required this.trackId,
    this.trackTitle,
    this.trackArtist,
    this.trackArtworkUrl,
    required this.currentPositionSeconds,
  });

  @override
  ConsumerState<_CommentsBody> createState() => _CommentsBodyState();
}

class _CommentsBodyState extends ConsumerState<_CommentsBody> {
  late final TextEditingController _inputController;
  late final FocusNode _inputFocus;
  final ScrollController _scrollController = ScrollController();

  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _inputFocus = FocusNode();

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final s = ref.read(commentsProvider(widget.trackId));
      if (s.hasMore && !s.isLoading) {
        ref.read(commentsProvider(widget.trackId).notifier).loadComments();
      }
    }
  }

  Future<void> _submit() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final ok = await ref.read(commentsProvider(widget.trackId).notifier).postComment(
          content: text,
          timestamp: widget.currentPositionSeconds,
          parentCommentId: _replyingToId,
        );

    if (ok) {
      _inputController.clear();
      _inputFocus.unfocus();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });
    }
  }

  void _startReply(String commentId, String name) {
    setState(() {
      _replyingToId = commentId;
      _replyingToName = name;
    });
    _inputFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
    _inputFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentsProvider(widget.trackId));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      children: [
        // ── Status bar spacer ─────────────────────────────────────────
        SizedBox(height: MediaQuery.of(context).padding.top),

        // ── Header: X  •  N comments  •  filter icon ─────────────────
        _Header(commentCount: state.comments.length),

        // ── Track info row ────────────────────────────────────────────
        if (widget.trackTitle != null || widget.trackArtworkUrl != null)
          _TrackInfoRow(
            artworkUrl: widget.trackArtworkUrl,
            title: widget.trackTitle ?? '',
            subtitle: widget.trackArtist ?? '',
          ),

        const Divider(color: Color(0xFF2A2A2A), height: 1),

        // ── Emoji reaction row ────────────────────────────────────────
        _EmojiReactionRow(totalCount: state.comments.length),

        const Divider(color: Color(0xFF2A2A2A), height: 1),

        // ── Comment list ──────────────────────────────────────────────
        Expanded(
          child: state.isLoading && state.comments.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Colors.orange, strokeWidth: 2),
                )
              : state.comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet.\nBe the first!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount:
                          state.comments.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == state.comments.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.orange, strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final c = state.comments[i];
                        return _CommentTile(
                          comment: c,
                          onReply: () =>
                              _startReply(c.id, c.user.displayName),
                          onDelete: () => ref
                              .read(commentsProvider(widget.trackId).notifier)
                              .deleteComment(c.id),
                        );
                      },
                    ),
        ),

        // ── Reply banner ──────────────────────────────────────────────
        if (_replyingToId != null)
          Container(
            color: const Color(0xFF1E1E1E),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.reply, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Replying to $_replyingToName',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  key: const ValueKey('comments_cancel_reply_button'),
                  onTap: _cancelReply,
                  child: const Icon(Icons.close,
                      color: Colors.white38, size: 16),
                ),
              ],
            ),
          ),

        // ── Input bar ─────────────────────────────────────────────────
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _InputBar(
            controller: _inputController,
            focusNode: _inputFocus,
            currentSec: widget.currentPositionSeconds,
            isPosting: state.isPosting,
            onSubmit: _submit,
          ),
        ),
      ],
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int commentCount;

  const _Header({required this.commentCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // X button
          GestureDetector(
            key: const ValueKey('comments_close_button'),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '$commentCount comments',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Filter / sort icon
          const Icon(Icons.tune, color: Colors.white, size: 22),
        ],
      ),
    );
  }
}

// ── Track info row ────────────────────────────────────────────────────────────

class _TrackInfoRow extends StatelessWidget {
  final String? artworkUrl;
  final String title;
  final String subtitle;

  const _TrackInfoRow({
    required this.artworkUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // Artwork thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: artworkUrl != null && artworkUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: artworkUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _artPlaceholder(),
                    errorWidget: (_, __, ___) => _artPlaceholder(),
                  )
                : _artPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.music_note,
          color: Colors.white24, size: 24),
    );
  }
}

// ── Emoji reaction row ────────────────────────────────────────────────────────

class _EmojiReactionRow extends StatelessWidget {
  final int totalCount;

  const _EmojiReactionRow({required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Emoji stacked chips
          const _EmojiChip(emoji: '🔥'),
          const SizedBox(width: 6),
          const _EmojiChip(emoji: '👏'),
          const SizedBox(width: 6),
          const _EmojiChip(emoji: '🤩'),
          const SizedBox(width: 10),
          Text(
            '$totalCount',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$totalCount comments',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  final String emoji;

  const _EmojiChip({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}

// ── Comment tile ──────────────────────────────────────────────────────────────

class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onDelete,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _liked = false;
  int _likeCount = 0;
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;

    return Column(
      children: [
        // ── Main comment row ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar — tap to go to profile
              GestureDetector(
                key: const ValueKey('comments_avatar_button'),
                onTap: () => _navigateToProfile(
                  context,
                  userId: c.user.id,
                  permalink: c.user.permalink,
                  displayName: c.user.displayName,
                ),
                child: _Avatar(url: c.user.avatarUrl, size: 46),
              ),
              const SizedBox(width: 12),

              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name  •  timestamp pill  •  time ago
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            key: const ValueKey('comments_username_button'),
                            onTap: () => _navigateToProfile(
                              context,
                              userId: c.user.id,
                              permalink: c.user.permalink,
                              displayName: c.user.displayName,
                            ),
                            child: Text(
                              c.user.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'at',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        _TimestampPill(key: const ValueKey('comments_timestamp_pill'), seconds: c.timestamp),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(c.createdAt),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Comment text
                    Text(
                      c.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Reply  •  ⋮
                    Row(
                      children: [
                        GestureDetector(
                          key: const ValueKey('comments_reply_button'),
                          onTap: widget.onReply,
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          key: const ValueKey('comments_more_button'),
                          onTap: () => _showOptions(context),
                          child: const Icon(Icons.more_vert,
                              color: Colors.white54, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Heart + count (right side)
              Column(
                children: [
                  GestureDetector(
                    key: const ValueKey('comments_like_button'),
                    onTap: () => setState(() {
                      _liked = !_liked;
                      _likeCount += _liked ? 1 : -1;
                    }),
                    child: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? Colors.orange : Colors.white54,
                      size: 22,
                    ),
                  ),
                  if (_likeCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$_likeCount',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Replies toggle ─────────────────────────────────────────────
        if (c.replies.isNotEmpty)
          GestureDetector(
            key: const ValueKey('comments_replies_toggle_button'),
            onTap: () => setState(() => _showReplies = !_showReplies),
            child: Padding(
              padding: const EdgeInsets.only(left: 74, top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _showReplies
                      ? 'Hide replies'
                      : 'View ${c.replies.length} '
                          '${c.replies.length == 1 ? 'reply' : 'replies'}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

        // ── Replies ────────────────────────────────────────────────────
        if (_showReplies)
          ...c.replies.map((r) => Padding(
                padding: const EdgeInsets.only(left: 58, top: 10),
                child: _ReplyRow(
                  avatarUrl: r.user.avatarUrl,
                  displayName: r.user.displayName,
                  content: r.content,
                  timestamp: r.timestamp,
                  createdAt: r.createdAt,
                ),
              )),

        const SizedBox(height: 4),
        const Divider(color: Color(0xFF1E1E1E), height: 1),
      ],
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('comments_delete_tile'),
              leading: const Icon(Icons.delete_outline,
                  color: Colors.red),
              title: const Text('Delete comment',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),
            ListTile(
              key: const ValueKey('comments_report_tile'),
              leading:
                  const Icon(Icons.flag_outlined, color: Colors.white54),
              title: const Text('Report',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reply row (indented, same structure, smaller avatar) ─────────────────────

class _ReplyRow extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final String content;
  final int timestamp;
  final DateTime createdAt;

  const _ReplyRow({
    required this.avatarUrl,
    required this.displayName,
    required this.content,
    required this.timestamp,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: avatarUrl, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('at',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 6),
                    _TimestampPill(key: const ValueKey('comments_timestamp_pill'), seconds: timestamp),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(createdAt),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timestamp pill ────────────────────────────────────────────────────────────

class _TimestampPill extends StatelessWidget {
  final int seconds;

  const _TimestampPill({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // SoundCloud uses a blue pill for the timestamp
        color: const Color(0xFF1A4A8A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$m:$s',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int currentSec;
  final bool isPosting;
  final VoidCallback onSubmit;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.currentSec,
    required this.isPosting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final m = currentSec ~/ 60;
    final s = (currentSec % 60).toString().padLeft(2, '0');

    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Row(
        children: [
          // My avatar placeholder
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person,
                color: Colors.white38, size: 20),
          ),
          const SizedBox(width: 10),

          // Input field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('comments_input_field'),
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Comment at',
                        hintStyle: TextStyle(
                            color: Colors.white38, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.send,
                      keyboardAppearance: Brightness.dark,
                      maxLines: 1,
                      onSubmitted: (_) => onSubmit(),
                    ),
                  ),
                  // Timestamp at end of input — matches screenshot
                  Text(
                    '$m:$s',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Send button (only visible when typing)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isPosting ? 40 : 0,
            child: isPosting
                ? const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          color: Colors.orange, strokeWidth: 2),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const _Avatar({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF3A3A3A),
      child: Icon(Icons.person, color: Colors.white38, size: size * 0.5),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Navigate to profile — own profile if it's the logged-in user, else other user
Future<void> _navigateToProfile(
  BuildContext context, {
  required String userId,
  required String permalink,
  required String displayName,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final myId = prefs.getString('userId') ?? '';

  if (!context.mounted) return;

  if (myId.isNotEmpty && myId == userId) {
    context.push('/profile');
  } else {
    context.push(
      '/user/$permalink',
      extra: {'displayName': displayName, 'userId': userId},
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
  return '${(diff.inDays / 365).floor()}y';
}