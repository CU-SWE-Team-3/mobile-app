import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LikeButton extends ConsumerWidget {
  final bool isLiked;

  const LikeButton({super.key, this.isLiked = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () {},
      icon: Icon(
        isLiked ? Icons.favorite : Icons.favorite_border,
        color: isLiked ? const Color(0xFFFF5500) : Colors.white54,
      ),
    );
  }
}
