import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../injection_container.dart';
import '../../data/models/liker_user_model.dart';
import '../../data/sources/engagement_remote_data_source.dart';

final _repostersProvider = FutureProvider.autoDispose
    .family<List<LikerUser>, String>((ref, trackId) async {
  return sl<EngagementRemoteDataSource>().getReposters(trackId);
});

class RepostersListPage extends ConsumerWidget {
  final String trackId;

  const RepostersListPage({super.key, required this.trackId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_repostersProvider(trackId));

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title:
            const Text('Reposted By', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5500)),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load reposters',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.invalidate(_repostersProvider(trackId)),
                child: const Text('Retry',
                    style: TextStyle(color: Color(0xFFFF5500))),
              ),
            ],
          ),
        ),
        data: (users) => users.isEmpty
            ? const Center(
                child: Text('No reposts yet',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
              )
            : ListView.builder(
                itemCount: users.length,
                itemBuilder: (_, i) => _UserTile(user: users[i]),
              ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final LikerUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user.avatarUrl != null &&
        user.avatarUrl!.isNotEmpty &&
        user.avatarUrl!.startsWith('http');
    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF2A2A2A),
        backgroundImage:
            hasAvatar ? CachedNetworkImageProvider(user.avatarUrl!) : null,
        child: hasAvatar
            ? null
            : const Icon(Icons.person, color: Colors.white54, size: 22),
      ),
      title: Text(user.displayName,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text('@${user.permalink}',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}
