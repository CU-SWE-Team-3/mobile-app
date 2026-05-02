import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../feed/presentation/providers/feed_provider.dart';

class FollowUnfollowButton extends StatefulWidget {
  final String userId;
  final bool isFollowing;

  const FollowUnfollowButton({
    super.key,
    required this.userId,
    this.isFollowing = false,
  });

  @override
  State<FollowUnfollowButton> createState() => _FollowUnfollowButtonState();
}

class _FollowUnfollowButtonState extends State<FollowUnfollowButton> {
  late bool _isFollowing;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  Future<void> _toggle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (_isFollowing) {
        await dioClient.dio.delete('/network/${widget.userId}/follow');
        setState(() => _isFollowing = false);
      } else {
        await dioClient.dio.post('/network/${widget.userId}/follow');
        setState(() => _isFollowing = true);
      }
      if (!mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      container.invalidate(followingFeedProvider);
      await container.read(followingFeedProvider.notifier).load();
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _toggle,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _isFollowing ? const Color(0xFF1F1F1F) : const Color(0xFFFF5500),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }
}
