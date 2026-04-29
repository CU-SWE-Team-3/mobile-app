import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

const _kArtistDisabledPhrase = 'has not enabled direct downloads';

/// Shared download handler — called by all download entry points.
///
/// Per API v1.10: only Go+ subscribers may call GET /tracks/{id}/download.
/// All other plans (Free, Pro/Artist Pro) are gated before any backend call.
///
/// [onProgress] is called with values in [0, 1] as bytes arrive.
Future<TrackDownloadResult> downloadTrack({
  required WidgetRef ref,
  required String trackId,
  required String title,
  required String artistName,
  String? artworkUrl,
  String? audioUrl,
  String? genre,
  int? duration,
  String? permalink,
  String source = 'unknown',
  void Function(double)? onProgress,
}) async {
  var sub = ref.read(subscriptionProvider);

  debugPrint(
    '[Download] tapped source=$source, trackId=$trackId, '
    'isPremium=${sub.isPremium}, planType=${sub.planType ?? "null"}, '
    'canUploadUnlimited=${sub.canUploadUnlimited}, '
    'canDownload=${sub.canDownload}',
  );

  if (!sub.canDownload || (sub.planType != 'Go+' && sub.offlineListening)) {
    await ref.read(subscriptionProvider.notifier).refreshFromProfile();
    sub = ref.read(subscriptionProvider);
    debugPrint(
      '[Download] after refresh — isPremium=${sub.isPremium}, '
      'planType=${sub.planType ?? "null"}, '
      'canUploadUnlimited=${sub.canUploadUnlimited}, '
      'canDownload=${sub.canDownload}',
    );
  }

  if (!sub.canDownload) {
    debugPrint(
      '[Download] plan-gated — isPremium=${sub.isPremium}, '
      'planType=${sub.planType ?? "null"}, '
      'canUploadUnlimited=${sub.canUploadUnlimited}, '
      'canDownload=${sub.canDownload} (Go+ required)',
    );
    return const TrackDownloadPlanGated();
  }

  debugPrint(
    '[Download] entitlement OK — planType=${sub.planType}, canDownload=true',
  );

  try {
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/offline_$trackId.mp3';
    final dioClient = ref.read(dioClientProvider);
    debugPrint('[Download] calling GET /tracks/$trackId/download');

    await dioClient.dio.download(
      '/tracks/$trackId/download',
      localPath,
      onReceiveProgress: onProgress != null
          ? (received, total) {
              if (total > 0) onProgress(received / total);
            }
          : null,
    );

    debugPrint('[Download] status=200 — saving metadata, mode=file');

    final repo = ref.read(offlineDownloadsRepositoryProvider);
    await repo.save(OfflineDownloadedTrack(
      trackId: trackId,
      title: title,
      artistName: artistName,
      artworkUrl: artworkUrl,
      audioUrl: audioUrl,
      downloadedAt: DateTime.now(),
      localPath: localPath,
      planType: sub.planType,
      genre: genre,
      duration: duration,
      downloadMode: 'file',
      fileAvailable: true,
      backendDownloadAllowed: true,
    ));
    ref.invalidate(offlineDownloadsProvider);
    return const TrackDownloadSuccess();
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final backendMsg =
        (data is Map ? data['message'] as String? : null) ?? '';
    debugPrint(
      '[Download] failed — status=$status, message="$backendMsg"',
    );

    if (status == 401) {
      return const TrackDownloadError('Please log in again.');
    }

    if (status == 403) {
      // Artist disabled direct downloads: save metadata-only preview so the
      // track appears in Offline Downloads with a "Preview saved" badge.
      if (backendMsg.contains(_kArtistDisabledPhrase)) {
        final repo = ref.read(offlineDownloadsRepositoryProvider);
        await repo.save(OfflineDownloadedTrack(
          trackId: trackId,
          title: title,
          artistName: artistName,
          artworkUrl: artworkUrl,
          audioUrl: audioUrl,
          downloadedAt: DateTime.now(),
          localPath: null,
          planType: sub.planType,
          genre: genre,
          duration: duration,
          downloadMode: 'metadataOnly',
          fileAvailable: false,
          backendDownloadAllowed: false,
          blockedReason: backendMsg,
        ));
        ref.invalidate(offlineDownloadsProvider);
        debugPrint(
          '[Download] status=403 artist-disabled — saved metadataOnly',
        );
        return TrackDownloadMetadataOnly(backendMsg);
      }

      // Any other 403 means plan-gated (shouldn't happen if client gate is
      // correct, but guard it anyway).
      debugPrint('[Download] status=403 plan-gated from backend');
      return const TrackDownloadPlanGated();
    }

    return const TrackDownloadError('Download failed. Please try again.');
  } catch (_) {
    return const TrackDownloadError('Download failed. Please try again.');
  }
}
