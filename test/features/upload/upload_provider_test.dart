import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/upload/domain/entities/upload_track.dart';
import 'package:soundcloud_clone/features/upload/presentation/providers/upload_provider.dart';

void main() {
  group('UploadState', () {
    const track = UploadTrack(
      title: 'Test',
      artist: 'Artist',
      tags: [],
    );

    test('initial defaults all correct', () {
      const state = UploadState(track: track);

      expect(state.track, track);
      expect(state.isLoading, false);
      expect(state.isUploading, false);
      expect(state.uploadProgress, 0.0);
      expect(state.error, null);
      expect(state.successMessage, null);
      expect(state.waveformLoaded, false);
    });

    test('copyWith updates isLoading, isUploading, uploadProgress, error, successMessage, waveformLoaded', () {
      const state = UploadState(track: track);

      final newState = state.copyWith(
        isLoading: true,
        isUploading: true,
        uploadProgress: 0.5,
        error: 'error',
        successMessage: 'success',
        waveformLoaded: true,
      );

      expect(newState.isLoading, true);
      expect(newState.isUploading, true);
      expect(newState.uploadProgress, 0.5);
      expect(newState.error, 'error');
      expect(newState.successMessage, 'success');
      expect(newState.waveformLoaded, true);
    });

    test('copyWith clears error when null passed', () {
      const state = UploadState(track: track, error: 'error');

      final newState = state.copyWith(error: null);

      expect(newState.error, null);
    });

    test('copyWith clears successMessage when null passed', () {
      const state = UploadState(track: track, successMessage: 'success');

      final newState = state.copyWith(successMessage: null);

      expect(newState.successMessage, null);
    });
  });

  group('UploadNotifier', () {
    late UploadNotifier notifier;

    setUp(() {
      notifier = UploadNotifier();
    });

    test('initial state has empty title and artist', () {
      expect(notifier.state.track.title, '');
      expect(notifier.state.track.artist, '');
    });

    test('updateTrack sets new track', () {
      const newTrack = UploadTrack(
        title: 'New Track',
        artist: 'New Artist',
        tags: ['tag'],
      );

      notifier.updateTrack(newTrack);

      expect(notifier.state.track.title, 'New Track');
      expect(notifier.state.track.artist, 'New Artist');
      expect(notifier.state.track.tags, ['tag']);
    });

    test('updateTrackField updates title, artist, genre, isPublic, tags, duration', () {
      notifier.updateTrackField(
        title: 'Updated Title',
        artist: 'Updated Artist',
        genre: 'Rock',
        isPublic: false,
        tags: ['tag1', 'tag2'],
        duration: 180000,
      );

      expect(notifier.state.track.title, 'Updated Title');
      expect(notifier.state.track.artist, 'Updated Artist');
      expect(notifier.state.track.genre, 'Rock');
      expect(notifier.state.track.isPublic, false);
      expect(notifier.state.track.tags, ['tag1', 'tag2']);
      expect(notifier.state.track.duration, 180000);
    });

    test('setWaveformLoaded true/false', () {
      notifier.setWaveformLoaded(true);
      expect(notifier.state.waveformLoaded, true);

      notifier.setWaveformLoaded(false);
      expect(notifier.state.waveformLoaded, false);
    });

    test('clearError sets null', () {
      notifier.state = notifier.state.copyWith(error: 'error');
      notifier.clearError();
      expect(notifier.state.error, null);
    });

    test('clearSuccessMessage sets null', () {
      notifier.state = notifier.state.copyWith(successMessage: 'success');
      notifier.clearSuccessMessage();
      expect(notifier.state.successMessage, null);
    });

    test('resetUpload resets everything', () {
      notifier.state = notifier.state.copyWith(
        track: const UploadTrack(title: 'Test', artist: 'Test', tags: []),
        isUploading: true,
        uploadProgress: 0.5,
        error: 'error',
        successMessage: 'success',
        waveformLoaded: true,
      );

      notifier.resetUpload();

      expect(notifier.state.track.title, '');
      expect(notifier.state.track.artist, '');
      expect(notifier.state.isUploading, false);
      expect(notifier.state.uploadProgress, 0.0);
      expect(notifier.state.error, null);
      expect(notifier.state.successMessage, null);
      expect(notifier.state.waveformLoaded, false);
    });

    test('multiple updateTrackField calls preserve all fields', () {
      notifier.updateTrackField(title: 'Title 1', artist: 'Artist 1');
      notifier.updateTrackField(genre: 'Rock', tags: ['rock']);
      notifier.updateTrackField(duration: 200000, isPublic: false);

      expect(notifier.state.track.title, 'Title 1');
      expect(notifier.state.track.artist, 'Artist 1');
      expect(notifier.state.track.genre, 'Rock');
      expect(notifier.state.track.tags, ['rock']);
      expect(notifier.state.track.duration, 200000);
      expect(notifier.state.track.isPublic, false);
    });
  });

  group('uploadProvider', () {
    test('initializes with empty track', () {
      final container = ProviderContainer();
      final state = container.read(uploadProvider);

      expect(state.track.title, '');
      expect(state.track.artist, '');
    });

    test('updateTrackField works via container', () {
      final container = ProviderContainer();

      container.read(uploadProvider.notifier).updateTrackField(
        title: 'Container Title',
        artist: 'Container Artist',
      );

      final state = container.read(uploadProvider);
      expect(state.track.title, 'Container Title');
      expect(state.track.artist, 'Container Artist');
    });

    test('resetUpload works via container', () {
      final container = ProviderContainer();

      container.read(uploadProvider.notifier).updateTrackField(title: 'Test');
      container.read(uploadProvider.notifier).resetUpload();

      final state = container.read(uploadProvider);
      expect(state.track.title, '');
    });

    test('two containers are independent', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();

      container1.read(uploadProvider.notifier).updateTrackField(title: 'Title 1');
      container2.read(uploadProvider.notifier).updateTrackField(title: 'Title 2');

      expect(container1.read(uploadProvider).track.title, 'Title 1');
      expect(container2.read(uploadProvider).track.title, 'Title 2');
    });
  });
}