/// A reference pointer to an existing track or playlist.
/// Attachments do not carry playable content — they point into the
/// track/playlist domain by referenceId. Resolution happens at render time.
class Attachment {
  final String type; // 'track' | 'playlist'
  final String referenceId;

  const Attachment({
    required this.type,
    required this.referenceId,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        type: json['type'] as String? ?? '',
        referenceId: json['referenceId'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'referenceId': referenceId,
      };
}
