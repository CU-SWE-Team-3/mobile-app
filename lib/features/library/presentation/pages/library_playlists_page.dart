import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../playlist/domain/entities/playlist.dart';
import '../../../playlist/presentation/pages/playlist_details_page.dart';

// ── Provider ────────────────────────────────────────────────────────────────

const _kPlaylistsKey = 'playlists_data';

class _PlaylistNotifier extends StateNotifier<List<Playlist>> {
  _PlaylistNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlaylistsKey);
    if (raw != null && raw.isNotEmpty) {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) state = list;
    }
  }

  Future<void> add(Playlist playlist) async {
    state = [...state, playlist];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }

  Future<void> updateVisibility(String id, bool isPublic) async {
    state = state
        .map((p) => p.id == id
            ? Playlist(
                id: p.id,
                title: p.title,
                artworkUrl: p.artworkUrl,
                ownerName: p.ownerName,
                trackCount: p.trackCount,
                isPublic: isPublic,
              )
            : p)
        .toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPlaylistsKey, jsonEncode(state.map((p) => p.toJson()).toList()));
  }
}

final playlistsProvider =
    StateNotifierProvider<_PlaylistNotifier, List<Playlist>>(
  (_) => _PlaylistNotifier(),
);

// ── Constants ────────────────────────────────────────────────────────────────

const _bg = Color(0xFF111111);
const _surface = Color(0xFF1F1F1F);
const _primary = Color(0xFFFF5500);
const _secondary = Color(0xFF999999);

// ── Page ─────────────────────────────────────────────────────────────────────

class LibraryPlaylistsPage extends ConsumerWidget {
  const LibraryPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onAdd: () => _openCreateSheet(context, ref)),
            Expanded(
              child: playlists.isEmpty
                  ? _EmptyState(onCreateTap: () => _openCreateSheet(context, ref))
                  : _PlaylistList(
                      playlists: playlists,
                      onCreateNew: () => _openCreateSheet(context, ref),
                      onImport: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const _ImportPage()),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CreateSheet(
        onSave: (title, isPublic) {
          _addPlaylist(ref, title, isPublic);
        },
      ),
    );
  }

  Future<void> _addPlaylist(
      WidgetRef ref, String title, bool isPublic) async {
    final prefs = await SharedPreferences.getInstance();
    final ownerName =
        prefs.getString('displayName') ?? prefs.getString('username') ?? 'You';
    ref.read(playlistsProvider.notifier).add(Playlist(
          title: title,
          ownerName: ownerName,
          isPublic: isPublic,
        ));
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _TopBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: _circleBtn(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(width: 12),
          const Text(
            'Playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _circleBtn(Icons.cast_rounded),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAdd,
            child: _circleBtn(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 32, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No playlists yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Playlists you have liked or created will show up here.',
              textAlign: TextAlign.left,
              style: TextStyle(color: _secondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onCreateTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Create playlist',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Playlist list ─────────────────────────────────────────────────────────────

class _PlaylistList extends StatefulWidget {
  final List<Playlist> playlists;
  final VoidCallback onCreateNew;
  final VoidCallback onImport;

  const _PlaylistList({
    required this.playlists,
    required this.onCreateNew,
    required this.onImport,
  });

  @override
  State<_PlaylistList> createState() => _PlaylistListState();
}

class _PlaylistListState extends State<_PlaylistList> {
  late final TextEditingController _searchCtrl;
  List<Playlist> _filtered = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtered = widget.playlists;
  }

  @override
  void didUpdateWidget(_PlaylistList old) {
    super.didUpdateWidget(old);
    if (old.playlists != widget.playlists) {
      _applyFilter(_searchCtrl.text);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.playlists
          : widget.playlists
              .where((p) => p.title.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.playlists.length;
    final hasQuery = _searchCtrl.text.isNotEmpty;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: Colors.white38, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _applyFilter,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: Colors.white54,
                    decoration: InputDecoration(
                      hintText: 'Search $totalCount playlists',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (hasQuery)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _applyFilter('');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white54, size: 18),
                    ),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
        // Action buttons row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.download_rounded,
                  label: 'Import',
                  onTap: widget.onImport,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.add,
                  label: 'Create new',
                  onTap: widget.onCreateNew,
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _PlaylistTile(playlist: _filtered[i]),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailsPage(playlist: playlist),
        ),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 56,
              child: playlist.artworkUrl != null
                  ? Image.network(playlist.artworkUrl!, fit: BoxFit.cover)
                  : const ColoredBox(
                      color: Color(0xFF2A2A2A),
                      child: Center(
                        child: Icon(Icons.music_note,
                            color: Colors.white38, size: 24),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  playlist.ownerName,
                  style: const TextStyle(color: _secondary, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Text(
                      'Playlist',
                      style: TextStyle(color: _secondary, fontSize: 11),
                    ),
                    const Text(' · ',
                        style: TextStyle(color: _secondary, fontSize: 11)),
                    Text(
                      '${playlist.trackCount} Tracks',
                      style: const TextStyle(color: _secondary, fontSize: 11),
                    ),
                    if (!playlist.isPublic) ...[
                      const Text(' · ',
                          style: TextStyle(color: _secondary, fontSize: 11)),
                      const Icon(Icons.lock_outline,
                          color: _secondary, size: 11),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: _surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => _PlaylistOptionsSheet(playlist: playlist),
            ),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.more_vert_rounded, color: _secondary, size: 20),
            ),
          ),
        ],
      ),
    ));
  }
}

// ── Playlist options sheet ────────────────────────────────────────────────────

class _PlaylistOptionsSheet extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistOptionsSheet({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: thumbnail + title/owner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: playlist.artworkUrl != null
                          ? Image.network(playlist.artworkUrl!,
                              fit: BoxFit.cover)
                          : const ColoredBox(
                              color: Color(0xFF2A2A2A),
                              child: Center(
                                child: Icon(Icons.music_note,
                                    color: Colors.white38, size: 24),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          playlist.ownerName,
                          style:
                              const TextStyle(color: _secondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 28),
            // Edit
            _optionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming soon'),
                    backgroundColor: _surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            // Make private / Make public
            _optionRow(
              icon: Icons.lock_outline,
              label: playlist.isPublic ? 'Make private' : 'Make public',
              onTap: () {
                Navigator.pop(context);
                ref.read(playlistsProvider.notifier).updateVisibility(
                      playlist.id,
                      !playlist.isPublic,
                    );
              },
            ),
            // Delete
            _optionRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: () {
                Navigator.pop(context);
                ref.read(playlistsProvider.notifier).remove(playlist.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlist deleted'),
                    backgroundColor: _surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 16),
              Text(label,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      );
}

// ── Create bottom sheet ───────────────────────────────────────────────────────

class _CreateSheet extends StatefulWidget {
  final void Function(String title, bool isPublic) onSave;
  const _CreateSheet({required this.onSave});

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  late final TextEditingController _ctrl;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: 'Untitled Playlist')
      ..selection =
          const TextSelection(baseOffset: 0, extentOffset: 17); // select all
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                    const Expanded(
                      child: Text(
                        'Create playlist',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Title field
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: _primary,
                  decoration: InputDecoration(
                    labelText: 'Playlist title',
                    labelStyle: const TextStyle(color: _secondary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF3A3A3A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _primary),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                  ),
                ),
                const SizedBox(height: 16),
                // Make public toggle
                Row(
                  children: [
                    const Text(
                      'Make public',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const Spacer(),
                    Switch(
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      activeThumbColor: Colors.white,
                      activeTrackColor: _primary,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFF3A3A3A),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final title = _ctrl.text.trim().isEmpty ? 'Untitled Playlist' : _ctrl.text.trim();
    Navigator.pop(context);
    widget.onSave(title, _isPublic);
  }
}

// ── Import page ───────────────────────────────────────────────────────────────

class _ImportPage extends StatelessWidget {
  const _ImportPage();

  static const _providers = [
    _ProviderCard(name: 'Spotify', color: Color(0xFF1DB954)),
    _ProviderCard(name: 'Apple Music', color: Color(0xFFFC3C44)),
    _ProviderCard(name: 'Deezer', color: Color(0xFF9B59B6)),
    _ProviderCard(name: 'Tidal', color: Color(0xFF2D2D2D)),
    _ProviderCard(name: 'Amazon Music', color: Color(0xFF0F2040)),
    _ProviderCard(name: 'Resso', color: Color(0xFFE91E8C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                    'Import music (1/3)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Select a provider',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: _providers
                    .map((p) => _ProviderCardWidget(
                          card: p,
                          onTap: () => _showComingSoon(context, p.name),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name integration coming soon!'),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ProviderCard {
  final String name;
  final Color color;
  const _ProviderCard({required this.name, required this.color});
}

class _ProviderCardWidget extends StatelessWidget {
  final _ProviderCard card;
  final VoidCallback onTap;
  const _ProviderCardWidget({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: card.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            card.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
