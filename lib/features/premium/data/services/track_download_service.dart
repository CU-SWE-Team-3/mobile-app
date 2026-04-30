import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/dio_client.dart';
import '../models/offline_downloaded_track.dart';
import 'offline_downloads_repository.dart';
import '../../presentation/providers/subscription_provider.dart';

sealed class TrackDownloadResult {
  const TrackDownloadResult();
}

class TrackDownloadSuccess extends TrackDownloadResult {
  const TrackDownloadSuccess();
}

// Artist has disabled direct downloads — metadata saved as offline preview.
class TrackDownloadMetadataOnly extends TrackDownloadResult {
  final String blockedReason;
  const TrackDownloadMetadataOnly(this.blockedReason);
}

class TrackDownloadPlanGated extends TrackDownloadResult {
  const TrackDownloadPlanGated();
}

class TrackDownloadError extends TrackDownloadResult {
  final String message;
  const TrackDownloadError(this.message);
}

const _kArtistDisabledMsg =
    'The artist has not enabled direct downloads for this track.';

/// Downloads [trackId] from the backend, saves to local storage, and persists
/// metadata. Returns a typed result — callers handle UI (snackbars, loading
/// state) based on the outcome.
///
/// [onProgress] is called with values in [0, 1] as bytes arrive. Only used by
/// the full player, which shows a progress indicator.
Future<TrackDownloadResult> downloadTrack({
  required WidgetRef ref,
  required String trackId,
  required String title,
  required String artistName,
  String? artworkUrl,
  void Function(double)? onProgress,
}) async {
  var sub = ref.read(subscriptionProvider);
  if (!sub.isPremium || sub.planType != 'Go+') {
    await ref.read(subscriptionProvider.notifier).refreshFromProfile();
    sub = ref.read(subscriptionProvider);
  }
  if (!sub.isPremium || sub.planType != 'Go+') {
    return const TrackDownloadPlanGated();
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/offline_$trackId.mp3';
    final dioClient = ref.read(dioClientProvider);
    await dioClient.dio.download(
      '/tracks/$trackId/download',
      localPath,
      onReceiveProgress: onProgress != null
          ? (received, total) {
              if (total > 0) onProgress(received / total);
            }
          : null,
    );

    final repo = ref.read(offlineDownloadsRepositoryProvider);
    await repo.save(OfflineDownloadedTrack(
      trackId: trackId,
      title: title,
      artistName: artistName,
      artworkUrl: artworkUrl,
      downloadedAt: DateTime.now(),
      localPath: localPath,
      planType: sub.planType,
      downloadMode: 'file',
      fileAvailable: true,
      backendDownloadAllowed: true,
    ));
    ref.invalidate(offlineDownloadsProvider);
    return const TrackDownloadSuccess();
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      return const TrackDownloadError('Please log in again.');
    }
    if (e.response?.statusCode == 403) {
      final data = e.response?.data;
      final backendMsg =
          (data is Map ? data['message'] as String? : null) ?? '';
      if (backendMsg == _kArtistDisabledMsg) {
        // Save metadata-only entry so the track appears in Offline Downloads
        // with a note that the file isn't available.
        final repo = ref.read(offlineDownloadsRepositoryProvider);
        await repo.save(OfflineDownloadedTrack(
          trackId: trackId,
          title: title,
          artistName: artistName,
          artworkUrl: artworkUrl,
          downloadedAt: DateTime.now(),
          localPath: null,
          planType: sub.planType,
          downloadMode: 'metadataOnly',
          fileAvailable: false,
          backendDownloadAllowed: false,
          blockedReason: backendMsg,
        ));
        ref.invalidate(offlineDownloadsProvider);
        return TrackDownloadMetadataOnly(backendMsg);
      }
      final msg = backendMsg.isNotEmpty
          ? backendMsg
          : 'Offline downloads require Go+.';
      return TrackDownloadError(msg);
    }
    return const TrackDownloadError('Download failed. Please try again.');
  } catch (_) {
    return const TrackDownloadError('Download failed. Please try again.');
  }
}
