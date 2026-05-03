import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../premium/presentation/providers/subscription_provider.dart';
import '../../domain/entities/upload_track.dart';
import '../providers/my_tracks_provider.dart';
import '../providers/upload_provider.dart';

class YourInsightsPage extends ConsumerStatefulWidget {
  const YourInsightsPage({super.key});

  @override
  ConsumerState<YourInsightsPage> createState() => _YourInsightsPageState();
}

class _YourInsightsPageState extends ConsumerState<YourInsightsPage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  String _timeframe = 'Last 30 days';
  late final AnimationController _pulseController;

  static const _bg = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.35,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    await ref.read(subscriptionProvider.notifier).refreshFromProfile();
    final sub = ref.read(subscriptionProvider);

    if (!sub.canUploadUnlimited) {
      final tracksAsync = ref.read(myTracksProvider);
      final trackCount =
          tracksAsync.maybeWhen(data: (t) => t.length, orElse: () => 0);
      if (trackCount >= 3) {
        if (mounted) _showUploadLimitDialog();
        return;
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null && mounted) {
          await ref
              .read(uploadProvider.notifier)
              .initializeUpload(audioFilePath: path);
          if (mounted) context.push('/upload');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUploadLimitDialog() {
    final sub = ref.read(subscriptionProvider);
    final planLabel = sub.planType == null ? 'Free' : sub.displayPlanName;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Upload limit reached',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Text(
          '$planLabel plan includes up to 3 uploads. Upgrade to Artist Pro for unlimited uploads.',
          style:
              const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Not now', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/premium');
            },
            child: const Text('Upgrade',
                style: TextStyle(color: Color(0xFFFF5500))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(myTracksProvider);
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => context.pop()),
            _InsightsTabs(
              selected: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
            Expanded(
              child: tracksAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
                error: (_, __) => _ErrorBody(onRetry: () {
                  ref.invalidate(myTracksProvider);
                }),
                data: (tracks) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    child: tracks.isEmpty
                        ? _MarketingEmptyState(onUpload: _pickAndUpload)
                        : _InsightsDashboard(
                            key: ValueKey('dashboard_$_selectedTab'),
                            tracks: tracks,
                            isArtistPro: sub.canUploadUnlimited,
                            selectedTab: _selectedTab,
                            timeframe: _timeframe,
                            pulseAnimation: _pulseController,
                            onTimeframeChanged: (value) {
                              setState(() => _timeframe = value);
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Your insights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _InsightsTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _TabItem(
            label: 'BioBeats',
            selected: selected == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 24),
          _TabItem(
            label: 'All Platforms',
            selected: selected == 1,
            onTap: () => onChanged(1),
          ),
          const SizedBox(width: 24),
          _TabItem(
            label: 'Fans',
            selected: selected == 2,
            showNew: true,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final bool showNew;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white38,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (showNew) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5500),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: selected ? label.length * 8.5 : 0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketingEmptyState extends StatelessWidget {
  final VoidCallback onUpload;

  const _MarketingEmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('insights_empty_state'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/SoundCloud_Insignts.1.png',
            height: 220,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
          const Text(
            'Get unmatched insights into your listeners that you won\'t find anywhere else.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'BioBeats helps you identify listener activity and track performance once your music is live.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'To get started, all it takes is an upload.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('insights_upload_button'),
              onPressed: onUpload,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Upload',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsDashboard extends StatelessWidget {
  final List<UploadTrack> tracks;
  final bool isArtistPro;
  final int selectedTab;
  final String timeframe;
  final Animation<double> pulseAnimation;
  final ValueChanged<String> onTimeframeChanged;

  const _InsightsDashboard({
    super.key,
    required this.tracks,
    required this.isArtistPro,
    required this.selectedTab,
    required this.timeframe,
    required this.pulseAnimation,
    required this.onTimeframeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _InsightMetrics.fromTracks(tracks);
    final allZero = metrics.total == 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: ListView(
        key: const ValueKey('insights_dashboard'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
        children: [
          Row(
            children: [
              _DateChip(
                value: timeframe,
                onChanged: onTimeframeChanged,
              ),
              const Spacer(),
              Text(
                selectedTab == 0
                    ? 'BioBeats activity'
                    : selectedTab == 1
                        ? 'External platform data unavailable'
                        : 'Fan insights',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _MainMetricCard(plays: metrics.plays, timeframe: timeframe),
          const SizedBox(height: 16),
          _MetricChipRow(metrics: metrics),
          const SizedBox(height: 12),
          Text(
            timeframe == 'Last 30 days'
                ? 'Showing activity from the last 30 days.'
                : 'Showing all available uploaded track totals.',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          if (allZero) ...[
            const SizedBox(height: 22),
            _NoActivityCard(
              onSwitch: () => onTimeframeChanged('Last 12 months'),
            ),
          ],
          const SizedBox(height: 26),
          _TopTracksSection(tracks: tracks),
          const SizedBox(height: 26),
          if (selectedTab == 2 || !isArtistPro)
            _FansSection(
              isArtistPro: isArtistPro,
              pulseAnimation: pulseAnimation,
            ),
          if (selectedTab == 1) ...[
            const SizedBox(height: 16),
            _UnavailableSection(
              title: 'All Platforms',
              subtitle:
                  'The current backend docs only expose platform-wide admin analytics, not creator platform breakdowns.',
            ),
          ],
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _DateChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: const Color(0xFF242426),
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'Last 30 days',
          child: Text('Last 30 days', style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 'Last 12 months',
          child: Text('Last 12 months', style: TextStyle(color: Colors.white)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MainMetricCard extends StatelessWidget {
  final int plays;
  final String timeframe;

  const _MainMetricCard({required this.plays, required this.timeframe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnimatedNumber(
            value: plays,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'plays in the ${timeframe.toLowerCase()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChipRow extends StatelessWidget {
  final _InsightMetrics metrics;

  const _MetricChipRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('plays', metrics.plays),
      ('likes', metrics.likes),
      ('comments', metrics.comments),
      ('reposts', metrics.reposts),
      ('downloads', metrics.downloads),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF242426),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _AnimatedNumber(
                      value: item.$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ' ${item.$1}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoActivityCard extends StatelessWidget {
  final VoidCallback onSwitch;

  const _NoActivityCard({required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Looks like there is no activity for the selected timeframe',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try selecting another timeframe.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onSwitch,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('Switch to last 12 months'),
          ),
        ],
      ),
    );
  }
}

class _TopTracksSection extends StatelessWidget {
  final List<UploadTrack> tracks;

  const _TopTracksSection({required this.tracks});

  @override
  Widget build(BuildContext context) {
    final sorted = [...tracks]
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top tracks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (final track in sorted.take(5)) _TopTrackTile(track: track),
      ],
    );
  }
}

class _TopTrackTile extends StatelessWidget {
  final UploadTrack track;

  const _TopTrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: const Color(0xFF2A2A2A),
              child: track.artworkUrl == null || track.artworkUrl!.isEmpty
                  ? const Icon(Icons.music_note, color: Colors.white30)
                  : Image.network(
                      track.artworkUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.music_note, color: Colors.white30),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title.isEmpty ? 'Untitled' : track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${track.playCount} plays ?? ${track.likeCount} likes ?? ${track.commentCount} comments',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${track.downloadCount}',
            style: const TextStyle(
              color: Color(0xFFFF5500),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.download_rounded,
              color: Color(0xFFFF5500), size: 16),
        ],
      ),
    );
  }
}

class _FansSection extends StatelessWidget {
  final bool isArtistPro;
  final Animation<double> pulseAnimation;

  const _FansSection({
    required this.isArtistPro,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (isArtistPro) {
      return const _UnavailableSection(
        title: 'Fans',
        subtitle:
            'Top listeners, countries, and platforms are not exposed by the current creator endpoints yet.',
      );
    }

    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Opacity(opacity: pulseAnimation.value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: Color(0xFFFF5500), size: 20),
                SizedBox(width: 8),
                Text(
                  'Fan insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SkeletonLine(widthFactor: 0.88),
            const SizedBox(height: 8),
            _SkeletonLine(widthFactor: 0.64),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
              ),
              child: const Text('Upgrade to Artist Pro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;

  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _UnavailableSection extends StatelessWidget {
  final String title;
  final String subtitle;

  const _UnavailableSection({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _AnimatedNumber({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, animated, __) => Text('$animated', style: style),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load insights.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightMetrics {
  final int plays;
  final int likes;
  final int comments;
  final int reposts;
  final int downloads;

  const _InsightMetrics({
    required this.plays,
    required this.likes,
    required this.comments,
    required this.reposts,
    required this.downloads,
  });

  int get total => plays + likes + comments + reposts + downloads;

  factory _InsightMetrics.fromTracks(List<UploadTrack> tracks) {
    return _InsightMetrics(
      plays: tracks.fold(0, (sum, track) => sum + track.playCount),
      likes: tracks.fold(0, (sum, track) => sum + track.likeCount),
      comments: tracks.fold(0, (sum, track) => sum + track.commentCount),
      reposts: tracks.fold(0, (sum, track) => sum + track.repostCount),
      downloads: tracks.fold(0, (sum, track) => sum + track.downloadCount),
    );
  }
}
