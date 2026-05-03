// Unit tests for PlaylistNotifier.
//
// Verifies that add, remove, and updateVisibility delegate network work to
// PlaylistRepository and that local state is updated only when the API call
// succeeds (i.e. the notifier does not mutate state on repository errors).
//
// Run with:
//   flutter test test/features/playlist/presentation/providers/playlists_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundcloud_clone/features/playlist/data/repositories/playlist_repository.dart';
import 'package:soundcloud_clone/features/playlist/domain/entities/playlist.dart';
import 'package:soundcloud_clone/features/playlist/presentation/providers/playlists_provider.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockPlaylistRepository extends Mock implements PlaylistRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Playlist _playlist({String id = 'p1', bool isPublic = true}) =>
    Playlist(id: id, title: 'Test Playlist', ownerName: 'User', isPublic: isPublic);

Future<PlaylistNotifier> _buildNotifier(MockPlaylistRepository repo) async {
  // _load() reads SharedPreferences; empty values → state stays [].
  SharedPreferences.setMockInitialValues({});
  // fetchById is called by _backfillArtwork only when state is non-empty
  // after loading — with empty prefs it is never triggered, but stub anyway.
  when(() => repo.fetchById(any())).thenAnswer((_) async => {});

  final notifier = PlaylistNotifier(repo);
  await pumpEventQueue(); // drain async _load()
  return notifier;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = MockPlaylistRepository();
  });

  // ── add ───────────────────────────────────────────────────────────────────

  group('PlaylistNotifier — add', () {
    test('appends the playlist to state', () async {
      final notifier = await _buildNotifier(mockRepo);
      final p = _playlist();

      await notifier.add(p);

      expect(notifier.state, contains(p));
    });

    test('does not call any repository method', () async {
      final notifier = await _buildNotifier(mockRepo);

      await notifier.add(_playlist());

      verifyNever(() => mockRepo.deletePlaylist(any()));
      verifyNever(() => mockRepo.updatePrivacy(any(), any()));
    });
  });

  // ── remove ────────────────────────────────────────────────────────────────

  group('PlaylistNotifier — remove', () {
    test('calls repository.deletePlaylist with the correct id', () async {
      when(() => mockRepo.deletePlaylist(any())).thenAnswer((_) async {});
      final notifier = await _buildNotifier(mockRepo);
      await notifier.add(_playlist(id: 'p1'));

      await notifier.remove('p1');

      verify(() => mockRepo.deletePlaylist('p1')).called(1);
    });

    test('removes the playlist from state after success', () async {
      when(() => mockRepo.deletePlaylist(any())).thenAnswer((_) async {});
      final notifier = await _buildNotifier(mockRepo);
      await notifier.add(_playlist(id: 'p1'));

      await notifier.remove('p1');

      expect(notifier.state.any((p) => p.id == 'p1'), isFalse);
    });

    test('throws and leaves state unchanged when repository throws', () async {
      when(() => mockRepo.deletePlaylist(any()))
          .thenThrow(Exception('network error'));
      final notifier = await _buildNotifier(mockRepo);
      await notifier.add(_playlist(id: 'p1'));

      await expectLater(() => notifier.remove('p1'), throwsException);

      expect(notifier.state.any((p) => p.id == 'p1'), isTrue);
    });
  });

  // ── updateVisibility ──────────────────────────────────────────────────────

  group('PlaylistNotifier — updateVisibility', () {
    test('calls repository.updatePrivacy with correct id and isPublic', () async {
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });
      final notifier = await _buildNotifier(mockRepo);
      await notifier.add(_playlist(id: 'p1', isPublic: true));

      await notifier.updateVisibility('p1', false);

      verify(() => mockRepo.updatePrivacy('p1', false)).called(1);
    });

    test('flips isPublic in state after success', () async {
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });
      final notifier = await _buildNotifier(mockRepo);
      await notifier.add(_playlist(id: 'p1', isPublic: true));

      await notifier.updateVisibility('p1', false);

      final updated = notifier.state.firstWhere((p) => p.id == 'p1');
      expect(updated.isPublic, isFalse);
    });

    test('throws and leaves isPublic unchanged when repository throws', () async {
      when(() => mockRepo.updatePrivacy(any(), any()))
          .thenThrow(Exception('network error'));
      final notifier = await _buildNotifier(mockRepo);
      await notifier.add(_playlist(id: 'p1', isPublic: true));

      await expectLater(
          () => notifier.updateVisibility('p1', false), throwsException);

      final unchanged = notifier.state.firstWhere((p) => p.id == 'p1');
      expect(unchanged.isPublic, isTrue);
    });

    test('does not affect other playlists in state', () async {
      when(() => mockRepo.updatePrivacy(any(), any())).thenAnswer((_) async {
        return null;
      });
      final notifier = await _buildNotifier(mockRepo);
      await notifier.add(_playlist(id: 'p1', isPublic: true));
      await notifier.add(_playlist(id: 'p2', isPublic: true));

      await notifier.updateVisibility('p1', false);

      final other = notifier.state.firstWhere((p) => p.id == 'p2');
      expect(other.isPublic, isTrue);
    });
  });
}
