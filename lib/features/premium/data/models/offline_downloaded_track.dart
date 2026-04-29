class OfflineDownloadedTrack {
  final String trackId;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final DateTime downloadedAt;
  final String? localPath;
  final String? planType;
  final String? genre;
  final int? duration;
  // 'file' = real audio saved locally, 'metadataOnly' = artist disabled download
  final String downloadMode;
  final bool fileAvailable;
  final bool backendDownloadAllowed;
  final String? blockedReason;

  const OfflineDownloadedTrack({
    required this.trackId,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    required this.downloadedAt,
    this.localPath,
    this.planType,
    this.genre,
    this.duration,
    this.downloadMode = 'file',
    this.fileAvailable = true,
    this.backendDownloadAllowed = true,
    this.blockedReason,
  });

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'artworkUrl': artworkUrl,
        'downloadedAt': downloadedAt.toIso8601String(),
        'localPath': localPath,
        'planType': planType,
        'genre': genre,
        'duration': duration,
        'downloadMode': downloadMode,
        'fileAvailable': fileAvailable,
        'backendDownloadAllowed': backendDownloadAllowed,
        'blockedReason': blockedReason,
      };

  factory OfflineDownloadedTrack.fromJson(Map<String, dynamic> json) =>
      OfflineDownloadedTrack(
        trackId: json['trackId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String,
        artworkUrl: json['artworkUrl'] as String?,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        localPath: json['localPath'] as String?,
        planType: json['planType'] as String?,
        genre: json['genre'] as String?,
        duration: json['duration'] as int?,
        downloadMode: json['downloadMode'] as String? ?? 'file',
        fileAvailable: json['fileAvailable'] as bool? ?? true,
        backendDownloadAllowed: json['backendDownloadAllowed'] as bool? ?? true,
        blockedReason: json['blockedReason'] as String?,
      );
}
