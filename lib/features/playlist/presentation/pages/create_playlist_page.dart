import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../premium/presentation/providers/subscription_provider.dart';

class CreatePlaylistPage extends ConsumerStatefulWidget {
  const CreatePlaylistPage({super.key});

  @override
  ConsumerState<CreatePlaylistPage> createState() => _CreatePlaylistPageState();
}

class _CreatePlaylistPageState extends ConsumerState<CreatePlaylistPage> {
  @override
  void initState() {
    super.initState();
    // Run paywall check after first frame so context + ref are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPaywall());
  }

  Future<void> _checkPaywall() async {
    final isPremium = ref.read(subscriptionProvider).isPremium;
    if (isPremium) return;

    // Fetch playlist count to decide whether to block.
    int count = 0;
    try {
      count = await ref.read(myPlaylistCountProvider.future);
    } catch (_) {
      return; // On error, allow creation rather than false-blocking.
    }

    if (count >= 2 && mounted) {
      _showPlaylistLimitDialog();
    }
  }

  void _showPlaylistLimitDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Playlist limit reached',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Free accounts can create up to 2 playlists. Upgrade to Artist Pro for unlimited playlists.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) context.pop();
            },
            child: const Text('Not now',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) context.go('/upgrade');
            },
            child: const Text('Upgrade',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text(
          'Create Playlist',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text(
          'Create Playlist',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      ),
    );
  }
}
