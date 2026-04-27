
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
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PlayerTrack && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
