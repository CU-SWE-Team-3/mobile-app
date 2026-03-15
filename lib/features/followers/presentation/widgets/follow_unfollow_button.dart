import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FollowUnfollowButton extends ConsumerWidget {
  final bool isFollowing;

  const FollowUnfollowButton({super.key, this.isFollowing = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isFollowing ? const Color(0xFF1F1F1F) : const Color(0xFFFF5500),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(isFollowing ? 'Following' : 'Follow'),
    );
  }
}
