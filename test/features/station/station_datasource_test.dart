import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/station/data/datasources/station_remote_data_source.dart';

void main() {
  // ── LikedStation.fromJson ─────────────────────────────────────────────────

  group('LikedStation.fromJson', () {
    test('parses full payload with seedTrack', () {
      final station = LikedStation.fromJson({
        '_id': 'station-1',
        'title': 'Chill Vibes',
        'description': 'Relaxing music',
        'artworkUrl': 'https://img/art.jpg',
        'seedTrack': {
          '_id': 'track-1',
          'title': 'Lo-Fi Beat',
          'artworkUrl': 'https://img/track.jpg',
          'artist': {
            'displayName': 'DJ Chill',
          },
        },
      });
      expect(station.id, 'station-1');
      expect(station.title, 'Chill Vibes');
      expect(station.description, 'Relaxing music');
      expect(station.artworkUrl, 'https://img/art.jpg');
      expect(station.seedTrackId, 'track-1');
      expect(station.seedTrackTitle, 'Lo-Fi Beat');
      expect(station.seedTrackArtistName, 'DJ Chill');
      expect(station.seedTrackArtworkUrl, 'https://img/track.jpg');
    });

    test('falls back to stationId when _id missing', () {
      final station = LikedStation.fromJson({
        'stationId': 'sid-2',
        'title': 'Pop Hits',
        'description': '',
      });
      expect(station.id, 'sid-2');
    });

    test('falls back to id when _id and stationId missing', () {
      final station = LikedStation.fromJson({
        'id': 'id-3',
        'title': 'Rock',
        'description': '',
      });
      expect(station.id, 'id-3');
    });

    test('id defaults to empty string when all id fields missing', () {
      final station = LikedStation.fromJson({
        'title': 'T',
        'description': '',
      });
      expect(station.id, '');
    });

    test('title falls back to name field', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'name': 'Named Station',
        'description': '',
      });
      expect(station.title, 'Named Station');
    });

    test('artworkUrl falls back to coverUrl', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'title': 'T',
        'description': '',
        'coverUrl': 'https://cover.jpg',
      });
      expect(station.artworkUrl, 'https://cover.jpg');
    });

    test('seedTrackId falls back to trackId field', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'title': 'T',
        'description': '',
        'trackId': 'fallback-track-id',
      });
      expect(station.seedTrackId, 'fallback-track-id');
    });

    test('seedTrackArtistName falls back to username', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'title': 'T',
        'description': '',
        'seedTrack': {
          '_id': 'tid',
          'title': 'T',
          'artist': {'username': 'dj_user'},
        },
      });
      expect(station.seedTrackArtistName, 'dj_user');
    });

    test('seedTrackArtistName falls back to name', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'title': 'T',
        'description': '',
        'seedTrack': {
          '_id': 'tid',
          'title': 'T',
          'artist': {'name': 'DJ Name'},
        },
      });
      expect(station.seedTrackArtistName, 'DJ Name');
    });

    test('seedTrackArtworkUrl falls back to coverUrl in seedTrack', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'title': 'T',
        'description': '',
        'seedTrack': {
          '_id': 'tid',
          'title': 'T',
          'coverUrl': 'https://cover/track.jpg',
        },
      });
      expect(station.seedTrackArtworkUrl, 'https://cover/track.jpg');
    });

    test('all optional fields are null when absent', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'title': 'T',
        'description': '',
      });
      expect(station.artworkUrl, isNull);
      expect(station.seedTrackId, isNull);
      expect(station.seedTrackTitle, isNull);
      expect(station.seedTrackArtistName, isNull);
      expect(station.seedTrackArtworkUrl, isNull);
    });

    test('description defaults to empty string when null', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'title': 'T',
      });
      expect(station.description, '');
    });

    test('title defaults to empty string when null', () {
      final station = LikedStation.fromJson({
        '_id': 's1',
        'description': '',
      });
      expect(station.title, '');
    });
  });
}
