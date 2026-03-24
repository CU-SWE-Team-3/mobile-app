import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerState {
  final String? currentTrackPath;
  final bool isPlaying;
  final String? currentTrackTitle;
  final String? currentTrackArtist;

  const PlayerState({
    this.currentTrackPath,
    this.isPlaying = false,
    this.currentTrackTitle,
    this.currentTrackArtist,
  });

  PlayerState copyWith({
    String? currentTrackPath,
    bool? isPlaying,
    String? currentTrackTitle,
    String? currentTrackArtist,
  }) {
    return PlayerState(
      currentTrackPath: currentTrackPath ?? this.currentTrackPath,
      isPlaying: isPlaying ?? this.isPlaying,
      currentTrackTitle: currentTrackTitle ?? this.currentTrackTitle,
      currentTrackArtist: currentTrackArtist ?? this.currentTrackArtist,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(const PlayerState());

  /// Play a track from a local file path
  Future<void> playTrackFromFile({
    required String filePath,
    required String title,
    required String artist,
  }) async {
    try {
      // In a real app, you'd use just_audio or similar package
      // For now, we'll just update the state to show what's playing
      state = state.copyWith(
        currentTrackPath: filePath,
        currentTrackTitle: title,
        currentTrackArtist: artist,
        isPlaying: true,
      );
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  /// Play a track from a URL
  Future<void> playTrackFromUrl({
    required String url,
    required String title,
    required String artist,
  }) async {
    try {
      state = state.copyWith(
        currentTrackPath: url,
        currentTrackTitle: title,
        currentTrackArtist: artist,
        isPlaying: true,
      );
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  /// Pause playback
  void pause() {
    state = state.copyWith(isPlaying: false);
  }

  /// Resume playback
  void resume() {
    if (state.currentTrackPath != null) {
      state = state.copyWith(isPlaying: true);
    }
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else if (state.currentTrackPath != null) {
      resume();
    }
  }

  /// Stop playback and clear current track
  void stop() {
    state = const PlayerState();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
