class Participant {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String permalink;

  const Participant({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.permalink,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    return Participant(
      id: id,
      displayName: json['displayName']?.toString() ??
          json['name']?.toString() ??
          json['username']?.toString() ??
          (id.isEmpty ? '' : 'Unknown user'),
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar']?.toString(),
      permalink: json['permalink']?.toString() ?? '',
    );
  }
}
