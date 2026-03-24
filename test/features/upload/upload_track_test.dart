import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/upload/domain/entities/upload_track.dart';

void main() {
  group('UploadTrack', () {
    const track = UploadTrack(
      audioFilePath: '/path/audio.mp3',
      coverImagePath: '/path/cover.jpg',
      title: 'Test Track',
      artist: 'Test Artist',
      album: 'Test Album',
      genre: 'Rock',
      tags: ['tag1', 'tag2'],
      releaseDate: null,
      isPublic: true,
      description: 'Test description',
      duration: 180000,
    );

    test('should create UploadTrack with correct properties', () {
      expect(track.audioFilePath, '/path/audio.mp3');
      expect(track.coverImagePath, '/path/cover.jpg');
      expect(track.title, 'Test Track');
      expect(track.artist, 'Test Artist');
      expect(track.album, 'Test Album');
      expect(track.genre, 'Rock');
      expect(track.tags, ['tag1', 'tag2']);
      expect(track.releaseDate, null);
      expect(track.isPublic, true);
      expect(track.description, 'Test description');
      expect(track.duration, 180000);
    });

    test('copyWith should update fields correctly', () {
      final newTrack = track.copyWith(
        title: 'New Title',
        artist: 'New Artist',
        tags: ['new tag'],
      );

      expect(newTrack.title, 'New Title');
      expect(newTrack.artist, 'New Artist');
      expect(newTrack.tags, ['new tag']);
      expect(newTrack.album, 'Test Album'); // unchanged
    });

    test('props should return correct list', () {
      expect(track.props, [
        '/path/audio.mp3',
        '/path/cover.jpg',
        'Test Track',
        'Test Artist',
        'Test Album',
        'Rock',
        ['tag1', 'tag2'],
        null,
        true,
        'Test description',
        180000,
      ]);
    });

    test('equality should work correctly', () {
      const track2 = UploadTrack(
        audioFilePath: '/path/audio.mp3',
        coverImagePath: '/path/cover.jpg',
        title: 'Test Track',
        artist: 'Test Artist',
        album: 'Test Album',
        genre: 'Rock',
        tags: ['tag1', 'tag2'],
        releaseDate: null,
        isPublic: true,
        description: 'Test description',
        duration: 180000,
      );

      expect(track, track2);
    });

    test('should handle nullable fields', () {
      const trackNullable = UploadTrack(
        title: 'Test',
        artist: 'Artist',
        tags: [],
      );

      expect(trackNullable.audioFilePath, null);
      expect(trackNullable.coverImagePath, null);
      expect(trackNullable.album, null);
      expect(trackNullable.genre, null);
      expect(trackNullable.releaseDate, null);
      expect(trackNullable.description, null);
      expect(trackNullable.duration, null);
    });
  });
}