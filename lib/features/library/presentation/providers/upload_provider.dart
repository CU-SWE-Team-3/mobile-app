import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/upload_track.dart';
import '../../../premium/presentation/providers/subscription_provider.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/core/providers/session_provider.dart';

class UploadState {
  final UploadTrack track;
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress; // 0.0 to 1.0
  final String? error;
  final String? successMessage;
  final bool waveformLoaded;
  final String? processingState; // "Processing", "Finished", or null
  final bool needsRoleUpgrade;

  const UploadState({
    required this.track,
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.successMessage,
    this.waveformLoaded = false,
    this.processingState,
    this.needsRoleUpgrade = false,
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
    bool? needsRoleUpgrade,
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
      needsRoleUpgrade: needsRoleUpgrade ?? this.needsRoleUpgrade,
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
    final stablePath = await _copyAudioToStableUploadLocation(audioFilePath);
    final filename = path.basename(stablePath);
    state = state.copyWith(
      track: UploadTrack(
        audioFilePath: stablePath,
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
      needsRoleUpgrade: false,
    );

    // Pre-check: enforce upload limits for Free / Go+ (max 3 tracks). If plan is Pro, allow.
    try {
      final prefs = await SharedPreferences.getInstance();
      final permalink = prefs.getString('permalink') ?? '';
      if (permalink.isNotEmpty) {
        final profileResp = await dioClient.dio.get('/profile/$permalink');
        final user = profileResp.data['data']?['user'] as Map<String, dynamic>?;
        final isPremium = (user?['isPremium'] as bool?) ??
            prefs.getBool('isPremium') ??
            false;
        final subscription = _asStringMap(user?['subscription']);
        final planType = _readPlanType(
              user: user,
              subscription: subscription,
            ) ??
            normalizeSubscriptionPlan(prefs.getString('subscriptionPlanType'));
        final offlineListening = _readBoolEntitlement(
              user: user,
              subscription: subscription,
              keys: const [
                'offlineListening',
                'canDownload',
                'downloadsEnabled',
              ],
            ) ||
            (prefs.getBool('subscriptionOfflineListening') ?? false);
        final role =
            ((user?['role'] as String?) ?? prefs.getString('role') ?? '')
                .toLowerCase();
        final legacyArtistPro =
            isPremium && planType == null && role == 'artist';
        final hasUnlimitedUploads = isPremium &&
            (planType == 'Pro' || planType == 'Artist Pro' || legacyArtistPro);
        final canDownload = planType == 'Go+' || offlineListening;
        debugPrint(
          '[Upload] entitlement â€” isPremium=$isPremium, '
          'planType=${planType ?? "null"}, '
          'canUploadUnlimited=$hasUnlimitedUploads, '
          'canDownload=$canDownload, '
          'role=$role, legacyArtistPro=$legacyArtistPro',
        );
        if (!hasUnlimitedUploads) {
          int? tracksCount;
          tracksCount = (user?['counts']?['tracks'] as int?) ??
              (user?['tracksCount'] as int?) ??
              (user?['trackCount'] as int?);
          tracksCount ??= (user?['tracks'] as List?)?.length;
          if (tracksCount != null && tracksCount >= 3) {
            state = state.copyWith(
              isUploading: false,
              error:
                  'Upload limit reached. Free and Go+ accounts are limited to 3 tracks. Upgrade to Artist Pro for unlimited uploads.',
            );
            return;
          }
        }
      }
    } catch (_) {
      // tolerate failures here — let the backend enforce limits if we cannot determine count
    }

    try {
      final audioFile = File(state.track.audioFilePath!);
      final audioBytes = await audioFile.readAsBytes();
      final mimeType = _getMimeType(state.track.audioFilePath!);

      // Step A: POST /tracks/upload - Get trackId and uploadUrl
      //
      // Resolve duration in whole seconds (API requirement).
      // UploadTrack.duration stores milliseconds but is never populated by the
      // file picker, so it is almost always null — sending 0 causes a 400.
      // Probe the file with just_audio; fall back to a size-based estimate if
      // probing fails so we always send a non-zero positive integer.
      state = state.copyWith(uploadProgress: 0.1);

      int durationSeconds = 0;
      if (state.track.duration != null && state.track.duration! > 0) {
        // Already set in milliseconds — convert to seconds
        durationSeconds = (state.track.duration! / 1000).round();
      } else {
        // Probe the file with just_audio to get the real duration
        final probe = ja.AudioPlayer();
        try {
          await probe.setFilePath(state.track.audioFilePath!);
          final probed = probe.duration;
          if (probed != null && probed.inSeconds > 0) {
            durationSeconds = probed.inSeconds;
          }
        } catch (_) {
          // Probing failed — estimate from file size.
          // 128 kbps MP3 ≈ 16 000 bytes/s; clamp to [1, 7200].
          durationSeconds = (audioBytes.length / 16000).round().clamp(1, 7200);
        } finally {
          await probe.dispose();
        }
      }

      // Ensure we never send 0 even after all attempts
      if (durationSeconds <= 0) {
        durationSeconds = (audioBytes.length / 16000).round().clamp(1, 7200);
      }

      final normalizedGenre = _normalizeGenre(state.track.genre);
      debugPrint(
          '[Upload] selectedGenre=${state.track.genre ?? "null"} → normalized=${normalizedGenre ?? "null"}');
      final uploadInitBody = <String, dynamic>{
        'title': state.track.title.isNotEmpty ? state.track.title : 'Untitled',
        'format': mimeType,
        'size': audioBytes.length,
        'duration': durationSeconds,
        'isPublic': state.track.isPublic,
      };
      if ((state.track.description ?? '').trim().isNotEmpty) {
        uploadInitBody['description'] = state.track.description!.trim();
      }
      if (normalizedGenre != null) {
        uploadInitBody['genre'] = normalizedGenre;
      }
      if (state.track.tags.isNotEmpty) {
        uploadInitBody['tags'] = state.track.tags;
      }
      if (state.track.releaseDate != null) {
        uploadInitBody['releaseDate'] =
            state.track.releaseDate!.toIso8601String();
      }

      debugPrint('[Upload] metadata sent=$uploadInitBody');
      final uploadInitResponse = await dioClient.dio.post(
        '/tracks/upload',
        data: uploadInitBody,
      );

      final trackId = uploadInitResponse.data['data']['trackId'] as String;
      final uploadUrl = uploadInitResponse.data['data']['uploadUrl'] as String;
      final responseGenre = uploadInitResponse.data['data']?['genre'] ??
          uploadInitResponse.data['data']?['track']?['genre'];
      debugPrint('[Upload] backend response genre=${responseGenre ?? "null"}');

      // Step B: PUT file to Azure Blob Storage with progress.
      //
      // IMPORTANT: must NOT use dioClient.dio here.
      // The shared client has:
      //   - Authorization: Bearer ... in dio.options.headers (global default)
      //   - CookieManager interceptor (adds Cookie headers)
      //   - A 403 error interceptor that re-injects the Bearer token and retries
      // Azure SAS URLs authenticate via the URL itself and reject any
      // unexpected headers (Authorization, Cookie, etc.) with 403.
      // A bare Dio() instance is the only safe option — no interceptors,
      // no default headers, no base URL.
      state = state.copyWith(uploadProgress: 0.10);
      final azureDio = Dio();
      final azureResponse = await azureDio.put(
        uploadUrl,
        data: Stream.fromIterable(audioBytes.map((b) => [b])),
        onSendProgress: (int sent, int total) {
          final progress = 0.10 + ((sent / total) * 0.65);
          state = state.copyWith(uploadProgress: progress);
        },
        options: Options(
          headers: {
            'Content-Type': mimeType,
            'Content-Length': audioBytes.length,
            'x-ms-blob-type': 'BlockBlob',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (azureResponse.statusCode == null ||
          azureResponse.statusCode! >= 300) {
        throw Exception(
          'Azure upload rejected (HTTP ${azureResponse.statusCode}). '
          'Ensure Content-Type matches the format declared during initiation.',
        );
      }

      // Step C: PATCH /tracks/{trackId}/confirm — no body, pure signal
      state = state.copyWith(uploadProgress: 0.80);
      final confirmResponse = await dioClient.dio.patch(
        '/tracks/$trackId/confirm',
      );

      final permalink = confirmResponse.data['data']['permalink'] as String?;

      // Step D: PATCH /tracks/{trackId}/metadata — non-null fields only
      state = state.copyWith(uploadProgress: 0.85);
      final metadataBody = <String, dynamic>{};
      if (state.track.title.isNotEmpty) {
        metadataBody['title'] = state.track.title;
      }
      if ((state.track.description ?? '').trim().isNotEmpty) {
        metadataBody['description'] = state.track.description!.trim();
      }
      if (normalizedGenre != null) metadataBody['genre'] = normalizedGenre;
      if (state.track.tags.isNotEmpty) {
        metadataBody['tags'] = state.track.tags;
      }
      metadataBody['isPublic'] = state.track.isPublic;
      if (state.track.releaseDate != null) {
        metadataBody['releaseDate'] =
            state.track.releaseDate!.toIso8601String();
      }
      if (metadataBody.isNotEmpty) {
        await dioClient.dio
            .patch('/tracks/$trackId/metadata', data: metadataBody);
      }

      // Step E: PATCH /tracks/{trackId}/artwork — multipart, only if cover selected
      state = state.copyWith(uploadProgress: 0.90);
      if (state.track.coverImagePath != null) {
        final artworkFormData = FormData.fromMap({
          'artwork': await MultipartFile.fromFile(state.track.coverImagePath!),
        });
        await dioClient.dio.patch(
          '/tracks/$trackId/artwork',
          data: artworkFormData,
        );
      }

      // Step F: Poll GET /tracks/{permalink} until processingState = "Finished"
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
      final message = _uploadErrorMessage(e);
      state = state.copyWith(
        error: message,
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
        final processingState =
            response.data['data']['track']['processingState'] as String?;

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
    final name = filepath.split(RegExp(r'[\\/]')).last;
    final dotIndex = name.lastIndexOf('.');
    final ext = dotIndex >= 0 ? name.substring(dotIndex).toLowerCase() : '';
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

  String? _normalizeGenre(String? genre) {
    if (genre == null) return null;
    switch (genre.trim()) {
      case 'All Music Genres':
        return 'All music genres';
      case 'Deep House':
        return 'Deep house';
      case 'Hip-hop & Rap':
        return 'Hiphop & rap';
      case 'Jazz & Blues':
        return 'Jazz & blues';
      case 'R&B & Soul':
        return 'R&B & soul';
      default:
        return genre.trim();
    }
  }

  Future<String> _copyAudioToStableUploadLocation(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      if (sourcePath.contains('file_picker') || sourcePath.contains('cache')) {
        throw FileSystemException(
          'Selected audio file no longer exists',
          sourcePath,
        );
      }
      return sourcePath;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final uploadDir = Directory(path.join(docsDir.path, 'pending_uploads'));
    if (!await uploadDir.exists()) {
      await uploadDir.create(recursive: true);
    }

    final normalizedUploadDir = path.normalize(uploadDir.path);
    final normalizedSource = path.normalize(source.path);
    if (path.isWithin(normalizedUploadDir, normalizedSource)) {
      return normalizedSource;
    }

    final extension = path.extension(source.path);
    final baseName = path.basenameWithoutExtension(source.path);
    final safeBaseName = baseName
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]+'), '_')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final copiedPath = path.join(
      uploadDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_${safeBaseName.isEmpty ? 'audio' : safeBaseName}$extension',
    );
    await source.copy(copiedPath);
    return copiedPath;
  }

  String _uploadErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final backendMessage = _bodyMessage(data);
      if (backendMessage.isNotEmpty) {
        return 'Upload failed: $backendMessage';
      }
      final status = error.response?.statusCode;
      if (status == 403) {
        return 'Upload failed: Backend rejected this upload. Please verify your account can upload tracks.';
      }
    }
    if (error is FileSystemException) {
      return 'Upload failed: ${error.message}';
    }
    return 'Upload failed: ${error.toString()}';
  }

  String _bodyMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['msg'];
      return message is String ? message : '';
    }
    return '';
  }

  bool _readBoolEntitlement({
    required Map<String, dynamic>? user,
    required Map<String, dynamic>? subscription,
    required List<String> keys,
  }) {
    final sources = <Map<String, dynamic>?>[
      subscription,
      _asStringMap(subscription?['entitlements']),
      user,
      _asStringMap(user?['entitlements']),
    ];
    for (final source in sources) {
      if (source == null) continue;
      for (final key in keys) {
        final value = source[key];
        if (value is bool) return value;
      }
    }
    return false;
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _readPlanType({
    required Map<String, dynamic>? user,
    required Map<String, dynamic>? subscription,
  }) {
    final rawSubscriptionPlan = user?['subscription'] is Map
        ? null
        : normalizeSubscriptionPlan(user?['subscription']);
    if (rawSubscriptionPlan != null) return rawSubscriptionPlan;

    final sources = <Map<String, dynamic>?>[
      subscription,
      _asStringMap(subscription?['plan']),
      user,
      _asStringMap(user?['subscription']),
    ];
    const keys = [
      'planType',
      'subscriptionPlan',
      'subscription_plan',
      'plan',
    ];
    for (final source in sources) {
      if (source == null) continue;
      for (final key in keys) {
        final normalized = normalizeSubscriptionPlan(source[key]);
        if (normalized != null) return normalized;
      }
    }
    return null;
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

  // Upgrade the current user's account to Artist role via PATCH /profile/tier.
  // Only called by explicit user action (upgrade button).
  Future<void> upgradeToArtist() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await dioClient.dio.patch('/profile/tier', data: {'tier': 'artist'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', 'artist');
      state = state.copyWith(
        isLoading: false,
        needsRoleUpgrade: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to upgrade role: ${e.toString()}',
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

  // Clear upload status fields only — preserves track data (file path, title, etc.)
  void clearUploadStatus() {
    state = state.copyWith(
      isUploading: false,
      uploadProgress: 0.0,
      processingState: null,
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
  ref.watch(sessionUserIdProvider);
  final dioClient = ref.watch(dioClientProvider);
  return UploadNotifier(dioClient);
});

// Provider for list of uploaded tracks
final uploadedTracksProvider =
    StateNotifierProvider<UploadedTracksNotifier, List<UploadTrack>>((ref) {
  ref.watch(sessionUserIdProvider);
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
