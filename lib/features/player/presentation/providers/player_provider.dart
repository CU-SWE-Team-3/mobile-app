import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../../player/domain/entities/player_track.dart';

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
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PlayerNotifier extends StateNotifier<PlayerState> {
  final ja.AudioPlayer _audioPlayer = ja.AudioPlayer();

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<ja.PlayerState> _playerStateSub;

  PlayerNotifier() : super(const PlayerState()) {
    // Sync the hardware volume to the state default so the UI and player agree
    // before the first explicit setVolume() call.
    _audioPlayer.setVolume(const PlayerState().volume);

    _positionSub = _audioPlayer.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen((ps) {
      final loading = ps.processingState == ja.ProcessingState.loading ||
          ps.processingState == ja.ProcessingState.buffering;

      state = state.copyWith(
        isPlaying: ps.playing,
        isLoading: loading,
      );

      if (ps.processingState == ja.ProcessingState.completed) {
        _onTrackCompleted();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Core play method — all others delegate here
  // -------------------------------------------------------------------------

  Future<void> playTrack(PlayerTrack track) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      // Push current track to history before switching
      if (state.currentTrack != null) {
        final updated = [state.currentTrack!, ...state.history];
        state = state.copyWith(
          history: updated.length > 50 ? updated.sublist(0, 50) : updated,
        );
      }

      state = state.copyWith(currentTrack: track);

      final url = track.audioUrl;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        await _audioPlayer.setUrl(url);
      } else {
        await _audioPlayer.setFilePath(url);
      }

      await _audioPlayer.play();
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
    if (queue.isEmpty) return;
    final nextIndex = state.currentQueueIndex + 1;
    if (nextIndex >= queue.length) return;
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
    if (queue.isEmpty) return;
    final prevIndex = state.currentQueueIndex - 1;
    if (prevIndex < 0) return;
    state = state.copyWith(currentQueueIndex: prevIndex);
    await playTrack(queue[prevIndex]);
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
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
    _audioPlayer.pause();
  }

  void resume() {
    if (state.currentTrack != null) {
      _audioPlayer.play();
    }
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  void stop() {
    _audioPlayer.stop();
    state = const PlayerState();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(clamped);
    state = state.copyWith(volume: clamped);
  }

  /// Aliases used by the full-screen player UI.
  Future<void> skipNext() => skipToNext();
  Future<void> skipPrevious() => skipToPrevious();

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  void _onTrackCompleted() {
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

  @override
  void dispose() {
    _positionSub.cancel();
    _durationSub.cancel();
    _playerStateSub.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
