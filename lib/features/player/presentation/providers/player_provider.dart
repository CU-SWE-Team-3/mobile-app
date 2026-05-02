import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/audio_handler_service.dart';
import '../../../engagement/data/sources/engagement_remote_data_source.dart';
import '../../../engagement/presentation/providers/engagement_provider.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../data/services/player_api_service.dart';

export '../../../player/domain/entities/player_track.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class PlayerState {
  final PlayerTrack? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<PlayerTrack> queue;
  final int currentQueueIndex;
  final List<PlayerTrack> history;
  final bool isLoading;
  final String? error;
  final double volume;
  final bool isCurrentTrackLiked;
  final bool isTogglingLike;
  // PUT /player/state context fields (API: queueContext enum + contextId ObjectId).
  final String queueContext;
  final String? contextId;

  const PlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentQueueIndex = 0,
    this.history = const [],
    this.isLoading = false,
    this.error,
    this.volume = 0.7,
    this.isCurrentTrackLiked = false,
    this.isTogglingLike = false,
    this.queueContext = 'none',
    this.contextId,
  });

  // Backward-compat getters used by existing UI
  String? get currentTrackPath => currentTrack?.audioUrl;
  String? get currentTrackTitle => currentTrack?.title;
  String? get currentTrackArtist => currentTrack?.artist;
  String? get currentTrackArtworkUrl => currentTrack?.coverUrl;

  PlayerState copyWith({
    PlayerTrack? currentTrack,
    bool clearCurrentTrack = false,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<PlayerTrack>? queue,
    int? currentQueueIndex,
    List<PlayerTrack>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
    double? volume,
    bool? isCurrentTrackLiked,
    bool? isTogglingLike,
    String? queueContext,
    String? contextId,
    bool clearContextId = false,
  }) {
    return PlayerState(
      currentTrack:
          clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentQueueIndex: currentQueueIndex ?? this.currentQueueIndex,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      volume: volume ?? this.volume,
      isCurrentTrackLiked: isCurrentTrackLiked ?? this.isCurrentTrackLiked,
      isTogglingLike: isTogglingLike ?? this.isTogglingLike,
      queueContext: queueContext ?? this.queueContext,
      contextId: clearContextId ? null : (contextId ?? this.contextId),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  final AppAudioHandler _audioHandler;
  final PlayerApiService _api;
  double _lastAudibleVolume = 0.7;
  

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<PlaybackState> _playbackStateSub;

  /// Fires PUT /player/state every 5 seconds while a track is playing.
  Timer? _heartbeatTimer;
  Timer? _seekSyncTimer;

  PlayerNotifier(this._ref, this._api, this._audioHandler)
      : super(const PlayerState()) {
    _audioHandler.onSkipNextRequested = skipToNext;
    _audioHandler.onSkipPreviousRequested = skipToPrevious;
    _audioHandler.onLikeRequested = toggleCurrentTrackLike;

    _positionSub = _audioHandler.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durationSub = _audioHandler.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    _playbackStateSub = _audioHandler.playbackState.listen((playbackState) {
      final loading =
          playbackState.processingState == AudioProcessingState.loading ||
              playbackState.processingState == AudioProcessingState.buffering;

      state = state.copyWith(
        isPlaying: playbackState.playing,
        isLoading: loading,
      );

      if (playbackState.processingState == AudioProcessingState.completed) {
        _onTrackCompleted();
      }
    });

    _startHeartbeat();
  }

  // -------------------------------------------------------------------------
  // Heartbeat
  // -------------------------------------------------------------------------

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final track = state.currentTrack;
      if (track != null && state.isPlaying) {
        _api.syncPlayerState(
          trackId: track.id,
          position: state.position.inSeconds.toDouble(),
          isPlaying: state.isPlaying,
          queueContext: state.queueContext,
          contextId: state.contextId,
        );
      }
    });
  }

  /// Records the playback context so the heartbeat can include it in
  /// PUT /player/state.  Call immediately after playQueue / playTrack.
  void setQueueContext(String context, {String? contextId}) {
    state = state.copyWith(queueContext: context, contextId: contextId);
  }

  // -------------------------------------------------------------------------
  // Core play method — all others delegate here
  // -------------------------------------------------------------------------

  Future<void> playTrack(PlayerTrack track) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      // Report progress for the outgoing track before switching.
      final outgoing = state.currentTrack;
      if (outgoing != null) {
        _api.reportProgress(
          trackId: outgoing.id,
          listenedSeconds: state.position.inSeconds,
          totalSeconds: state.duration.inSeconds,
        );
        // Push current track to in-session history.
        final updated = [outgoing, ...state.history];
        state = state.copyWith(
          history: updated.length > 50 ? updated.sublist(0, 50) : updated,
        );
      }

      final initialEngagement = _ref.read(
        engagementProvider(EngagementParams(trackId: track.id)),
      );

      state = state.copyWith(
        currentTrack: track,
        isCurrentTrackLiked: initialEngagement.isLiked,
        isTogglingLike: false,
        position: Duration.zero,
        duration: track.duration ?? Duration.zero,
      );
      _audioHandler.setLiked(initialEngagement.isLiked);
      unawaited(
        _hydrateCurrentTrack(
          track.id,
          trackPermalink: track.trackPermalink,
        ),
      );

      // Resolve the server-authorized HLS URL.
      // If the stream endpoint fails, fall back to track.audioUrl only when
      // it is a valid remote URL — never pass an empty or local path to
      // ExoPlayer (setFilePath("") throws FileNotFoundException: ENOENT).
      final streamUrl = await _api.getStreamUrl(track.id);
      final fallback = track.audioUrl;
      final bool fallbackIsRemote =
          fallback.startsWith('http://') || fallback.startsWith('https://');

      final String? resolvedUrl = (streamUrl != null && streamUrl.isNotEmpty)
          ? streamUrl
          : (fallbackIsRemote ? fallback : null);

      if (resolvedUrl == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Track audio is unavailable',
        );
        return;
      }

      await _audioHandler.loadTrack(track, resolvedUrl);
      await _audioHandler.play();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Queue operations
  // -------------------------------------------------------------------------

  Future<void> playQueue(List<PlayerTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    state = state.copyWith(queue: tracks, currentQueueIndex: startIndex);
    await playTrack(tracks[startIndex]);
  }

  Future<void> skipToNext() async {
    final queue = state.queue;
    if (queue.isEmpty) {
      await seekTo(state.duration);
      return;
    }
    final nextIndex = state.currentQueueIndex + 1;
    if (nextIndex >= queue.length) {
      await seekTo(state.duration);
      return;
    }
    state = state.copyWith(currentQueueIndex: nextIndex);
    await playTrack(queue[nextIndex]);
  }

  Future<void> skipToPrevious() async {
    // If more than 3 s in, restart instead of going back
    if (state.position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    final queue = state.queue;
    if (queue.isEmpty) {
      await seekTo(Duration.zero);
      return;
    }
    final prevIndex = state.currentQueueIndex - 1;
    if (prevIndex < 0) return;
    state = state.copyWith(currentQueueIndex: prevIndex);
    await playTrack(queue[prevIndex]);
  }

  Future<void> seekTo(Duration position) async {
    await _audioHandler.seek(position);
    _scheduleSeekSync(position);
  }

  void addToQueue(PlayerTrack track) {
    state = state.copyWith(queue: [...state.queue, track]);
  }

  void removeFromQueue(int index) {
    final updated = List<PlayerTrack>.from(state.queue)..removeAt(index);
    state = state.copyWith(queue: updated);
  }

  void clearQueue() {
    state = state.copyWith(queue: []);
  }

  /// Reorders the queue without interrupting playback.
  /// Accepts the raw oldIndex / newIndex from [ReorderableListView.onReorder].
  void reorderQueue(int oldIndex, int newIndex) {
    // ReorderableListView passes newIndex as if the item is still present;
    // adjust before inserting.
    if (oldIndex < newIndex) newIndex -= 1;

    final queue = List<PlayerTrack>.from(state.queue);
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);

    // Keep currentQueueIndex pointing at the same track.
    int idx = state.currentQueueIndex;
    if (oldIndex == idx) {
      idx = newIndex;
    } else if (oldIndex < idx && newIndex >= idx) {
      idx -= 1;
    } else if (oldIndex > idx && newIndex <= idx) {
      idx += 1;
    }

    state = state.copyWith(queue: queue, currentQueueIndex: idx);
  }

  /// Jumps playback to a specific position in the queue.
  Future<void> skipToIndex(int index) async {
    final queue = state.queue;
    if (index < 0 || index >= queue.length) return;
    state = state.copyWith(currentQueueIndex: index);
    await playTrack(queue[index]);
  }

  // -------------------------------------------------------------------------
  // Backward-compatible methods (original signatures preserved)
  // -------------------------------------------------------------------------

  Future<void> playTrackFromFile({
    required String filePath,
    required String title,
    required String artist,
  }) async {
    await playTrack(PlayerTrack(
      id: filePath,
      title: title,
      artist: artist,
      audioUrl: filePath,
    ));
  }

  Future<void> playTrackFromUrl({
    required String url,
    required String title,
    required String artist,
  }) async {
    await playTrack(PlayerTrack(
      id: url,
      title: title,
      artist: artist,
      audioUrl: url,
    ));
  }

  void pause() {
    _audioHandler.pause();
  }

  void resume() {
    if (state.currentTrack != null) {
      _audioHandler.play();
    }
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  Future<void> toggleCurrentTrackLike() async {
    final track = state.currentTrack;
    if (track == null || state.isTogglingLike) return;

    final engParams = EngagementParams(trackId: track.id);
    final engState = _ref.read(engagementProvider(engParams));
    final wasLiked = engState.isLiked;
    final previousLikeCount = engState.likeCount;
    state = state.copyWith(
      isCurrentTrackLiked: !wasLiked,
      isTogglingLike: true,
    );
    _audioHandler.setLiked(!wasLiked);
    _writeLikedTrackOverride(
      track: track,
      liked: !wasLiked,
      likeCount: wasLiked ? previousLikeCount : previousLikeCount + 1,
    );

    try {
      final success =
          await _ref.read(engagementProvider(engParams).notifier).toggleLike();
      if (!success) {
        state = state.copyWith(
          isCurrentTrackLiked: wasLiked,
          isTogglingLike: false,
        );
        _audioHandler.setLiked(wasLiked);
        _writeLikedTrackOverride(
          track: track,
          liked: wasLiked,
          likeCount: previousLikeCount,
        );
        return;
      }
      state = state.copyWith(isTogglingLike: false);
    } catch (_) {
      state = state.copyWith(
        isCurrentTrackLiked: wasLiked,
        isTogglingLike: false,
      );
      _audioHandler.setLiked(wasLiked);
      _writeLikedTrackOverride(
        track: track,
        liked: wasLiked,
        likeCount: previousLikeCount,
      );
    }
  }

  void _writeLikedTrackOverride({
    required PlayerTrack track,
    required bool liked,
    required int likeCount,
  }) {
    final overrides = Map<String, TrackSummary>.from(
      _ref.read(likedTrackOverridesProvider),
    );
    if (liked) {
      overrides[track.id] = TrackSummary(
        id: track.id,
        title: track.title,
        artistName: track.artist,
        artistId: track.artistId,
        artistPermalink: track.artistPermalink,
        trackPermalink: track.trackPermalink,
        artworkUrl: track.coverUrl,
        audioUrl: track.audioUrl,
        waveform: track.waveform,
        likeCount: likeCount,
      );
    } else {
      overrides.remove(track.id);
    }
    _ref.read(likedTrackOverridesProvider.notifier).state = overrides;
  }

  void stop() {
    _audioHandler.stop();
    state = const PlayerState();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _audioHandler.setVolume(clamped);
    state = state.copyWith(volume: clamped);
    if (clamped > 0.0) {
      _lastAudibleVolume = clamped;
    }
  }

  Future<void> toggleMute() async {
    if (state.volume > 0.0) {
      await setVolume(0.0);
    } else {
      await setVolume(_lastAudibleVolume);
    }
  }

  /// Aliases used by the full-screen player UI.
  Future<void> skipNext() => skipToNext();
  Future<void> skipPrevious() => skipToPrevious();

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  void _onTrackCompleted() {
    // Report full listen for the completed track.
    final track = state.currentTrack;
    if (track != null && state.duration.inSeconds > 0) {
      _api.reportProgress(
        trackId: track.id,
        listenedSeconds: state.duration.inSeconds,
        totalSeconds: state.duration.inSeconds,
      );
    }

    final queue = state.queue;
    if (queue.isNotEmpty) {
      final nextIndex = state.currentQueueIndex + 1;
      if (nextIndex < queue.length) {
        state = state.copyWith(currentQueueIndex: nextIndex);
        playTrack(queue[nextIndex]);
        return;
      }
    }
    state = state.copyWith(isPlaying: false, position: Duration.zero);
  }

  Future<void> _hydrateCurrentTrack(
    String trackId, {
    String? trackPermalink,
  }) async {
    final details = await _api.getTrackDetails(
      trackId,
      trackPermalink: trackPermalink,
    );
    if (details == null) return;

    final current = state.currentTrack;
    if (current == null || current.id != trackId) return;

    state = state.copyWith(
      currentTrack: current.copyWith(
        id: current.id.isEmpty ? details.id : current.id,
        title: details.title.isNotEmpty ? details.title : current.title,
        artist: details.artist.isNotEmpty ? details.artist : current.artist,
        audioUrl: details.audioUrl.isNotEmpty ? details.audioUrl : current.audioUrl,
        coverUrl: (current.coverUrl == null || current.coverUrl!.isEmpty)
            ? details.coverUrl
            : current.coverUrl,
        duration: current.duration ?? details.duration,
        waveform: details.waveform ?? current.waveform,
        artistId: current.artistId ?? details.artistId,
        artistPermalink: current.artistPermalink ?? details.artistPermalink,
        trackPermalink: current.trackPermalink ?? details.trackPermalink,
      ),
      duration: state.duration == Duration.zero
          ? (current.duration ?? details.duration ?? Duration.zero)
          : state.duration,
    );
  }

  void _scheduleSeekSync(Duration position) {
    _seekSyncTimer?.cancel();
    final track = state.currentTrack;
    if (track == null) return;

    _seekSyncTimer = Timer(const Duration(milliseconds: 300), () {
      _api.syncPlayerState(
        trackId: track.id,
        position: position.inSeconds.toDouble(),
        isPlaying: state.isPlaying,
        queueContext: state.queueContext,
        contextId: state.contextId,
      );
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _seekSyncTimer?.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _playbackStateSub.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final notifier = PlayerNotifier(
    ref,
    ref.read(playerApiServiceProvider),
    appAudioHandler!,
  );

  ref.listen<String>(sessionUserIdProvider, (previous, next) {
    if (previous != null && previous != next) {
      notifier.stop();
    }
  });

  return notifier;
});
