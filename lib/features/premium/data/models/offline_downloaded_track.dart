class OfflineDownloadedTrack {
  final String trackId;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final String? audioUrl;
  final DateTime downloadedAt;
  final String? localPath;
  final String? planType;
  final String? genre;
  final int? duration;
  // 'file' = real audio saved locally, 'metadataOnly' = artist disabled preview
  final String downloadMode;
  final bool fileAvailable;
  final bool backendDownloadAllowed;
  final String? blockedReason;
  // true when the entry was created locally without a real backend file response
  final bool isMockDownload;

  const OfflineDownloadedTrack({
    required this.trackId,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    this.audioUrl,
    required this.downloadedAt,
    this.localPath,
    this.planType,
    this.genre,
    this.duration,
    this.downloadMode = 'file',
    this.fileAvailable = true,
    this.backendDownloadAllowed = true,
    this.blockedReason,
    this.isMockDownload = false,
  });

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'artworkUrl': artworkUrl,
        'audioUrl': audioUrl,
        'downloadedAt': downloadedAt.toIso8601String(),
        'localPath': localPath,
        'planType': planType,
        'genre': genre,
        'duration': duration,
        'downloadMode': downloadMode,
        'fileAvailable': fileAvailable,
        'backendDownloadAllowed': backendDownloadAllowed,
        'blockedReason': blockedReason,
        'isMockDownload': isMockDownload,
      };

  factory OfflineDownloadedTrack.fromJson(Map<String, dynamic> json) =>
      OfflineDownloadedTrack(
        trackId: json['trackId'] as String,
        title: json['title'] as String,
        artistName: json['artistName'] as String,
        artworkUrl: json['artworkUrl'] as String?,
        audioUrl: json['audioUrl'] as String?,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        localPath: json['localPath'] as String?,
        planType: json['planType'] as String?,
        genre: json['genre'] as String?,
        duration: json['duration'] as int?,
        downloadMode: json['downloadMode'] as String? ?? 'file',
        fileAvailable: json['fileAvailable'] as bool? ?? true,
        backendDownloadAllowed: json['backendDownloadAllowed'] as bool? ?? true,
        blockedReason: json['blockedReason'] as String?,
        isMockDownload: json['isMockDownload'] as bool? ?? false,
      );
}
