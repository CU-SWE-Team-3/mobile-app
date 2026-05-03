import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/library/domain/entities/upload_track.dart';
import 'package:soundcloud_clone/features/library/presentation/providers/upload_provider.dart';

/// Tests that cover the pure-logic portions of [UploadState] and the
/// synchronous helpers on [UploadNotifier] (no HTTP / DioClient calls).
void main() {
  // ── UploadState ───────────────────────────────────────────────────────────

  group('UploadState', () {
    const emptyTrack = UploadTrack(title: '', artist: '');

    group('default values', () {
      test('initial state has correct defaults', () {
        const state = UploadState(track: emptyTrack);

        expect(state.isLoading, isFalse);
        expect(state.isUploading, isFalse);
        expect(state.uploadProgress, 0.0);
        expect(state.error, isNull);
        expect(state.successMessage, isNull);
        expect(state.waveformLoaded, isFalse);
        expect(state.processingState, isNull);
        expect(state.needsRoleUpgrade, isFalse);
      });
    });

    group('copyWith', () {
      test('updating isUploading preserves other fields', () {
        const state = UploadState(track: emptyTrack, uploadProgress: 0.5);
        final updated = state.copyWith(isUploading: true);

        expect(updated.isUploading, isTrue);
        expect(updated.uploadProgress, 0.5); // preserved
        expect(updated.track, emptyTrack);   // preserved
      });

      test('updating uploadProgress is reflected correctly', () {
        const state = UploadState(track: emptyTrack);
        final updated = state.copyWith(uploadProgress: 0.75);
        expect(updated.uploadProgress, closeTo(0.75, 1e-9));
      });

      test('uploading progress can reach 1.0', () {
        const state = UploadState(track: emptyTrack);
        final done = state.copyWith(uploadProgress: 1.0);
        expect(done.uploadProgress, 1.0);
      });

      test('error can be set and cleared via copyWith', () {
        const state = UploadState(track: emptyTrack);
        final withError = state.copyWith(error: 'Upload failed');
        expect(withError.error, 'Upload failed');

        // Passing null clears the error (nullable override semantics)
        final cleared = withError.copyWith(error: null);
        expect(cleared.error, isNull);
      });

      test('successMessage can be set and cleared', () {
        const state = UploadState(track: emptyTrack);
        final success = state.copyWith(successMessage: 'Upload complete!');
        expect(success.successMessage, 'Upload complete!');

        final cleared = success.copyWith(successMessage: null);
        expect(cleared.successMessage, isNull);
      });

      test('processingState can cycle through Processing → Finished → null', () {
        const state = UploadState(track: emptyTrack);

        final processing = state.copyWith(processingState: 'Processing');
        expect(processing.processingState, 'Processing');

        final finished = processing.copyWith(processingState: 'Finished');
        expect(finished.processingState, 'Finished');

        final reset = finished.copyWith(processingState: null);
        expect(reset.processingState, isNull);
      });

      test('waveformLoaded flag toggles correctly', () {
        const state = UploadState(track: emptyTrack);
        expect(state.waveformLoaded, isFalse);

        final loaded = state.copyWith(waveformLoaded: true);
        expect(loaded.waveformLoaded, isTrue);
      });

      test('needsRoleUpgrade flag toggles correctly', () {
        const state = UploadState(track: emptyTrack);
        expect(state.needsRoleUpgrade, isFalse);

        final upgrade = state.copyWith(needsRoleUpgrade: true);
        expect(upgrade.needsRoleUpgrade, isTrue);
      });

      test('track can be replaced via copyWith', () {
        const state = UploadState(track: emptyTrack);
        const newTrack = UploadTrack(title: 'New Song', artist: 'New Artist');
        final updated = state.copyWith(track: newTrack);
        expect(updated.track.title, 'New Song');
        expect(updated.track.artist, 'New Artist');
      });

      test('null track in copyWith keeps existing track', () {
        const track = UploadTrack(title: 'Keep Me', artist: 'A');
        const state = UploadState(track: track);
        final updated = state.copyWith(isLoading: true);
        expect(updated.track, track);
      });
    });

    group('upload progress semantics', () {
      test('progress 0.0 represents not started', () {
        const state = UploadState(track: emptyTrack, uploadProgress: 0.0);
        expect(state.uploadProgress, 0.0);
      });

      test('progress 0.10 represents Azure upload step A completed', () {
        const state = UploadState(track: emptyTrack, uploadProgress: 0.10);
        expect(state.uploadProgress, closeTo(0.10, 1e-9));
      });

      test('progress 0.80 represents confirm step', () {
        const state = UploadState(track: emptyTrack, uploadProgress: 0.80);
        expect(state.uploadProgress, closeTo(0.80, 1e-9));
      });
    });
  });

  // ── UploadedTracksNotifier ─────────────────────────────────────────────────

  group('UploadedTracksNotifier', () {
    late UploadedTracksNotifier notifier;

    setUp(() {
      notifier = UploadedTracksNotifier();
    });

    test('starts with empty list', () {
      expect(notifier.state, isEmpty);
    });

    test('addTrack appends to the list', () {
      const track = UploadTrack(title: 'Song A', artist: 'A');
      notifier.addTrack(track);
      expect(notifier.state, hasLength(1));
      expect(notifier.state.first.title, 'Song A');
    });

    test('addTrack can add multiple tracks', () {
      const t1 = UploadTrack(title: 'T1', artist: 'A', audioFilePath: '/a.mp3');
      const t2 = UploadTrack(title: 'T2', artist: 'B', audioFilePath: '/b.mp3');
      notifier.addTrack(t1);
      notifier.addTrack(t2);
      expect(notifier.state, hasLength(2));
    });

    test('removeTrack removes by audioFilePath', () {
      const t1 = UploadTrack(title: 'T1', artist: 'A', audioFilePath: '/a.mp3');
      const t2 = UploadTrack(title: 'T2', artist: 'B', audioFilePath: '/b.mp3');
      notifier.addTrack(t1);
      notifier.addTrack(t2);

      notifier.removeTrack('/a.mp3');
      expect(notifier.state, hasLength(1));
      expect(notifier.state.first.title, 'T2');
    });

    test('removeTrack with non-existent path is a no-op', () {
      const t1 = UploadTrack(title: 'T1', artist: 'A', audioFilePath: '/a.mp3');
      notifier.addTrack(t1);
      notifier.removeTrack('/does-not-exist.mp3');
      expect(notifier.state, hasLength(1));
    });

    test('clearAll empties the list', () {
      notifier.addTrack(const UploadTrack(title: 'T', artist: 'A'));
      notifier.addTrack(const UploadTrack(title: 'T2', artist: 'B'));
      notifier.clearAll();
      expect(notifier.state, isEmpty);
    });

    test('clearAll on already-empty list is safe', () {
      expect(() => notifier.clearAll(), returnsNormally);
      expect(notifier.state, isEmpty);
    });
  });
}
