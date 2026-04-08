import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/upload_track.dart';

class UploadState {
  final UploadTrack track;
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress; // 0.0 to 1.0
  final String? error;
  final String? successMessage;
  final bool waveformLoaded;

  const UploadState({
    required this.track,
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.successMessage,
    this.waveformLoaded = false,
  });

  UploadState copyWith({
    UploadTrack? track,
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    String? successMessage,
    bool? waveformLoaded,
  }) {
    return UploadState(
      track: track ?? this.track,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      successMessage: successMessage,
      waveformLoaded: waveformLoaded ?? this.waveformLoaded,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier()
      : super(
          const UploadState(
            track: UploadTrack(
              title: '',
              artist: '',
            ),
          ),
        );

  // Update track with new values
  void updateTrack(UploadTrack newTrack) {
    state = state.copyWith(track: newTrack);
  }

  // Update specific track field
  void updateTrackField({
    String? audioFilePath,
    String? coverImagePath,
    String? title,
    String? artist,
    String? album,
    String? genre,
    List<String>? tags,
    DateTime? releaseDate,
    bool? isPublic,
    String? description,
    int? duration,
  }) {
    state = state.copyWith(
      track: state.track.copyWith(
        audioFilePath: audioFilePath,
        coverImagePath: coverImagePath,
        title: title,
        artist: artist,
        album: album,
        genre: genre,
        tags: tags,
        releaseDate: releaseDate,
        isPublic: isPublic,
        description: description,
        duration: duration,
      ),
    );
  }

  // Set waveform loaded state
  void setWaveformLoaded(bool loaded) {
    state = state.copyWith(waveformLoaded: loaded);
  }

  // Simulate upload progress
  Future<void> simulateUpload() async {
    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      error: null,
      successMessage: null,
    );

    try {
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        state = state.copyWith(uploadProgress: i / 100);
      }

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        successMessage: 'Track uploaded successfully!',
      );

      // Reset after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      resetUpload();
    } catch (e) {
      state = state.copyWith(
        error: 'Upload failed: ${e.toString()}',
        isUploading: false,
      );
    }
  }

  // Reset upload state
  void resetUpload() {
    state = const UploadState(
      track: UploadTrack(
        title: '',
        artist: '',
      ),
    );
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Clear success message
  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }
}

final uploadProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier();
});
