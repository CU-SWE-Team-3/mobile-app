class Playlist {
  final String id;
  final String title;
  final String? artworkUrl;
  final String ownerName;
  final int trackCount;
  final bool isPublic;

  Playlist({
    String? id,
    required this.title,
    this.artworkUrl,
    required this.ownerName,
    this.trackCount = 0,
    this.isPublic = true,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artworkUrl': artworkUrl,
        'ownerName': ownerName,
        'trackCount': trackCount,
        'isPublic': isPublic,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '',
        artworkUrl: json['artworkUrl'] as String?,
        ownerName: json['ownerName'] as String? ?? '',
        trackCount: json['trackCount'] as int? ?? 0,
        isPublic: json['isPublic'] as bool? ?? true,
      );
}
