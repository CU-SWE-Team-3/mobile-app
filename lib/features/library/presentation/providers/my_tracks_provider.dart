import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/upload_track.dart';
import '../../../../core/network/dio_client.dart';

final myTracksProvider = FutureProvider.autoDispose<List<UploadTrack>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final response = await dio.get('/tracks/my-tracks');
  final data = response.data['data'];
  if (data is! List) return [];
  final raw = data;
  return raw.map((t) {
    return UploadTrack(
      title: t['title'] as String? ?? '',
      artist: (t['artist'] is Map) ? (t['artist']['displayName'] as String? ?? '') : '',
      genre: t['genre'] as String?,
      description: t['description'] as String?,
      isPublic: t['isPublic'] as bool? ?? true,
      duration: t['duration'] as int?,
    );
  }).toList();
});
