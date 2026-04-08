import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/engagement_provider.dart';

class LikeButton extends ConsumerWidget {
  final String trackId;
  final bool initialIsLiked;
  final int initialLikeCount;
  final bool showCount;
  final double iconSize;

  const LikeButton({
    super.key,
    required this.trackId,
    this.initialIsLiked = false,
    this.initialLikeCount = 0,
    this.showCount = false,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = EngagementParams(
      trackId: trackId,
      isLiked: initialIsLiked,
      likeCount: initialLikeCount,
    );
    final state = ref.watch(engagementProvider(params));

    return GestureDetector(
      onTap: state.isLoadingLike
          ? null
          : () => ref.read(engagementProvider(params).notifier).toggleLike(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.isLiked ? Icons.favorite : Icons.favorite_border,
              color:
                  state.isLiked ? const Color(0xFFFF5500) : Colors.white54,
              size: iconSize,
            ),
            if (showCount && state.likeCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${state.likeCount}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
