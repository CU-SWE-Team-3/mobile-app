import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../player/presentation/providers/follow_provider.dart';

class FollowUnfollowButton extends ConsumerWidget {
  final String userId;
  final bool isFollowing;

  const FollowUnfollowButton({
    super.key,
    required this.userId,
    this.isFollowing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followProvider(userId));
    // While checking, fall back to the initial hint passed by the caller.
    final showing = state.isChecking ? isFollowing : state.isFollowing;
    final busy = state.isLoading || state.isChecking;

    return ElevatedButton(
      onPressed: busy
          ? null
          : () => ref.read(followProvider(userId).notifier).toggle(userId),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            showing ? const Color(0xFF1F1F1F) : const Color(0xFFFF5500),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(showing ? 'Following' : 'Follow'),
    );
  }
}
