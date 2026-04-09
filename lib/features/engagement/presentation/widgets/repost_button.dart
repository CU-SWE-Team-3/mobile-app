import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/engagement_provider.dart';

class RepostButton extends ConsumerWidget {
  final String trackId;
  final bool initialIsReposted;
  final int initialRepostCount;
  final bool showCount;
  final double iconSize;

  const RepostButton({
    super.key,
    required this.trackId,
    this.initialIsReposted = false,
    this.initialRepostCount = 0,
    this.showCount = false,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = EngagementParams(
      trackId: trackId,
      isReposted: initialIsReposted,
      repostCount: initialRepostCount,
    );
    final state = ref.watch(engagementProvider(params));

    return GestureDetector(
      onTap: state.isLoadingRepost
          ? null
          : () =>
              ref.read(engagementProvider(params).notifier).toggleRepost(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat,
              color: state.isReposted
                  ? const Color(0xFFFF5500)
                  : Colors.white54,
              size: iconSize,
            ),
            if (showCount && state.repostCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${state.repostCount}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
