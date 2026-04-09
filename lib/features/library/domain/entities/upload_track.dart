import 'package:equatable/equatable.dart';

class UploadTrack extends Equatable {
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

  const UploadTrack({
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
  });

  UploadTrack copyWith({
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
  }) {
    return UploadTrack(
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
    );
  }

  @override
  List<Object?> get props => [
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
      ];
}
