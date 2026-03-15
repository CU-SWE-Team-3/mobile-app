import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RepostButton extends ConsumerWidget {
  final bool isReposted;

  const RepostButton({super.key, this.isReposted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () {},
      icon: Icon(
        Icons.repeat,
        color: isReposted ? const Color(0xFFFF5500) : Colors.white54,
      ),
    );
  }
}
