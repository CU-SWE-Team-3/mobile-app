ï»¿import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../station/data/datasources/station_remote_data_source.dart';
import '../../../station/presentation/providers/station_providers.dart';

class LibraryStationsPage extends ConsumerWidget {
  const LibraryStationsPage({super.key});

  static const _bg = Color(0xFF111111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(likedStationsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ?????? top bar ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Stations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cast_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ?????? content ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
            Expanded(
              child: stationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                ),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load stations',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(likedStationsProvider),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Color(0xFFFF5500)),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (stations) {
                  if (stations.isEmpty) {
                    return _EmptyState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 132),
                    physics: const BouncingScrollPhysics(),
                    itemCount: stations.length,
                    itemBuilder: (_, i) => _StationTile(station: stations[i]),
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

// ?????? Empty state ????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'No stations yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Stations you have liked will show up here. '
            'To start a station, just search for a track or '
            'artist, then tap the menu and select "Start station".',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => context.go('/search'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Begin search',
                style: TextStyle(
                  color: Colors.black,
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

// ?????? Station tile ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

class _StationTile extends ConsumerWidget {
  final LikedStation station;

  const _StationTile({required this.station});

  String? get _seedTrackId {
    if (station.id.startsWith('track_')) return station.id.substring(6);
    return station.seedTrackId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Recover artworkUrl / artistName from the session cache if the API didn't
    // return them (GET /stations/liked omits these fields).
    final cached = ref.watch(stationMetaCacheProvider)[station.id];
    final effectiveArtwork =
        station.artworkUrl ?? cached?.artworkUrl;
    final effectiveArtistName = cached?.artistName;
    // Prefer the cached title (original track title) over the API station title
    // when available, since it's what the StationPage header shows.
    final effectiveTitle =
        cached?.title ?? (station.title.isNotEmpty ? station.title : 'Station');

    final hasArtwork = effectiveArtwork != null &&
        effectiveArtwork.isNotEmpty &&
        effectiveArtwork.startsWith('http');
    final trackId = _seedTrackId ?? '';

    return GestureDetector(
      onTap: () {
        context.push('/station', extra: {
          'trackId': trackId,
          'title': effectiveTitle,
          'artistName': effectiveArtistName,
          'artworkUrl': effectiveArtwork,
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: hasArtwork
                    ? CachedNetworkImage(
                        imageUrl: effectiveArtwork!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectiveTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (effectiveArtistName != null &&
                      effectiveArtistName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      effectiveArtistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ] else if (station.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      station.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF2A2A2A),
        child: const Center(
          child: Icon(
            Icons.wifi_tethering_rounded,
            color: Colors.white24,
            size: 28,
          ),
        ),
      );
}
