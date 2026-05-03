import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mock_audio_ad_provider.dart';

class MockAudioAdOverlay extends ConsumerStatefulWidget {
  const MockAudioAdOverlay({super.key});

  @override
  ConsumerState<MockAudioAdOverlay> createState() => _MockAudioAdOverlayState();
}

class _MockAudioAdOverlayState extends ConsumerState<MockAudioAdOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController;
  Offset _tilt = Offset.zero;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(mockAudioAdProvider);
    if (adState.isShowing && !_sweepController.isAnimating) {
      _sweepController.repeat();
    } else if (!adState.isShowing && _sweepController.isAnimating) {
      _sweepController.stop();
      _sweepController.value = 0;
    }

    return IgnorePointer(
      ignoring: !adState.isShowing,
      child: AnimatedOpacity(
        opacity: adState.isShowing ? 1 : 0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: Container(
          color: Colors.black.withValues(alpha: 0.88),
          child: Center(
            child: GestureDetector(
              onPanUpdate: (details) {
                final box = context.findRenderObject() as RenderBox?;
                final size = box?.size ?? const Size(1, 1);
                final local = details.localPosition;
                setState(() {
                  _tilt = Offset(
                    ((local.dx / size.width) - 0.5).clamp(-0.5, 0.5),
                    ((local.dy / size.height) - 0.5).clamp(-0.5, 0.5),
                  );
                });
              },
              onPanEnd: (_) => setState(() => _tilt = Offset.zero),
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.985 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  transformAlignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(_tilt.dy * -0.12)
                    ..rotateY(_tilt.dx * 0.12),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.94,
                      end: adState.isShowing ? 1 : 0.94,
                    ),
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: AnimatedBuilder(
                      animation: _sweepController,
                      builder: (context, _) {
                        return _PremiumAdCard(
                          adState: adState,
                          sweepValue: _sweepController.value,
                          onComplete:
                              ref.read(mockAudioAdProvider.notifier).completeAd,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumAdCard extends StatelessWidget {
  final MockAudioAdState adState;
  final double sweepValue;
  final VoidCallback onComplete;

  const _PremiumAdCard({
    required this.adState,
    required this.sweepValue,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 36, 360.0);

    return Container(
      width: width,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF6A00),
            Color(0xFF9A5CFF),
            Color(0x33FFFFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5500).withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 48,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xF21A171C),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MockAdVisual(sweepValue: sweepValue),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Text(
                          'Sponsored',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        adState.secondsRemaining > 0
                            ? 'Ad ends in ${adState.secondsRemaining}s'
                            : 'Ready',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Upgrade your sound with BioBeats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create, upload, and discover more music with premium tools.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: adState.canSkip ? onComplete : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5500),
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white38,
                        elevation: adState.canSkip ? 8 : 0,
                        shadowColor:
                            const Color(0xFFFF5500).withValues(alpha: 0.38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Continue listening',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _CardSweep(progress: sweepValue),
          ],
        ),
      ),
    );
  }
}

class _MockAdVisual extends StatelessWidget {
  final double sweepValue;

  const _MockAdVisual({required this.sweepValue});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6A00),
                    Color(0xFF6431A8),
                    Color(0xFF0D0D10),
                  ],
                  stops: [0, 0.58, 1],
                ),
              ),
            ),
            Positioned(
              right: -14 + (sweepValue * 10),
              top: -18,
              child: Icon(
                Icons.album_rounded,
                size: 132,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 18,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
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
                children: [20.0, 38.0, 26.0, 44.0, 30.0]
                    .map(
                      (height) => Container(
                        width: 5,
                        height: height + math.sin(sweepValue * math.pi * 2) * 2,
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

class _CardSweep extends StatelessWidget {
  final double progress;

  const _CardSweep({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sweepWidth = constraints.maxWidth * 0.42;
            final left =
                -sweepWidth + (constraints.maxWidth + sweepWidth) * progress;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: left,
                  width: sweepWidth,
                  child: Transform.rotate(
                    angle: -0.22,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
