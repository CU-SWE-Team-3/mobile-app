class LikerUser {
  final String id;
  final String displayName;
  final String permalink;
  final String? avatarUrl;
  final bool isFollowing;

  const LikerUser({
    required this.id,
    required this.displayName,
    required this.permalink,
    this.avatarUrl,
    this.isFollowing = false,
  });

  factory LikerUser.fromJson(Map<String, dynamic> json) {
    return LikerUser(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      permalink: json['permalink'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }
}
