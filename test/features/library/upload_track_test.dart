import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';

void main() {
  group('UploadTrack entity', () {
    // ── Constructor & Defaults ─────────────────────────────────────────────

    group('default values', () {
      test('has correct defaults when only required fields provided', () {
        const track = UploadTrack(title: 'My Song', artist: 'Alice');

        expect(track.title, 'My Song');
        expect(track.artist, 'Alice');
        expect(track.tags, isEmpty);
        expect(track.isPublic, isTrue);
        expect(track.enableDirectDownloads, isFalse);
        expect(track.playCount, 0);
        expect(track.likeCount, 0);
        expect(track.commentCount, 0);
        expect(track.repostCount, 0);
        expect(track.downloadCount, 0);
      });

      test('optional fields are null by default', () {
        const track = UploadTrack(title: '', artist: '');

        expect(track.id, isNull);
        expect(track.hlsUrl, isNull);
        expect(track.artworkUrl, isNull);
        expect(track.permalink, isNull);
        expect(track.shareUrl, isNull);
        expect(track.publicUrl, isNull);
        expect(track.waveform, isNull);
        expect(track.audioFilePath, isNull);
        expect(track.coverImagePath, isNull);
        expect(track.album, isNull);
        expect(track.genre, isNull);
        expect(track.releaseDate, isNull);
        expect(track.description, isNull);
        expect(track.duration, isNull);
        expect(track.processingState, isNull);
      });
    });

    // ── copyWith ──────────────────────────────────────────────────────────

    group('copyWith', () {
      const base = UploadTrack(
        title: 'Original',
        artist: 'Bob',
        isPublic: true,
        playCount: 5,
      );

      test('returns new instance with updated title', () {
        final updated = base.copyWith(title: 'Updated');
        expect(updated.title, 'Updated');
        expect(updated.artist, 'Bob'); // unchanged
      });

      test('returns new instance with updated artist', () {
        final updated = base.copyWith(artist: 'Carol');
        expect(updated.artist, 'Carol');
        expect(updated.title, 'Original'); // unchanged
      });

      test('can toggle isPublic to false', () {
        final updated = base.copyWith(isPublic: false);
        expect(updated.isPublic, isFalse);
      });

      test('can enable direct downloads', () {
        final updated = base.copyWith(enableDirectDownloads: true);
        expect(updated.enableDirectDownloads, isTrue);
      });

      test('preserves all unchanged fields', () {
        final updated = base.copyWith(genre: 'Electronic');
        expect(updated.title, base.title);
        expect(updated.artist, base.artist);
        expect(updated.isPublic, base.isPublic);
        expect(updated.playCount, base.playCount);
        expect(updated.genre, 'Electronic');
      });

      test('can set server-assigned id', () {
        final updated = base.copyWith(id: 'server-id-123');
        expect(updated.id, 'server-id-123');
      });

      test('can set permalink and share url', () {
        final updated =
            base.copyWith(permalink: 'my-song', shareUrl: 'https://example.com/tracks/my-song');
        expect(updated.permalink, 'my-song');
        expect(updated.shareUrl, 'https://example.com/tracks/my-song');
      });

      test('can update tags list', () {
        final updated = base.copyWith(tags: ['rock', 'live']);
        expect(updated.tags, ['rock', 'live']);
      });

      test('can set waveform data', () {
        final updated = base.copyWith(waveform: [10, 20, 30]);
        expect(updated.waveform, [10, 20, 30]);
      });

      test('can set processingState', () {
        final processing = base.copyWith(processingState: 'Processing');
        expect(processing.processingState, 'Processing');

        final finished = processing.copyWith(processingState: 'Finished');
        expect(finished.processingState, 'Finished');
      });

      test('can set duration in milliseconds', () {
        final updated = base.copyWith(duration: 180000);
        expect(updated.duration, 180000);
      });
    });

    // ── Equatable / props ─────────────────────────────────────────────────

    group('equality (Equatable)', () {
      test('two tracks with same fields are equal', () {
        const a = UploadTrack(title: 'Song', artist: 'Artist', playCount: 3);
        const b = UploadTrack(title: 'Song', artist: 'Artist', playCount: 3);
        expect(a, equals(b));
      });

      test('tracks differ when title differs', () {
        const a = UploadTrack(title: 'Song A', artist: 'Artist');
        const b = UploadTrack(title: 'Song B', artist: 'Artist');
        expect(a, isNot(equals(b)));
      });

      test('tracks differ when artist differs', () {
        const a = UploadTrack(title: 'Song', artist: 'Alice');
        const b = UploadTrack(title: 'Song', artist: 'Bob');
        expect(a, isNot(equals(b)));
      });

      test('tracks differ when isPublic differs', () {
        const a = UploadTrack(title: 'T', artist: 'A', isPublic: true);
        const b = UploadTrack(title: 'T', artist: 'A', isPublic: false);
        expect(a, isNot(equals(b)));
      });

      test('tracks differ when tags differ', () {
        const a = UploadTrack(title: 'T', artist: 'A', tags: ['rock']);
        const b = UploadTrack(title: 'T', artist: 'A', tags: ['pop']);
        expect(a, isNot(equals(b)));
      });

      test('tracks differ when play counts differ', () {
        const a = UploadTrack(title: 'T', artist: 'A', playCount: 10);
        const b = UploadTrack(title: 'T', artist: 'A', playCount: 20);
        expect(a, isNot(equals(b)));
      });

      test('tracks differ when processingState differs', () {
        const a = UploadTrack(title: 'T', artist: 'A', processingState: 'Processing');
        const b = UploadTrack(title: 'T', artist: 'A', processingState: 'Finished');
        expect(a, isNot(equals(b)));
      });

      test('props list contains all discriminating fields', () {
        const track = UploadTrack(
          id: 'id',
          title: 'T',
          artist: 'A',
          permalink: 'perm',
          playCount: 1,
          likeCount: 2,
          commentCount: 3,
          repostCount: 4,
          downloadCount: 5,
        );
        final props = track.props;
        expect(props, contains('id'));
        expect(props, contains('T'));
        expect(props, contains('A'));
        expect(props, contains('perm'));
        expect(props, contains(1));
        expect(props, contains(2));
        expect(props, contains(3));
        expect(props, contains(4));
        expect(props, contains(5));
      });
    });

    // ── Business logic: visibility toggle ─────────────────────────────────

    group('public/private visibility', () {
      test('track is public by default', () {
        const track = UploadTrack(title: 'T', artist: 'A');
        expect(track.isPublic, isTrue);
      });

      test('track can be created as private', () {
        const track = UploadTrack(title: 'T', artist: 'A', isPublic: false);
        expect(track.isPublic, isFalse);
      });

      test('switching public to private via copyWith preserves metadata', () {
        const pub = UploadTrack(title: 'Private Track', artist: 'A', isPublic: true);
        final priv = pub.copyWith(isPublic: false);
        expect(priv.isPublic, isFalse);
        expect(priv.title, pub.title);
        expect(priv.artist, pub.artist);
      });
    });

    // ── Business logic: engagement counters ───────────────────────────────

    group('engagement counters', () {
      test('all counters default to zero', () {
        const t = UploadTrack(title: '', artist: '');
        expect(t.playCount, 0);
        expect(t.likeCount, 0);
        expect(t.commentCount, 0);
        expect(t.repostCount, 0);
        expect(t.downloadCount, 0);
      });

      test('counters can be set to positive values', () {
        const t = UploadTrack(
          title: '',
          artist: '',
          playCount: 100,
          likeCount: 50,
          commentCount: 10,
          repostCount: 5,
          downloadCount: 2,
        );
        expect(t.playCount, 100);
        expect(t.likeCount, 50);
        expect(t.commentCount, 10);
        expect(t.repostCount, 5);
        expect(t.downloadCount, 2);
      });
    });

    // ── Edge cases ────────────────────────────────────────────────────────

    group('edge cases', () {
      test('empty title is valid', () {
        const track = UploadTrack(title: '', artist: '');
        expect(track.title, '');
      });

      test('empty tags list is not null', () {
        const track = UploadTrack(title: '', artist: '');
        expect(track.tags, isNotNull);
        expect(track.tags, isEmpty);
      });

      test('duration in milliseconds stores correctly', () {
        const track = UploadTrack(title: '', artist: '', duration: 240000);
        expect(track.duration, 240000);
      });

      test('waveform list preserves order', () {
        const track = UploadTrack(title: '', artist: '', waveform: [5, 80, 30, 95, 10]);
        expect(track.waveform, [5, 80, 30, 95, 10]);
      });
    });
  });
}
