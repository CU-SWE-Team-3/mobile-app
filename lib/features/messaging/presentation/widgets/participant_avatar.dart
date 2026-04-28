import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ParticipantAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;

  const ParticipantAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.radius = 20,
  });

  bool get _isDefault {
    final url = avatarUrl;
    return url == null || url.isEmpty || url.contains('default-avatar');
  }

  String get _initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    if (_isDefault) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[800],
        child: Text(
          _initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[800],
          child: Text(
            _initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.75,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
