import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/upload_track.dart';
import '../../../../core/network/dio_client.dart';

final myTracksProvider =
    FutureProvider.autoDispose<List<UploadTrack>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  final prefs = await SharedPreferences.getInstance();
  final currentArtistName = prefs.getString('displayName') ??
      prefs.getString('username') ??
      prefs.getString('name') ??
      '';
  final response = await dio.get('/tracks/my-tracks');
  final data = _extractTrackItems(response.data);
  return data.map((t) {
    final artist = t['artist'] is Map<String, dynamic>
        ? t['artist'] as Map<String, dynamic>
        : <String, dynamic>{};
    final user = t['user'] is Map<String, dynamic>
        ? t['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final audio = t['audio'] is Map<String, dynamic>
        ? t['audio'] as Map<String, dynamic>
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
      hlsUrl: t['hlsUrl'] as String? ?? audio['hlsUrl'] as String?,
      artworkUrl: t['artworkUrl'] as String?,
      waveform: _parseWaveform(t['waveform']),
      title: t['title'] as String? ?? '',
      artist: artistName.isNotEmpty ? artistName : currentArtistName,
      genre: t['genre'] as String?,
      description: t['description'] as String?,
      isPublic: t['isPublic'] as bool? ?? true,
      duration: _parseInt(t['duration']),
      processingState: t['processingState'] as String?,
    );
  }).toList();
});

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

List<int>? _parseWaveform(dynamic value) {
  if (value is! List) return null;
  return value
      .map(_parseInt)
      .whereType<int>()
      .toList();
}

List<Map<String, dynamic>> _extractTrackItems(dynamic body) {
  Iterable<dynamic> rawItems = const [];
  if (body is List) {
    rawItems = body;
  } else if (body is Map) {
    final data = body['data'];
    if (data is List) {
      rawItems = data;
    } else if (data is Map) {
      rawItems = _firstList(data);
    } else {
      rawItems = _firstList(body);
    }
  }

  return rawItems
      .whereType<Map>()
      .map((track) => Map<String, dynamic>.from(track))
      .toList();
}

Iterable<dynamic> _firstList(Map<dynamic, dynamic> map) {
  for (final key in const ['tracks', 'items', 'results']) {
    final value = map[key];
    if (value is List) return value;
  }
  return const [];
}
