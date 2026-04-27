class User {
  final String id;
  final String permalink;
  final String displayName;
  final String? location;
  final String? bio;
  final List<String> favoriteGenres;
  final Map<String, String?> socialLinks;
  final bool isPrivate;
  final String role;
  final bool isPremium;
  final bool isEmailVerified;
  final String accountStatus;
  final String? avatarUrl;
  final String? coverPhotoUrl;
  final int followerCount;
  final int followingCount;

  const User({
    required this.id,
    required this.permalink,
    required this.displayName,
    this.location,
    this.bio,
    required this.favoriteGenres,
    required this.socialLinks,
    required this.isPrivate,
    required this.role,
    required this.isPremium,
    required this.isEmailVerified,
    required this.accountStatus,
    this.avatarUrl,
    this.coverPhotoUrl,
    required this.followerCount,
    required this.followingCount,
  });
}