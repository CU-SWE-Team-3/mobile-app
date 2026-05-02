import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../station/presentation/providers/station_providers.dart';

class LibraryStationsPage extends ConsumerStatefulWidget {
  const LibraryStationsPage({super.key});

  @override
  ConsumerState<LibraryStationsPage> createState() =>
      _LibraryStationsPageState();
}

class _LibraryStationsPageState extends ConsumerState<LibraryStationsPage> {
  static const _bg = Color(0xFF111111);
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(likedStationsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── top bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 20, 18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Text(
                    'Stations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.cast_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ],
              ),
            ),

            // ── content ────────────────────────────────────────────────
            stationsAsync.maybeWhen(
              data: (stations) => _SearchRow(
                controller: _searchController,
                count: stations.length,
                onChanged: (value) => setState(() => _query = value),
                onFilterTap: () {},
              ),
              orElse: () => _SearchRow(
                controller: _searchController,
                count: 0,
                onChanged: (value) => setState(() => _query = value),
                onFilterTap: () {},
              ),
            ),
            const SizedBox(height: 18),
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
                        onPressed: () => ref.invalidate(likedStationsProvider),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Color(0xFFFF5500)),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (stations) {
                  final filtered = _filterStations(stations);
                  if (stations.isEmpty) {
                    return _EmptyState();
                  }
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No stations found',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 132),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _StationTile(station: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LikedStation> _filterStations(List<LikedStation> stations) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return stations;
    return stations
        .where((station) => _stationSearchText(station).contains(q))
        .toList();
  }

  String _stationSearchText(LikedStation station) {
    final trackId = _seedTrackId(station);
    final cached = ref.watch(stationMetaCacheProvider)[station.id];
    final firstRelatedTrack = trackId != null && trackId.isNotEmpty
        ? ref.watch(stationTracksProvider(trackId)).maybeWhen(
              data: (tracks) => tracks.isNotEmpty ? tracks.first : null,
              orElse: () => null,
            )
        : null;

    return [
      cached?.title,
      station.seedTrackTitle,
      firstRelatedTrack?.title,
      station.title,
      cached?.artistName,
      station.seedTrackArtistName,
      firstRelatedTrack?.artistName,
      station.description,
    ].whereType<String>().join(' ').toLowerCase();
  }

  String? _seedTrackId(LikedStation station) {
    if (station.id.startsWith('track_')) return station.id.substring(6);
    return station.seedTrackId;
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final int count;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  const _SearchRow({
    required this.controller,
    required this.count,
    required this.onChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white54,
                decoration: InputDecoration(
                  hintText: 'Search $count stations',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 30,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            onTap: onFilterTap,
            child: const SizedBox(
              width: 42,
              height: 48,
              child: Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 31,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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

// ── Station tile ───────────────────────────────────────────────────────────────

class _StationTile extends ConsumerWidget {
  final LikedStation station;

  const _StationTile({required this.station});

  String? get _seedTrackId {
    if (station.id.startsWith('track_')) return station.id.substring(6);
    return station.seedTrackId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackId = _seedTrackId ?? '';
    final relatedAsync =
        trackId.isNotEmpty ? ref.watch(stationTracksProvider(trackId)) : null;
    final firstRelatedTrack = relatedAsync?.maybeWhen(
      data: (tracks) => tracks.isNotEmpty ? tracks.first : null,
      orElse: () => null,
    );

    // Recover artworkUrl / artistName from the session cache if the API didn't
    // return them (GET /stations/liked omits these fields).
    final cached = ref.watch(stationMetaCacheProvider)[station.id];
    final effectiveArtwork = station.artworkUrl ??
        cached?.artworkUrl ??
        station.seedTrackArtworkUrl ??
        firstRelatedTrack?.artworkUrl;
    final effectiveArtistName = cached?.artistName ??
        station.seedTrackArtistName ??
        firstRelatedTrack?.artistName;
    // Prefer the cached title (original track title) over the API station title
    // when available, since it's what the StationPage header shows.
    final stationTitleIsGeneric =
        station.title.isEmpty || station.title.toLowerCase() == 'station';
    final effectiveTitle = cached?.title ??
        station.seedTrackTitle ??
        firstRelatedTrack?.title ??
        (!stationTitleIsGeneric ? station.title : 'Station');
    final trackCount = relatedAsync?.maybeWhen(
      data: (tracks) => tracks.length,
      orElse: () => null,
    );

    final hasArtwork = effectiveArtwork != null &&
        effectiveArtwork.isNotEmpty &&
        effectiveArtwork.startsWith('http');
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: hasArtwork
                  ? CachedNetworkImage(
                      imageUrl: effectiveArtwork,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        [
                          'Track station',
                          if (trackCount != null) '$trackCount Tracks',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (effectiveArtistName != null &&
                      effectiveArtistName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      effectiveArtistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.more_vert_rounded,
              color: Colors.white70,
              size: 25,
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
