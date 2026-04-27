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

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: json['_id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        permalink: json['permalink'] as String? ?? '',
      );
}
