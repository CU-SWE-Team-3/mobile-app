/// Lightweight search result used by the attachment picker and staged preview.
/// Carries only the display data needed for picker rows and the input bar preview.
/// Never serialized — constructed at the data layer from search API responses.
class AttachmentPickerItem {
  final String id;
  final String type; // 'track' | 'playlist'
  final String title;
  final String subtitle;
  final String? artworkUrl;

  const AttachmentPickerItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.artworkUrl,
  });
}
