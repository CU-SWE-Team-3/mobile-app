class OfflineDownloadedTrack {
  final String trackId;
  final String title;
  final String artistName;
  final String? artworkUrl;
  final DateTime downloadedAt;
  final String? localPath;
  final String? planType;

  const OfflineDownloadedTrack({
    required this.trackId,
    required this.title,
    required this.artistName,
    this.artworkUrl,
    required this.downloadedAt,
    this.localPath,
    this.planType,
  });

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'artworkUrl': artworkUrl,
        'downloadedAt': downloadedAt.toIso8601String(),
        'localPath': localPath,
        'planType': planType,
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
      );
}
