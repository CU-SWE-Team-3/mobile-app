import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navigate to a user's profile.
/// Routes to /profile (own page) if [userId] matches the stored userId,
/// otherwise pushes /user/[permalink] with extra data.
Future<void> navigateToUserProfile(
  BuildContext context, {
  required String userId,
  required String permalink,
  required String displayName,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final myId = prefs.getString('userId') ?? '';

  if (!context.mounted) return;

  if (myId.isNotEmpty && myId == userId) {
    context.push('/profile');
  } else {
    context.push(
      '/user/$permalink',
      extra: {'displayName': displayName, 'userId': userId},
    );
  }
}
