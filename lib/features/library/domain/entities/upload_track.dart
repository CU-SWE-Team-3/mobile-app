import 'package:equatable/equatable.dart';

class UploadTrack extends Equatable {
  // Server-assigned fields (null for locally-staged, pre-upload tracks)
  final String? id;
  final String? hlsUrl;
  final String? artworkUrl;
  final List<int>? waveform;

  final String? audioFilePath;
  final String? coverImagePath;
  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final List<String> tags;
  final DateTime? releaseDate;
  final bool isPublic;
  final String? description;
  final int? duration; // in milliseconds
  final String? processingState; // "Processing", "Finished", or null
  final bool enableDirectDownloads;
  final int playCount;
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final int downloadCount;

  const UploadTrack({
    this.id,
    this.hlsUrl,
    this.artworkUrl,
    this.waveform,
    this.audioFilePath,
    this.coverImagePath,
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    this.tags = const [],
    this.releaseDate,
    this.isPublic = true,
    this.description,
    this.duration,
    this.processingState,
    this.enableDirectDownloads = false,
    this.playCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.repostCount = 0,
    this.downloadCount = 0,
  });

  UploadTrack copyWith({
    String? id,
    String? hlsUrl,
    String? artworkUrl,
    List<int>? waveform,
    String? audioFilePath,
    String? coverImagePath,
    String? title,
    String? artist,
    String? album,
    String? genre,
    List<String>? tags,
    DateTime? releaseDate,
    bool? isPublic,
    String? description,
    int? duration,
    String? processingState,
    bool? enableDirectDownloads,
    int? playCount,
    int? likeCount,
    int? commentCount,
    int? repostCount,
    int? downloadCount,
  }) {
    return UploadTrack(
      id: id ?? this.id,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      waveform: waveform ?? this.waveform,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      tags: tags ?? this.tags,
      releaseDate: releaseDate ?? this.releaseDate,
      isPublic: isPublic ?? this.isPublic,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      processingState: processingState ?? this.processingState,
      enableDirectDownloads:
          enableDirectDownloads ?? this.enableDirectDownloads,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,
      downloadCount: downloadCount ?? this.downloadCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        hlsUrl,
        artworkUrl,
        waveform,
        audioFilePath,
        coverImagePath,
        title,
        artist,
        album,
        genre,
        tags,
        releaseDate,
        isPublic,
        description,
        duration,
        processingState,
        enableDirectDownloads,
        playCount,
        likeCount,
        commentCount,
        repostCount,
        downloadCount,
      ];
}
