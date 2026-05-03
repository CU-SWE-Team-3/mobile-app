import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/upload_track.dart';
import '../../../../core/network/dio_client.dart';

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _parseBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

int _firstInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final parsed = _parseInt(map[key]);
    if (parsed != null) return parsed;
  }
  final stats = map['stats'];
  if (stats is Map) {
    final statMap = Map<String, dynamic>.from(stats);
    for (final key in keys) {
      final parsed = _parseInt(statMap[key]);
      if (parsed != null) return parsed;
    }
  }
  final counts = map['counts'];
  if (counts is Map) {
    final countMap = Map<String, dynamic>.from(counts);
    for (final key in keys) {
      final parsed = _parseInt(countMap[key]);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

List<int>? _parseWaveform(dynamic value) {
  if (value is! List) return null;
  return value.map(_parseInt).whereType<int>().toList();
}

String? _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

Iterable<dynamic> _firstList(Map<dynamic, dynamic> map) {
  for (final key in const ['tracks', 'items', 'results']) {
    final value = map[key];
    if (value is List) return value;
  }
  return const [];
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

// Provider for the track currently being edited (null = no edit in progress).
final trackEditProvider = StateProvider<UploadTrack?>((ref) => null);

final myTracksProvider =
    FutureProvider.autoDispose<List<UploadTrack>>((ref) async {
  final dio = ref.watch(dioClientProvider).dio;
  var currentArtistName = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    currentArtistName = prefs.getString('displayName') ??
        prefs.getString('username') ??
        prefs.getString('name') ??
        '';
  } catch (_) {
    currentArtistName = '';
  }
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
      permalink: _firstString(t, const ['permalink', 'slug']),
      shareUrl: _firstString(t, const ['shareUrl', 'trackLink']),
      publicUrl: _firstString(t, const ['publicUrl', 'url']),
      waveform: _parseWaveform(t['waveform']),
      title: t['title'] as String? ?? '',
      artist: artistName.isNotEmpty ? artistName : currentArtistName,
      genre: t['genre'] as String?,
      description: t['description'] as String?,
      isPublic: t['isPublic'] as bool? ?? true,
      enableDirectDownloads: _parseBool(t['enableDirectDownloads']),
      playCount: _firstInt(t, const [
        'playCount',
        'plays',
        'playsCount',
        'playback_count',
        'playbackCount',
      ]),
      likeCount: _firstInt(t, const ['likeCount', 'likes', 'likesCount']),
      commentCount:
          _firstInt(t, const ['commentCount', 'comments', 'commentsCount']),
      repostCount:
          _firstInt(t, const ['repostCount', 'reposts', 'repostsCount']),
      downloadCount: _firstInt(t, const [
        'downloadCount',
        'downloads',
        'downloadsCount',
      ]),
      duration: _parseInt(t['duration']),
      processingState: t['processingState'] as String?,
    );
  }).toList();
});
