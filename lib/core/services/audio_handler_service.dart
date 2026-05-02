import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';

import '../../features/player/domain/entities/player_track.dart';

AppAudioHandler? appAudioHandler;

const String toggleLikeActionName = 'toggle_like';
const String _storageBaseUrl =
    'https://biobeatsstorage2026.blob.core.windows.net/biobeats-audio';

Future<AppAudioHandler> initAudioHandler() async {
  final existing = appAudioHandler;
  if (existing != null) return existing;

  final handler = await AudioService.init(
    builder: AppAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'biobeats_media_playback',
      androidNotificationChannelName: 'BioBeats playback',
      androidNotificationOngoing: false,
      androidShowNotificationBadge: true,
    ),
  );
  appAudioHandler = handler;
  return handler;
}

class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  final ja.AudioPlayer _player = ja.AudioPlayer();
  bool _isLiked = false;
  Future<void> Function()? onSkipNextRequested;
  Future<void> Function()? onSkipPreviousRequested;
  Future<void> Function()? onLikeRequested;

  AppAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.durationStream.listen(_updateMediaItemDuration);
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> loadTrack(PlayerTrack track, String streamUrl) async {
    _isLiked = false;
    final artworkUri = await _resolveArtworkUri(track.coverUrl);
    debugPrint(
      '[AudioHandler] loadTrack id=${track.id} title="${track.title}" artwork=$artworkUri',
    );
    mediaItem.add(_toMediaItem(track, artworkUri: artworkUri));
    if (streamUrl.startsWith('http://') || streamUrl.startsWith('https://')) {
      await _player.setUrl(streamUrl);
    } else {
      await _player.setFilePath(streamUrl);
    }
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  void setLiked(bool liked) {
    if (_isLiked == liked) return;
    _isLiked = liked;
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> play() {
    debugPrint('[AudioHandler] play pressed');
    return _player.play();
  }

  @override
  Future<void> pause() {
    debugPrint('[AudioHandler] pause pressed');
    return _player.pause();
  }

  @override
  Future<void> seek(Duration position) {
    debugPrint('[AudioHandler] seek to ${position.inMilliseconds}ms');
    return _player.seek(position);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('[AudioHandler] skipToNext pressed');
    final callback = onSkipNextRequested;
    if (callback != null) await callback();
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('[AudioHandler] skipToPrevious pressed');
    final callback = onSkipPreviousRequested;
    if (callback != null) await callback();
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == toggleLikeActionName) {
      debugPrint('[AudioHandler] like pressed');
      final callback = onLikeRequested;
      if (callback != null) await callback();
      return null;
    }
    return super.customAction(name, extras);
  }

  void _broadcastState(ja.PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          _likeControl,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _processingState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0,
      ),
    );
  }

  MediaControl get _likeControl => MediaControl.custom(
        androidIcon: _isLiked
            ? 'drawable/ic_notification_heart_filled'
            : 'drawable/ic_notification_heart',
        label: _isLiked ? 'Unlike' : 'Like',
        name: toggleLikeActionName,
      );

  void _updateMediaItemDuration(Duration? duration) {
    final item = mediaItem.value;
    if (item == null || duration == null || item.duration == duration) return;
    mediaItem.add(item.copyWith(duration: duration));
  }

  AudioProcessingState get _processingState {
    switch (_player.processingState) {
      case ja.ProcessingState.idle:
        return AudioProcessingState.idle;
      case ja.ProcessingState.loading:
        return AudioProcessingState.loading;
      case ja.ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ja.ProcessingState.ready:
        return AudioProcessingState.ready;
      case ja.ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  MediaItem _toMediaItem(PlayerTrack track, {Uri? artworkUri}) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      artUri: artworkUri,
      duration: track.duration,
      extras: {'audioUrl': track.audioUrl},
    );
  }

  Future<Uri?> _resolveArtworkUri(String? rawUrl) async {
    final url = _normaliseArtworkUrl(rawUrl);
    if (url == null) return null;

    try {
      final cacheDir = await getTemporaryDirectory();
      final extension =
          Uri.parse(url).path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final file = File(
        '${cacheDir.path}${Platform.pathSeparator}biobeats_art_${url.hashCode}.$extension',
      );
      if (!await file.exists() || await file.length() == 0) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint(
            '[AudioHandler] artwork download failed ${response.statusCode}: $url',
          );
          client.close(force: true);
          return Uri.parse(url);
        }
        await response.pipe(file.openWrite());
        client.close(force: true);
      }
      return file.uri;
    } catch (e) {
      debugPrint('[AudioHandler] artwork cache failed: $e');
      return Uri.parse(url);
    }
  }

  String? _normaliseArtworkUrl(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '$_storageBaseUrl$value';
    return '$_storageBaseUrl/$value';
  }
}
