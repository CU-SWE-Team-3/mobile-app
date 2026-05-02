import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/themes/app_theme.dart';
import '../providers/upload_provider.dart';

class UploadProgressPage extends ConsumerStatefulWidget {
  const UploadProgressPage({super.key});

  @override
  ConsumerState<UploadProgressPage> createState() => _UploadProgressPageState();
}

class _UploadProgressPageState extends ConsumerState<UploadProgressPage>
    with SingleTickerProviderStateMixin {
  bool _uploadStarted = false;
  bool _navigationScheduled = false;
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_uploadStarted) {
        _uploadStarted = true;
        // Clear stale progress/error state while preserving the track file path
        ref.read(uploadProvider.notifier).clearUploadStatus();
        ref.read(uploadProvider.notifier).uploadTrack();
      }
    });
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);
    final isComplete =
        uploadState.uploadProgress >= 1.0 && !uploadState.isUploading;
    final isProcessing = uploadState.processingState != null &&
        uploadState.processingState != 'Finished';

    // Auto navigate when upload completes successfully
    if (isComplete &&
        uploadState.successMessage != null &&
        !_navigationScheduled) {
      _navigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (context.mounted) context.go('/library/uploads');
          });
        }
      });
    }

    return PopScope(
      canPop: !uploadState.isUploading && !isProcessing,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: !(uploadState.isUploading || isProcessing)
              ? GestureDetector(
                  key: const ValueKey('upload_progress_back_button'),
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              : null,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── PROGRESS CIRCLE ────────────────────
                  _AnimatedUploadHero(
                    controller: _motionController,
                    progress: isProcessing ? 1 : uploadState.uploadProgress,
                    isProcessing: isProcessing,
                    isComplete:
                        isComplete && uploadState.successMessage != null,
                  ),
                  const SizedBox(height: 48),

                  // ── PROGRESS BAR (linear) ────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlowingProgressBar(
                          progress:
                              isProcessing ? 1.0 : uploadState.uploadProgress,
                          controller: _motionController,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isProcessing
                              ? 'Processing on server...'
                              : 'Uploading... ${(uploadState.uploadProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── TRACK INFO ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track Title',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          uploadState.track.title.isNotEmpty
                              ? uploadState.track.title
                              : 'Untitled Track',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Artist',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          uploadState.track.artist.isNotEmpty
                              ? uploadState.track.artist
                              : 'Unknown Artist',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── ROLE UPGRADE REQUIRED ─────────────

                  // ── ERROR MESSAGE ────────────────────
                  if (uploadState.error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              uploadState.error!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── SUCCESS MESSAGE ────────────────────
                  if (isComplete && uploadState.successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        border: Border.all(color: AppTheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppTheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              uploadState.successMessage!,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // ── ACTION BUTTONS ────────────────────
                  if (uploadState.isUploading || isProcessing)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Uploading...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (isComplete)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const ValueKey(
                                'upload_progress_view_uploads_button'),
                            onPressed: () => context.go('/library/uploads'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'View in My Uploads',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const ValueKey(
                                'upload_progress_upload_another_button'),
                            onPressed: () => context.go('/upload'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surface,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Upload Another Track',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (uploadState.error != null)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const ValueKey('upload_progress_retry_button'),
                            onPressed: () {
                              _uploadStarted = true;
                              ref
                                  .read(uploadProvider.notifier)
                                  .clearUploadStatus();
                              ref.read(uploadProvider.notifier).uploadTrack();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedUploadHero extends StatelessWidget {
  final AnimationController controller;
  final double progress;
  final bool isProcessing;
  final bool isComplete;

  const _AnimatedUploadHero({
    required this.controller,
    required this.progress,
    required this.isProcessing,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, __) {
            final pulse = isComplete
                ? 1.0
                : 1 + (math.sin(controller.value * math.pi * 2) * 0.025);
            return Transform.scale(
              scale: pulse,
              child: SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF5500).withValues(alpha: 0.24),
                            blurRadius: 34,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color:
                                const Color(0xFF8A3FFC).withValues(alpha: 0.18),
                            blurRadius: 52,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const SizedBox.expand(),
                    ),
                    CustomPaint(
                      size: const Size.square(178),
                      painter: _PremiumProgressRingPainter(
                        progress: animatedProgress,
                        rotation: controller.value,
                        isComplete: isComplete,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutBack,
                      child: isComplete
                          ? const Icon(
                              Icons.check_rounded,
                              key: ValueKey('upload_success_check'),
                              color: Colors.white,
                              size: 58,
                            )
                          : Column(
                              key: const ValueKey('upload_progress_percent'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${(animatedProgress * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isProcessing ? 'Processing' : 'Uploading',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PremiumProgressRingPainter extends CustomPainter {
  final double progress;
  final double rotation;
  final bool isComplete;

  _PremiumProgressRingPainter({
    required this.progress,
    required this.rotation,
    required this.isComplete,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = -math.pi / 2 + (rotation * math.pi * 2);
    final sweep = math.pi * 2 * progress.clamp(0, 1);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF26262A);
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..shader = const SweepGradient(
        colors: [Color(0xFFFF5500), Color(0xFF8A3FFC), Color(0xFFFF5500)],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, shadowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF5500),
          Color(0xFFFFB000),
          Color(0xFF8A3FFC),
          Color(0xFFFF5500),
        ],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, ringPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: isComplete ? 0.18 : 0.08);
    canvas.drawCircle(center.translate(-3, -5), radius - 22, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _PremiumProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        rotation != oldDelegate.rotation ||
        isComplete != oldDelegate.isComplete;
  }
}

class _GlowingProgressBar extends StatelessWidget {
  final double progress;
  final AnimationController controller;

  const _GlowingProgressBar({
    required this.progress,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, __) {
            return Container(
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: animatedProgress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment(-1 + controller.value * 2, 0),
                      end: Alignment(1 + controller.value * 2, 0),
                      colors: const [
                        Color(0xFFFF5500),
                        Color(0xFFFFB000),
                        Color(0xFF8A3FFC),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5500).withValues(alpha: 0.45),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
