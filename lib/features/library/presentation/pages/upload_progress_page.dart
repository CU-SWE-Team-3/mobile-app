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

class _UploadProgressPageState extends ConsumerState<UploadProgressPage> {
  bool _uploadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_uploadStarted) {
        _uploadStarted = true;
        // Call simulateUpload exactly once
        if (!ref.read(uploadProvider).isUploading) {
          ref.read(uploadProvider.notifier).simulateUpload();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);
    final isComplete =
        uploadState.uploadProgress >= 1.0 && !uploadState.isUploading;
    final isProcessing = uploadState.processingState != null &&
        uploadState.processingState != 'Finished';

    // Auto navigate when upload completes successfully
    if (isComplete && uploadState.successMessage != null) {
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
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value:
                              isProcessing ? 1.0 : uploadState.uploadProgress,
                          strokeWidth: 8,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary,
                          ),
                          backgroundColor: AppTheme.surface,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isProcessing)
                              Text(
                                '${(uploadState.uploadProgress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              const SizedBox(height: 8),
                            const SizedBox(height: 4),
                            Text(
                              isProcessing
                                  ? 'Processing on server...'
                                  : isComplete
                                      ? 'Complete!'
                                      : 'Uploading...',
                              style: TextStyle(
                                color: isProcessing
                                    ? AppTheme.primary
                                    : Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value:
                                isProcessing ? 1.0 : uploadState.uploadProgress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFF2A2A2A),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF5500),
                            ),
                          ),
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

                  const Spacer(),

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
                            onPressed: () {
                              _uploadStarted = false;
                              ref.read(uploadProvider.notifier).clearError();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref
                                    .read(uploadProvider.notifier)
                                    .simulateUpload();
                                _uploadStarted = true;
                              });
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
