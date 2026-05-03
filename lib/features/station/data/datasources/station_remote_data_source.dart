import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../engagement/data/sources/engagement_remote_data_source.dart';

class LikedStation {
  final String id;
  final String title;
  final String description;
  final String? artworkUrl;
  final String? seedTrackId;
  final String? seedTrackTitle;
  final String? seedTrackArtistName;
  final String? seedTrackArtworkUrl;

  const LikedStation({
    required this.id,
    required this.title,
    required this.description,
    this.artworkUrl,
    this.seedTrackId,
    this.seedTrackTitle,
    this.seedTrackArtistName,
    this.seedTrackArtworkUrl,
  });

  factory LikedStation.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] as String? ??
        json['stationId'] as String? ??
        json['id'] as String? ??
        '';
    final seedTrack = json['seedTrack'] as Map<String, dynamic>?;
    final seedArtist = seedTrack?['artist'] as Map<String, dynamic>?;
    return LikedStation(
      id: id,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      artworkUrl: json['artworkUrl'] as String? ?? json['coverUrl'] as String?,
      seedTrackId: seedTrack?['_id'] as String? ?? json['trackId'] as String?,
      seedTrackTitle: seedTrack?['title'] as String?,
      seedTrackArtistName: seedArtist?['displayName'] as String? ??
          seedArtist?['username'] as String? ??
          seedArtist?['name'] as String?,
      seedTrackArtworkUrl: seedTrack?['artworkUrl'] as String? ??
          seedTrack?['coverUrl'] as String?,
    );
  }
}

class StationRemoteDataSource {
  final Dio _dio;

  StationRemoteDataSource(this._dio);

  Future<List<TrackSummary>> getRelatedTracks(String trackId) async {
    final response = await _dio.get('/discovery/related/$trackId');
    final data = response.data;
    final raw = _extractList(data);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TrackSummary.fromJson)
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  Future<bool> isStationLiked(String stationId) async {
    try {
      final response = await _dio.get('/stations/$stationId/like');
      final data = response.data;
      if (data is Map) {
        final inner = data['data'];
        if (inner is Map) {
          return inner['isLiked'] as bool? ?? inner['liked'] as bool? ?? false;
        }
        return data['isLiked'] as bool? ?? data['liked'] as bool? ?? false;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<void> likeStation(String stationId) async {
    await _dio.post(
      '/stations/$stationId/like',
      data: {'stationType': 'curated'},
    );
  }

  Future<void> unlikeStation(String stationId) async {
    await _dio.delete('/stations/$stationId/like');
  }

  Future<List<LikedStation>> getLikedStations() async {
    final response = await _dio.get('/stations/liked');
    final data = response.data;
    final raw =
        _extractList(data, keys: ['stations', 'likedStations', 'items']);
    debugPrint('[Station] getLikedStations raw count=${raw.length}');
    return raw
        .whereType<Map<String, dynamic>>()
        .map(LikedStation.fromJson)
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  List<dynamic> _extractList(
    dynamic data, {
    List<String> keys = const ['tracks', 'related', 'items'],
  }) {
    if (data is List) return data;
    if (data is! Map) return [];
    final inner = data['data'];
    if (inner is List) return inner;
    if (inner is Map) {
      for (final key in keys) {
        final val = inner[key];
        if (val is List) return val;
      }
    }
    for (final key in keys) {
      final val = data[key];
      if (val is List) return val;
    }
    return [];
  }
}
