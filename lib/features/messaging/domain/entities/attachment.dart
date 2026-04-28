/// A reference pointer to an existing track or playlist.
/// Carries an optional metadata snapshot (title, artworkUrl, subtitle) so
/// AttachmentCard can render without a network fetch. Populated from the
/// AttachmentPickerItem on the sender side, and from inline server fields on
/// the receiver side when the backend embeds them.
class Attachment {
  final String type; // 'track' | 'playlist'
  final String referenceId;

  /// Optional snapshot — present for sender-side optimistic messages and for
  /// received messages if the backend embeds track metadata inline.
  final String? title;
  final String? artworkUrl;
  final String? subtitle;

  const Attachment({
    required this.type,
    required this.referenceId,
    this.title,
    this.artworkUrl,
    this.subtitle,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        type: json['type'] as String? ?? '',
        referenceId: json['referenceId'] as String? ?? '',
        title: json['title'] as String?,
        artworkUrl: json['artworkUrl'] as String?,
        subtitle: json['subtitle'] as String?,
      );

  Attachment copyWith({
    String? title,
    String? artworkUrl,
    String? subtitle,
  }) =>
      Attachment(
        type: type,
        referenceId: referenceId,
        title: title ?? this.title,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        subtitle: subtitle ?? this.subtitle,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'referenceId': referenceId,
      };
}
