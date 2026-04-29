import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/upload_track.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/session_provider.dart';

final myTracksProvider = FutureProvider.autoDispose<List<UploadTrack>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final userId = ref.watch(sessionUserIdProvider);
  if (userId.isEmpty) return [];
  final prefs = await SharedPreferences.getInstance();
  final currentArtistName = prefs.getString('displayName') ??
      prefs.getString('username') ??
      prefs.getString('name') ??
      '';
  final response = await dio.get('/tracks/my-tracks');
  final data = response.data['data'];
  if (data is! List) return [];
  return data.map((t) {
    final artist = t['artist'] is Map<String, dynamic>
        ? t['artist'] as Map<String, dynamic>
        : <String, dynamic>{};
    final user = t['user'] is Map<String, dynamic>
        ? t['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final artistName = (artist['displayName'] ??
            artist['username'] ??
            artist['name'] ??
            user['displayName'] ??
            user['username'] ??
            user['name'] ??
            t['artistName'] ??
            '')
        .toString();
    return UploadTrack(
      id: t['_id'] as String?,
      hlsUrl: t['hlsUrl'] as String?,
      artworkUrl: t['artworkUrl'] as String?,
      waveform: (t['waveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      title: t['title'] as String? ?? '',
      artist: artistName.isNotEmpty ? artistName : currentArtistName,
      genre: t['genre'] as String?,
      description: t['description'] as String?,
      isPublic: t['isPublic'] as bool? ?? true,
      duration: t['duration'] as int?,
    );
  }).toList();
});
