import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mock_audio_ad_provider.dart';

class MockAudioAdOverlay extends ConsumerWidget {
  const MockAudioAdOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adState = ref.watch(mockAudioAdProvider);

    return IgnorePointer(
      ignoring: !adState.isShowing,
      child: AnimatedOpacity(
        opacity: adState.isShowing ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: Container(
          color: Colors.black.withValues(alpha: 0.86),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween:
                  Tween<double>(begin: 0.96, end: adState.isShowing ? 1 : 0.96),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 340,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MockAdVisual(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Sponsored',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          adState.secondsRemaining > 0
                              ? 'Ad ends in ${adState.secondsRemaining}...'
                              : 'Ready to continue',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Upgrade your sound with BioBeats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create, upload, and discover more music.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: adState.canSkip
                            ? ref.read(mockAudioAdProvider.notifier).completeAd
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5500),
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white38,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          adState.canSkip ? 'Skip Ad' : 'Skip Ad',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockAdVisual extends StatelessWidget {
  const _MockAdVisual();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF5500),
              Color(0xFF24110A),
              Color(0xFF0F0F0F),
            ],
            stops: [0, 0.58, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: Icon(
                Icons.album_rounded,
                size: 132,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 18,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: Row(
                children: [18.0, 34.0, 24.0, 42.0, 28.0]
                    .map(
                      (height) => Container(
                        width: 5,
                        height: height,
                        margin: const EdgeInsets.only(left: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
