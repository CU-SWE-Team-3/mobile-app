import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_downloaded_track.dart';

class OfflineDownloadsRepository {
  static const _key = 'offline_downloaded_tracks_v1';

  Future<List<OfflineDownloadedTrack>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              OfflineDownloadedTrack.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList(); // newest first
    } catch (_) {
      return [];
    }
  }

  Future<void> save(OfflineDownloadedTrack track) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    // Deduplicate: remove any previous entry for the same trackId
    final updated = existing.where((t) => t.trackId != track.trackId).toList()
      ..add(track);
    await prefs.setString(
        _key, jsonEncode(updated.map((t) => t.toJson()).toList()));
  }

  Future<void> remove(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final updated = existing.where((t) => t.trackId != trackId).toList();
    await prefs.setString(
        _key, jsonEncode(updated.map((t) => t.toJson()).toList()));
  }
}

final offlineDownloadsRepositoryProvider =
    Provider<OfflineDownloadsRepository>((_) => OfflineDownloadsRepository());

/// FutureProvider — call `ref.invalidate(offlineDownloadsProvider)` to refresh.
final offlineDownloadsProvider =
    FutureProvider<List<OfflineDownloadedTrack>>((ref) async {
  return ref.read(offlineDownloadsRepositoryProvider).getAll();
});
