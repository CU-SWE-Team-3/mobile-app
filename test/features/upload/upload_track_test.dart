import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';

void main() {
  group('UploadTrack Initialization', () {
    test('creates track with only required fields', () {
      const track = UploadTrack(
        title: 'Test Song',
        artist: 'Test Artist',
      );

      expect(track.title, 'Test Song');
      expect(track.artist, 'Test Artist');
    });

    test('title is correct', () {
      const track = UploadTrack(
        title: 'Awesome Track',
        artist: 'Artist Name',
      );

      expect(track.title, 'Awesome Track');
    });

    test('artist is correct', () {
      const track = UploadTrack(
        title: 'Song Name',
        artist: 'Amazing Artist',
      );

      expect(track.artist, 'Amazing Artist');
    });

    test('album is correct', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        album: 'Album Name',
      );

      expect(track.album, 'Album Name');
    });

    test('genre is correct', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        genre: 'Electronic',
      );

      expect(track.genre, 'Electronic');
    });

    test('description is correct', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        description: 'A beautiful track',
      );

      expect(track.description, 'A beautiful track');
    });

    test('duration is correct', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        duration: 180000,
      );

      expect(track.duration, 180000);
    });
  });

  group('UploadTrack File Paths', () {
    test('audioFilePath is set', () {
      const filePath = '/storage/music/song.mp3';
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        audioFilePath: filePath,
      );

      expect(track.audioFilePath, filePath);
    });

    test('coverImagePath is set', () {
      const imagePath = '/storage/images/cover.jpg';
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        coverImagePath: imagePath,
      );

      expect(track.coverImagePath, imagePath);
    });

    test('audioFilePath can be null', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        audioFilePath: null,
      );

      expect(track.audioFilePath, isNull);
    });

    test('coverImagePath can be null', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        coverImagePath: null,
      );

      expect(track.coverImagePath, isNull);
    });
  });

  group('UploadTrack Nullable Fields', () {
    test('album can be null', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        album: null,
      );

      expect(track.album, isNull);
    });

    test('genre can be null', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        genre: null,
      );

      expect(track.genre, isNull);
    });

    test('releaseDate can be null', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        releaseDate: null,
      );

      expect(track.releaseDate, isNull);
    });

    test('description can be null', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        description: null,
      );

      expect(track.description, isNull);
    });

    test('duration can be null', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        duration: null,
      );

      expect(track.duration, isNull);
    });
  });

  group('UploadTrack Default Values', () {
    test('isPublic defaults to true', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
      );

      expect(track.isPublic, true);
    });

    test('tags defaults to empty list', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
      );

      expect(track.tags, isEmpty);
    });

    test('isPublic can be false', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        isPublic: false,
      );

      expect(track.isPublic, false);
    });
  });

  group('UploadTrack Tags', () {
    test('tags has correct length', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        tags: ['electronic', 'dance', 'remix'],
      );

      expect(track.tags.length, 3);
    });

    test('tags contains correct items', () {
      const tagList = ['ambient', 'chill', 'lofi'];
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        tags: tagList,
      );

      expect(track.tags, containsAll(tagList));
      expect(track.tags[0], 'ambient');
      expect(track.tags[1], 'chill');
      expect(track.tags[2], 'lofi');
    });
  });

  group('UploadTrack Duration Calculations', () {
    test('duration in seconds is correct', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        duration: 180000, // 3 minutes
      );

      final durationInSeconds = track.duration! ~/ 1000;
      expect(durationInSeconds, 180);
    });

    test('duration in minutes is correct', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        duration: 300000, // 5 minutes
      );

      final durationInMinutes = track.duration! ~/ 60000;
      expect(durationInMinutes, 5);
    });

    test('duration is positive', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        duration: 240000,
      );

      expect(track.duration, greaterThan(0));
    });
  });

  group('UploadTrack copyWith', () {
    test('copyWith updates title', () {
      const track = UploadTrack(
        title: 'Original Title',
        artist: 'Artist',
      );

      final updated = track.copyWith(title: 'New Title');

      expect(updated.title, 'New Title');
      expect(updated.artist, 'Artist');
    });

    test('copyWith updates artist', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Original Artist',
      );

      final updated = track.copyWith(artist: 'New Artist');

      expect(updated.artist, 'New Artist');
      expect(updated.title, 'Song');
    });

    test('copyWith updates isPublic', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        isPublic: true,
      );

      final updated = track.copyWith(isPublic: false);

      expect(updated.isPublic, false);
    });

    test('copyWith updates genre', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        genre: 'Rock',
      );

      final updated = track.copyWith(genre: 'Jazz');

      expect(updated.genre, 'Jazz');
    });

    test('copyWith updates tags', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        tags: ['old'],
      );

      final updated = track.copyWith(tags: ['new1', 'new2']);

      expect(updated.tags, ['new1', 'new2']);
    });

    test('copyWith updates duration', () {
      const track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        duration: 120000,
      );

      final updated = track.copyWith(duration: 240000);

      expect(updated.duration, 240000);
    });

    test('copyWith updates releaseDate', () {
      final date1 = DateTime(2026, 1, 1);
      final date2 = DateTime(2026, 6, 15);

      final track = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        releaseDate: date1,
      );

      final updated = track.copyWith(releaseDate: date2);

      expect(updated.releaseDate, date2);
    });

    test('copyWith preserves unchanged fields', () {
      final releaseDate = DateTime(2026, 3, 22);
      final track = UploadTrack(
        title: 'Original',
        artist: 'Artist',
        album: 'Album',
        genre: 'Electronic',
        tags: const ['tag1', 'tag2'],
        releaseDate: releaseDate,
        isPublic: false,
        description: 'Description',
        duration: 300000,
        audioFilePath: '/path/to/audio.mp3',
        coverImagePath: '/path/to/cover.jpg',
      );

      final updated = track.copyWith(title: 'Updated');

      expect(updated.artist, 'Artist');
      expect(updated.album, 'Album');
      expect(updated.genre, 'Electronic');
      expect(updated.tags, ['tag1', 'tag2']);
      expect(updated.releaseDate, releaseDate);
      expect(updated.isPublic, false);
      expect(updated.description, 'Description');
      expect(updated.duration, 300000);
      expect(updated.audioFilePath, '/path/to/audio.mp3');
      expect(updated.coverImagePath, '/path/to/cover.jpg');
    });
  });

  group('UploadTrack Equality', () {
    test('two identical tracks are equal (Equatable)', () {
      const track1 = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
      );

      const track2 = UploadTrack(
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
      );

      expect(track1, track2);
    });

    test('two different tracks are not equal', () {
      const track1 = UploadTrack(
        title: 'Song 1',
        artist: 'Artist',
      );

      const track2 = UploadTrack(
        title: 'Song 2',
        artist: 'Artist',
      );

      expect(track1, isNot(track2));
    });
  });

  group('UploadTrack Props', () {
    test('props list has 11 items', () {
      final track = UploadTrack(
        audioFilePath: '/path/audio.mp3',
        coverImagePath: '/path/cover.jpg',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        genre: 'Electronic',
        tags: const ['tag1'],
        releaseDate: DateTime(2026, 3, 22),
        isPublic: true,
        description: 'Description',
        duration: 180000,
      );

      expect(track.props.length, 11);
    });
  });
}
