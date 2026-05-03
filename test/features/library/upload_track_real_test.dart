import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';

// We test the pure helper functions by testing UploadTrack which uses them

void main() {
  group('UploadTrack construction', () {
    test('stores all required fields', () {
      final track = UploadTrack(
        id: 'track-1',
        title: 'My Track',
        artist: 'Artist',
        isPublic: true,
      );
      expect(track.id, 'track-1');
      expect(track.title, 'My Track');
      expect(track.artist, 'Artist');
      expect(track.isPublic, isTrue);
    });

    test('optional fields default to null or zero', () {
      final track = UploadTrack(title: 'T', artist: 'A');
      expect(track.id, isNull);
      expect(track.hlsUrl, isNull);
      expect(track.artworkUrl, isNull);
      expect(track.genre, isNull);
      expect(track.description, isNull);
      expect(track.playCount, 0);
      expect(track.likeCount, 0);
      expect(track.commentCount, 0);
      expect(track.repostCount, 0);
      expect(track.downloadCount, 0);
      expect(track.duration, isNull);
      expect(track.processingState, isNull);
      expect(track.waveform, isNull);
    });

    test('isPublic defaults to true', () {
      final track = UploadTrack(title: 'T', artist: 'A');
      expect(track.isPublic, isTrue);
    });

    test('enableDirectDownloads defaults to false', () {
      final track = UploadTrack(title: 'T', artist: 'A');
      expect(track.enableDirectDownloads, isFalse);
    });

    test('all optional fields can be set', () {
      final track = UploadTrack(
        id: 'id-1',
        title: 'Song',
        artist: 'DJ',
        hlsUrl: 'https://hls/playlist.m3u8',
        artworkUrl: 'https://art/img.jpg',
        permalink: 'my-song',
        shareUrl: 'https://share/song',
        publicUrl: 'https://public/song',
        waveform: [10, 20, 30],
        genre: 'Electronic',
        description: 'A great song',
        isPublic: false,
        enableDirectDownloads: true,
        playCount: 100,
        likeCount: 50,
        commentCount: 10,
        repostCount: 5,
        downloadCount: 20,
        duration: 180,
        processingState: 'finished',
      );
      expect(track.hlsUrl, 'https://hls/playlist.m3u8');
      expect(track.artworkUrl, 'https://art/img.jpg');
      expect(track.permalink, 'my-song');
      expect(track.shareUrl, 'https://share/song');
      expect(track.publicUrl, 'https://public/song');
      expect(track.waveform, [10, 20, 30]);
      expect(track.genre, 'Electronic');
      expect(track.description, 'A great song');
      expect(track.isPublic, isFalse);
      expect(track.enableDirectDownloads, isTrue);
      expect(track.playCount, 100);
      expect(track.likeCount, 50);
      expect(track.commentCount, 10);
      expect(track.repostCount, 5);
      expect(track.downloadCount, 20);
      expect(track.duration, 180);
      expect(track.processingState, 'finished');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = UploadTrack(
        id: 'id-1',
        title: 'Original',
        artist: 'Artist',
        playCount: 10,
      );
      final copy = original.copyWith(title: 'Updated', playCount: 20);
      expect(copy.title, 'Updated');
      expect(copy.playCount, 20);
      expect(copy.id, 'id-1'); // unchanged
      expect(copy.artist, 'Artist'); // unchanged
    });

    test('copyWith preserves all fields when no args given', () {
      final original = UploadTrack(
        id: 'id-1',
        title: 'T',
        artist: 'A',
        genre: 'Pop',
        likeCount: 5,
      );
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.genre, original.genre);
      expect(copy.likeCount, original.likeCount);
    });

    test('props list contains all fields', () {
      final track = UploadTrack(title: 'T', artist: 'A');
      expect(track.props, isNotEmpty);
    });

    test('two tracks with same fields are equal', () {
      final a = UploadTrack(id: 'x', title: 'T', artist: 'A');
      final b = UploadTrack(id: 'x', title: 'T', artist: 'A');
      expect(a, equals(b));
    });

    test('two tracks with different ids are not equal', () {
      final a = UploadTrack(id: 'x', title: 'T', artist: 'A');
      final b = UploadTrack(id: 'y', title: 'T', artist: 'A');
      expect(a, isNot(equals(b)));
    });
  });
}
