import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/messaging/domain/entities/attachment.dart';

void main() {
  // ── Construction ────────────────────────────────────────────────────────────
  group('Attachment — direct construction', () {
    test('stores type and referenceId', () {
      const a = Attachment(type: 'track', referenceId: 'ref_001');
      expect(a.type, 'track');
      expect(a.referenceId, 'ref_001');
    });

    test('optional rich fields default to null', () {
      const a = Attachment(type: 'track', referenceId: 'ref_001');
      expect(a.title, isNull);
      expect(a.artworkUrl, isNull);
      expect(a.permalink, isNull);
      expect(a.artistName, isNull);
      expect(a.duration, isNull);
    });

    test('stores all optional rich fields when provided', () {
      const a = Attachment(
        type: 'track',
        referenceId: 'ref_002',
        title: 'My Track',
        artworkUrl: 'https://cdn.example.com/art.jpg',
        permalink: 'my-track',
        artistName: 'DJ X',
        duration: 240,
      );
      expect(a.title, 'My Track');
      expect(a.artworkUrl, 'https://cdn.example.com/art.jpg');
      expect(a.permalink, 'my-track');
      expect(a.artistName, 'DJ X');
      expect(a.duration, 240);
    });
  });

  // ── Computed properties ─────────────────────────────────────────────────────
  group('Attachment.hasRichData', () {
    test('returns true when title is non-empty', () {
      const a =
          Attachment(type: 'track', referenceId: 'r1', title: 'Track Title');
      expect(a.hasRichData, isTrue);
    });

    test('returns false when title is null', () {
      const a = Attachment(type: 'track', referenceId: 'r1');
      expect(a.hasRichData, isFalse);
    });

    test('returns false when title is an empty string', () {
      const a = Attachment(type: 'track', referenceId: 'r1', title: '');
      expect(a.hasRichData, isFalse);
    });
  });

  group('Attachment.isAvailable', () {
    test('returns true when referenceId is non-empty', () {
      const a = Attachment(type: 'track', referenceId: 'valid_id');
      expect(a.isAvailable, isTrue);
    });

    test('returns false when referenceId is empty', () {
      const a = Attachment(type: 'track', referenceId: '');
      expect(a.isAvailable, isFalse);
    });
  });

  // ── fromJson — flat (socket payload) ───────────────────────────────────────
  group('Attachment.fromJson — flat socket payload', () {
    test('parses type "track" correctly', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': 'track_abc',
      });
      expect(a.type, 'track');
      expect(a.referenceId, 'track_abc');
    });

    test('parses type "playlist" correctly', () {
      final a = Attachment.fromJson({
        'type': 'playlist',
        'referenceId': 'playlist_xyz',
      });
      expect(a.type, 'playlist');
    });

    test('normalizes type with mixed case', () {
      final a = Attachment.fromJson({'type': 'Track', 'referenceId': 'id1'});
      expect(a.type, 'track');
    });

    test('uses trackId as fallback key for referenceId', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'trackId': 'track_fallback',
      });
      expect(a.referenceId, 'track_fallback');
    });

    test('uses playlistId as fallback key for referenceId', () {
      final a = Attachment.fromJson({
        'type': 'playlist',
        'playlistId': 'playlist_fallback',
      });
      expect(a.referenceId, 'playlist_fallback');
    });

    test('referenceId is empty string when all keys are missing', () {
      final a = Attachment.fromJson({'type': 'track'});
      expect(a.referenceId, '');
    });

    test('parses title from flat json', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': 'id1',
        'title': 'Flat Title',
      });
      expect(a.title, 'Flat Title');
    });

    test('parses artworkUrl from flat json', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': 'id1',
        'artworkUrl': 'https://img.com/art.jpg',
      });
      expect(a.artworkUrl, 'https://img.com/art.jpg');
    });

    test('parses duration from flat json', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': 'id1',
        'duration': 180,
      });
      expect(a.duration, 180);
    });

    test('duration is null when absent', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': 'id1',
      });
      expect(a.duration, isNull);
    });
  });

  // ── fromJson — embedded object (REST payload) ──────────────────────────────
  group('Attachment.fromJson — REST embedded object', () {
    test('extracts referenceId from embedded object _id', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': {
          '_id': 'embedded_001',
          'title': 'REST Track',
        },
      });
      expect(a.referenceId, 'embedded_001');
      expect(a.title, 'REST Track');
    });

    test('extracts artworkUrl from embedded coverUrl key', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': {
          '_id': 'id2',
          'coverUrl': 'https://cdn.com/cover.jpg',
        },
      });
      expect(a.artworkUrl, 'https://cdn.com/cover.jpg');
    });

    test('extracts artistName from nested artist map', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': {
          '_id': 'id3',
          'artist': {'displayName': 'Artist Name'},
        },
      });
      expect(a.artistName, 'Artist Name');
    });

    test('extracts duration from embedded map', () {
      final a = Attachment.fromJson({
        'type': 'track',
        'referenceId': {
          '_id': 'id4',
          'duration': 300,
        },
      });
      expect(a.duration, 300);
    });
  });

  // ── toJson ──────────────────────────────────────────────────────────────────
  group('Attachment.toJson', () {
    test('always includes type and referenceId', () {
      const a = Attachment(type: 'track', referenceId: 'ref_001');
      final json = a.toJson();
      expect(json['type'], 'track');
      expect(json['referenceId'], 'ref_001');
    });

    test('includes title only when not null', () {
      const withTitle =
          Attachment(type: 'track', referenceId: 'r1', title: 'T');
      const withoutTitle = Attachment(type: 'track', referenceId: 'r1');

      expect(withTitle.toJson().containsKey('title'), isTrue);
      expect(withoutTitle.toJson().containsKey('title'), isFalse);
    });

    test('includes artworkUrl only when not null', () {
      const a = Attachment(
          type: 'track', referenceId: 'r1', artworkUrl: 'http://img.com');
      expect(a.toJson().containsKey('artworkUrl'), isTrue);
    });

    test('includes duration only when not null', () {
      const withDur = Attachment(type: 'track', referenceId: 'r1', duration: 120);
      const withoutDur = Attachment(type: 'track', referenceId: 'r1');

      expect(withDur.toJson().containsKey('duration'), isTrue);
      expect(withoutDur.toJson().containsKey('duration'), isFalse);
    });

    test('round-trips through toJson and produces a Map', () {
      const original = Attachment(
        type: 'playlist',
        referenceId: 'pl_001',
        title: 'Summer Vibes',
        artworkUrl: 'https://cdn.com/art.jpg',
        permalink: 'summer-vibes',
        artistName: 'Curator',
        duration: null,
      );
      final json = original.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json['type'], 'playlist');
      expect(json['referenceId'], 'pl_001');
      expect(json['title'], 'Summer Vibes');
    });
  });

  // ── normalizeType edge cases ────────────────────────────────────────────────
  group('Attachment — type normalization', () {
    test('"Track" maps to "track"', () {
      final a = Attachment.fromJson({'type': 'Track', 'referenceId': 'id'});
      expect(a.type, 'track');
    });

    test('"Playlist" maps to "playlist"', () {
      final a = Attachment.fromJson({'type': 'Playlist', 'referenceId': 'id'});
      expect(a.type, 'playlist');
    });

    test('unknown type is kept lowercased', () {
      final a = Attachment.fromJson({'type': 'Album', 'referenceId': 'id'});
      expect(a.type, 'album');
    });

    test('null type results in empty string', () {
      final a = Attachment.fromJson({'referenceId': 'id'});
      expect(a.type, '');
    });
  });
}
