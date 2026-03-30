import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';
import 'package:soundcloud_clone/features/library/presentation/providers/upload_provider.dart';

/// Simple test double for DioClient (no mocks used)
class _TestDioClient implements DioClient {
  @override
  late final Dio dio;

  _TestDioClient() {
    dio = Dio();
  }

  @override
  Future<void> init() async {}

  @override
  void setAuthToken(String token) {}
}

void main() {
  group('UploadState Initialization', () {
    test('initial defaults are correct for all flags', () {
      final track = UploadTrack(title: 'Song', artist: 'Artist');
      final state = UploadState(track: track);

      expect(state.isLoading, false);
      expect(state.isUploading, false);
      expect(state.uploadProgress, 0.0);
      expect(state.error, isNull);
      expect(state.successMessage, isNull);
      expect(state.waveformLoaded, false);
    });

    test('track is set correctly', () {
      final track = UploadTrack(title: 'Test', artist: 'Artist');
      final state = UploadState(track: track);

      expect(state.track.title, 'Test');
      expect(state.track.artist, 'Artist');
    });
  });

  group('UploadState copyWith', () {
    late UploadState baseState;

    setUp(() {
      baseState = UploadState(
        track: UploadTrack(title: 'Original', artist: 'Artist'),
        isLoading: false,
        isUploading: false,
        uploadProgress: 0.0,
        error: null,
        successMessage: null,
        waveformLoaded: false,
      );
    });

    test('copyWith updates track', () {
      final newTrack = UploadTrack(title: 'New Track', artist: 'New Artist');
      final updated = baseState.copyWith(track: newTrack);

      expect(updated.track.title, 'New Track');
      expect(updated.track.artist, 'New Artist');
      expect(updated.isLoading, false);
    });

    test('copyWith updates isLoading', () {
      final updated = baseState.copyWith(isLoading: true);

      expect(updated.isLoading, true);
      expect(updated.track.title, 'Original');
    });

    test('copyWith updates isUploading', () {
      final updated = baseState.copyWith(isUploading: true);

      expect(updated.isUploading, true);
      expect(updated.uploadProgress, 0.0);
    });

    test('copyWith updates uploadProgress', () {
      final updated = baseState.copyWith(uploadProgress: 0.5);

      expect(updated.uploadProgress, 0.5);
      expect(updated.isUploading, false);
    });

    test('copyWith updates error', () {
      final updated = baseState.copyWith(error: 'Upload failed');

      expect(updated.error, 'Upload failed');
      expect(updated.successMessage, isNull);
    });

    test('copyWith clears error when null passed', () {
      final stateWithError = baseState.copyWith(error: 'Some error');
      final cleared = stateWithError.copyWith(error: null);

      expect(cleared.error, isNull);
    });

    test('copyWith updates successMessage', () {
      final updated = baseState.copyWith(successMessage: 'Upload complete');

      expect(updated.successMessage, 'Upload complete');
      expect(updated.error, isNull);
    });

    test('copyWith clears successMessage when null passed', () {
      final stateWithMessage =
          baseState.copyWith(successMessage: 'Success message');
      final cleared = stateWithMessage.copyWith(successMessage: null);

      expect(cleared.successMessage, isNull);
    });

    test('copyWith updates waveformLoaded', () {
      final updated = baseState.copyWith(waveformLoaded: true);

      expect(updated.waveformLoaded, true);
      expect(updated.track.title, 'Original');
    });
  });

  group('UploadState uploadProgress Range', () {
    test('uploadProgress is between 0.0 and 1.0', () {
      final state = UploadState(
        track: UploadTrack(title: 'Song', artist: 'Artist'),
        uploadProgress: 0.75,
      );

      expect(state.uploadProgress, greaterThanOrEqualTo(0.0));
      expect(state.uploadProgress, lessThanOrEqualTo(1.0));
    });
  });

  group('UploadNotifier Initialization', () {
    test('initial state has empty title and artist', () {
      final notifier = UploadNotifier(_TestDioClient());
      final state = notifier.state;

      expect(state.track.title, '');
      expect(state.track.artist, '');
    });

    test('initial state has all flags as default', () {
      final notifier = UploadNotifier(_TestDioClient());
      final state = notifier.state;

      expect(state.isLoading, false);
      expect(state.isUploading, false);
      expect(state.uploadProgress, 0.0);
      expect(state.error, isNull);
      expect(state.successMessage, isNull);
      expect(state.waveformLoaded, false);
    });
  });

  group('UploadNotifier updateTrack', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
    });

    test('updateTrack sets new track correctly', () {
      final newTrack = UploadTrack(
        title: 'New Song',
        artist: 'New Artist',
        genre: 'Rock',
      );

      notifier.updateTrack(newTrack);

      expect(notifier.state.track.title, 'New Song');
      expect(notifier.state.track.artist, 'New Artist');
      expect(notifier.state.track.genre, 'Rock');
    });
  });

  group('UploadNotifier updateTrackField', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
    });

    test('updateTrackField updates title', () {
      notifier.updateTrackField(title: 'Updated Title');

      expect(notifier.state.track.title, 'Updated Title');
    });

    test('updateTrackField updates artist', () {
      notifier.updateTrackField(artist: 'Updated Artist');

      expect(notifier.state.track.artist, 'Updated Artist');
    });

    test('updateTrackField updates genre', () {
      notifier.updateTrackField(genre: 'Jazz');

      expect(notifier.state.track.genre, 'Jazz');
    });

    test('updateTrackField updates isPublic to false', () {
      notifier.updateTrackField(isPublic: false);

      expect(notifier.state.track.isPublic, false);
    });

    test('updateTrackField updates tags', () {
      notifier.updateTrackField(tags: ['tag1', 'tag2', 'tag3']);

      expect(notifier.state.track.tags, ['tag1', 'tag2', 'tag3']);
      expect(notifier.state.track.tags.length, 3);
    });

    test('updateTrackField updates duration', () {
      notifier.updateTrackField(duration: 240000);

      expect(notifier.state.track.duration, 240000);
    });

    test('updateTrackField updates audioFilePath', () {
      const filePath = '/storage/music/track.mp3';
      notifier.updateTrackField(audioFilePath: filePath);

      expect(notifier.state.track.audioFilePath, filePath);
    });

    test('updateTrackField updates coverImagePath', () {
      const imagePath = '/storage/images/cover.jpg';
      notifier.updateTrackField(coverImagePath: imagePath);

      expect(notifier.state.track.coverImagePath, imagePath);
    });

    test('updateTrackField updates album', () {
      notifier.updateTrackField(album: 'My Album');

      expect(notifier.state.track.album, 'My Album');
    });

    test('updateTrackField updates description', () {
      const desc = 'Beautiful track description';
      notifier.updateTrackField(description: desc);

      expect(notifier.state.track.description, desc);
    });

    test('updateTrackField updates releaseDate', () {
      final date = DateTime(2026, 6, 15);
      notifier.updateTrackField(releaseDate: date);

      expect(notifier.state.track.releaseDate, date);
    });
  });

  group('UploadNotifier setWaveformLoaded', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
    });

    test('setWaveformLoaded sets true', () {
      notifier.setWaveformLoaded(true);

      expect(notifier.state.waveformLoaded, true);
    });

    test('setWaveformLoaded sets false', () {
      notifier.setWaveformLoaded(true);
      notifier.setWaveformLoaded(false);

      expect(notifier.state.waveformLoaded, false);
    });
  });

  group('UploadNotifier clearError', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
    });

    test('clearError sets error to null', () {
      notifier.state = notifier.state.copyWith(error: 'Some error');
      notifier.clearError();

      expect(notifier.state.error, isNull);
    });
  });

  group('UploadNotifier clearSuccessMessage', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
    });

    test('clearSuccessMessage sets successMessage to null', () {
      notifier.state =
          notifier.state.copyWith(successMessage: 'Upload success');
      notifier.clearSuccessMessage();

      expect(notifier.state.successMessage, isNull);
    });
  });

  group('UploadNotifier resetUpload', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
    });

    test('resetUpload resets track to empty title and artist', () {
      notifier.updateTrackField(title: 'Test', artist: 'Artist');
      notifier.resetUpload();

      expect(notifier.state.track.title, '');
      expect(notifier.state.track.artist, '');
    });

    test('resetUpload resets isUploading to false', () {
      notifier.state = notifier.state.copyWith(isUploading: true);
      notifier.resetUpload();

      expect(notifier.state.isUploading, false);
    });

    test('resetUpload resets uploadProgress to 0.0', () {
      notifier.state = notifier.state.copyWith(uploadProgress: 0.8);
      notifier.resetUpload();

      expect(notifier.state.uploadProgress, 0.0);
    });

    test('resetUpload resets error to null', () {
      notifier.state = notifier.state.copyWith(error: 'Some error');
      notifier.resetUpload();

      expect(notifier.state.error, isNull);
    });

    test('resetUpload resets successMessage to null', () {
      notifier.state =
          notifier.state.copyWith(successMessage: 'Upload complete');
      notifier.resetUpload();

      expect(notifier.state.successMessage, isNull);
    });
  });

  group('UploadNotifier simulateUpload', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
      notifier.updateTrackField(title: 'Test Song', artist: 'Test Artist');
    });

    test('simulateUpload sets isUploading to true immediately', () {
      notifier.simulateUpload();
      expect(notifier.state.isUploading, true);
    });

    test('simulateUpload clears error before starting', () {
      notifier.state = notifier.state.copyWith(error: 'Previous error');
      notifier.simulateUpload();
      expect(notifier.state.error, isNull);
    });

    test('simulateUpload sets uploadProgress to 0.0 initially', () {
      notifier.state = notifier.state.copyWith(uploadProgress: 0.5);
      notifier.simulateUpload();
      expect(notifier.state.uploadProgress, 0.0);
    });
  });

  group('UploadNotifier Complex Operations', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier(_TestDioClient());
    });

    test('multiple updateTrackField calls preserve all fields', () {
      notifier.updateTrackField(title: 'Song Title');
      notifier.updateTrackField(artist: 'Artist Name');
      notifier.updateTrackField(genre: 'Electronic');
      notifier.updateTrackField(tags: ['tag1', 'tag2']);
      notifier.updateTrackField(isPublic: false);

      expect(notifier.state.track.title, 'Song Title');
      expect(notifier.state.track.artist, 'Artist Name');
      expect(notifier.state.track.genre, 'Electronic');
      expect(notifier.state.track.tags, ['tag1', 'tag2']);
      expect(notifier.state.track.isPublic, false);
    });

    test('updateTrack followed by updateTrackField works correctly', () {
      final newTrack = UploadTrack(
        title: 'Initial Song',
        artist: 'Initial Artist',
        genre: 'Rock',
      );

      notifier.updateTrack(newTrack);
      notifier.updateTrackField(genre: 'Jazz');

      expect(notifier.state.track.title, 'Initial Song');
      expect(notifier.state.track.artist, 'Initial Artist');
      expect(notifier.state.track.genre, 'Jazz');
    });
  });

  group('uploadProvider Riverpod Integration', () {
    test('initializes with empty track title', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(uploadProvider);
      expect(state.track.title, '');
    });

    test('initializes with empty track artist', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(uploadProvider);
      expect(state.track.artist, '');
    });

    test('updateTrackField works via container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(uploadProvider.notifier)
          .updateTrackField(title: 'New Title');

      final state = container.read(uploadProvider);
      expect(state.track.title, 'New Title');
    });

    test('resetUpload works via container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(uploadProvider.notifier)
          .updateTrackField(title: 'Test Title', artist: 'Test Artist');

      container.read(uploadProvider.notifier).resetUpload();

      final state = container.read(uploadProvider);
      expect(state.track.title, '');
      expect(state.track.artist, '');
    });

    test('two containers are independent', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();

      addTearDown(container1.dispose);
      addTearDown(container2.dispose);

      container1
          .read(uploadProvider.notifier)
          .updateTrackField(title: 'Title from Container 1');

      container2
          .read(uploadProvider.notifier)
          .updateTrackField(title: 'Title from Container 2');

      final state1 = container1.read(uploadProvider);
      final state2 = container2.read(uploadProvider);

      expect(state1.track.title, 'Title from Container 1');
      expect(state2.track.title, 'Title from Container 2');
    });

    test('simulateUpload works via container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final future = container.read(uploadProvider.notifier).simulateUpload();
      expect(container.read(uploadProvider).isUploading, true);
    });
  });
}
