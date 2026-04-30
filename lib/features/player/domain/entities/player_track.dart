import 'package:flutter/foundation.dart';

class PlayerTrack {
  final String id;
  final String title;
  final String artist;
  final String audioUrl; // supports both file path and HTTP URL
  final String? coverUrl;
  final Duration? duration;
  final List<int>? waveform;
  final String? artistId;
  final String? artistPermalink;
  final String? trackPermalink;

  const PlayerTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverUrl,
    this.duration,
    this.waveform,
    this.artistId,
    this.artistPermalink,
    this.trackPermalink,
  });

  PlayerTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? audioUrl,
    String? coverUrl,
    Duration? duration,
    List<int>? waveform,
    String? artistId,
    String? artistPermalink,
    String? trackPermalink,
  }) {
    return PlayerTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      artistId: artistId ?? this.artistId,
      artistPermalink: artistPermalink ?? this.artistPermalink,
      trackPermalink: trackPermalink ?? this.trackPermalink,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerTrack &&
        other.id == id &&
        other.title == title &&
        other.artist == artist &&
        other.audioUrl == audioUrl &&
        other.coverUrl == coverUrl &&
        other.duration == duration &&
        listEquals(other.waveform, waveform) &&
        other.artistId == artistId &&
        other.artistPermalink == artistPermalink &&
        other.trackPermalink == trackPermalink;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        artist,
        audioUrl,
        coverUrl,
        duration,
        Object.hashAll(waveform ?? const []),
        artistId,
        artistPermalink,
        trackPermalink,
      );
}
