import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';
import '../../domain/entities/upload_track.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';

class UploadState {
  final UploadTrack track;
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress; // 0.0 to 1.0
  final String? error;
  final String? successMessage;
  final bool waveformLoaded;
  final String? processingState; // "Processing", "Finished", or null

  const UploadState({
    required this.track,
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.successMessage,
    this.waveformLoaded = false,
    this.processingState,
  });

  UploadState copyWith({
    UploadTrack? track,
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    String? successMessage,
    bool? waveformLoaded,
    String? processingState,
  }) {
    return UploadState(
      track: track ?? this.track,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      successMessage: successMessage,
      waveformLoaded: waveformLoaded ?? this.waveformLoaded,
      processingState: processingState,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final DioClient dioClient;

  UploadNotifier(this.dioClient)
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

  // Initialize upload with audio file path
  Future<void> initializeUpload({required String audioFilePath}) async {
    final filename = audioFilePath.split('/').last;
    state = state.copyWith(
      track: UploadTrack(
        audioFilePath: audioFilePath,
        title: filename.replaceAll(RegExp(r'\.[^.]*$'), ''), // Remove extension
        artist: '',
      ),
    );
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

  // Real API upload with Azure blob storage
  Future<void> uploadTrack() async {
    if (state.track.audioFilePath == null) {
      state = state.copyWith(error: 'No audio file selected');
      return;
    }

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      error: null,
      successMessage: null,
      processingState: null,
    );

    try {
      final audioFile = File(state.track.audioFilePath!);
      final audioBytes = await audioFile.readAsBytes();
      final mimeType = _getMimeType(state.track.audioFilePath!);

      // Step A: POST /tracks/upload - Get trackId and uploadUrl
      state = state.copyWith(uploadProgress: 0.1);
      final uploadInitResponse = await dioClient.dio.post(
        '/tracks/upload',
        data: {
          'fileName': path.basename(state.track.audioFilePath!),
          'fileSize': audioBytes.length,
          'mimeType': mimeType,
        },
      );

      final trackId = uploadInitResponse.data['trackId'] as String;
      final uploadUrl = uploadInitResponse.data['uploadUrl'] as String;
      final permalink = uploadInitResponse.data['permalink'] as String?;

      // Step B: PUT file to Azure blob with progress
      state = state.copyWith(uploadProgress: 0.15);
      await dioClient.dio.put(
        uploadUrl,
        data: Stream.fromIterable(
          audioBytes.map((e) => [e]),
        ),
        onSendProgress: (int sent, int total) {
          // Progress from 15% to 85%
          final progress = 0.15 + ((sent / total) * 0.7);
          state = state.copyWith(uploadProgress: progress);
        },
        options: Options(
          contentType: mimeType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Step C: PATCH /tracks/{trackId}/confirm - Trigger FFmpeg processing
      state = state.copyWith(uploadProgress: 0.9);
      await dioClient.dio.patch(
        '/tracks/$trackId/confirm',
        data: {
          'title': state.track.title,
          'artist': state.track.artist,
          'genre': state.track.genre,
          'description': state.track.description,
          'tags': state.track.tags,
          'isPublic': state.track.isPublic,
        },
      );

      // Step D: Poll GET /tracks/{permalink} until processingState="Finished"
      if (permalink != null) {
        await _pollProcessingStatus(permalink);
      }

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        successMessage: 'Upload complete! ✓',
        processingState: 'Finished',
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Upload failed: ${e.toString()}',
        isUploading: false,
        uploadProgress: 0.0,
      );
    }
  }

  // Poll track processing status until completion
  Future<void> _pollProcessingStatus(String permalink) async {
    const int maxAttempts = 60;
    const Duration pollInterval = Duration(seconds: 3);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      try {
        final response = await dioClient.dio.get('/tracks/$permalink');
        final processingState = response.data['processingState'] as String?;

        if (processingState == 'Finished') {
          return;
        }

        // Update state to show server is processing
        state = state.copyWith(processingState: processingState);
      } catch (e) {
        // Continue polling even if individual requests fail
        continue;
      }
    }
  }

  // Get MIME type from file extension
  String _getMimeType(String filepath) {
    final ext = path.extension(filepath).toLowerCase();
    switch (ext) {
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.flac':
        return 'audio/flac';
      case '.ogg':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }

  // Simulate upload progress (pure local simulation - no HTTP calls)
  Future<void> simulateUpload() async {
    state = state.copyWith(isUploading: true, uploadProgress: 0.0, error: null);
    for (int i = 1; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      state = state.copyWith(uploadProgress: i / 20);
    }
    state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        successMessage: 'Track uploaded successfully!');
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
  final dioClient = ref.watch(dioClientProvider);
  return UploadNotifier(dioClient);
});

// Provider for list of uploaded tracks
final uploadedTracksProvider =
    StateNotifierProvider<UploadedTracksNotifier, List<UploadTrack>>((ref) {
  return UploadedTracksNotifier();
});

class UploadedTracksNotifier extends StateNotifier<List<UploadTrack>> {
  UploadedTracksNotifier() : super([]);

  void addTrack(UploadTrack track) {
    state = [...state, track];
  }

  void removeTrack(String audioFilePath) {
    state = state.where((t) => t.audioFilePath != audioFilePath).toList();
  }

  void clearAll() {
    state = [];
  }
}
