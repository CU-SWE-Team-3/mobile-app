import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/feed/presentation/providers/feed_provider.dart';
import 'package:soundcloud_clone/features/feed/data/services/resource_resolver_service.dart';
import 'package:soundcloud_clone/core/utils/relative_time.dart';

void main() {
  // ── FeedState ─────────────────────────────────────────────────────────────

  group('FeedState', () {
    group('default values', () {
      test('initial state has correct defaults', () {
        const state = FeedState();
        expect(state.tracks, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.isLoadingMore, isFalse);
        expect(state.hasMore, isFalse);
        expect(state.nextCursor, isNull);
        expect(state.error, isNull);
      });
    });

    group('copyWith', () {
      test('isLoading flag updates correctly', () {
        const state = FeedState();
        final loading = state.copyWith(isLoading: true);
        expect(loading.isLoading, isTrue);
        expect(loading.tracks, isEmpty); // unchanged
      });

      test('isLoadingMore flag updates correctly', () {
        const state = FeedState();
        final paging = state.copyWith(isLoadingMore: true);
        expect(paging.isLoadingMore, isTrue);
      });

      test('hasMore updates correctly', () {
        const state = FeedState();
        expect(state.hasMore, isFalse);
        final hasMore = state.copyWith(hasMore: true);
        expect(hasMore.hasMore, isTrue);
      });

      test('nextCursor can be set', () {
        const state = FeedState();
        final withCursor = state.copyWith(nextCursor: 'cursor-abc');
        expect(withCursor.nextCursor, 'cursor-abc');
      });

      test('clearNextCursor=true sets nextCursor to null', () {
        const state = FeedState(nextCursor: 'existing-cursor');
        final cleared = state.copyWith(clearNextCursor: true);
        expect(cleared.nextCursor, isNull);
      });

      test('clearError=true sets error to null', () {
        const state = FeedState(error: 'Some error');
        final cleared = state.copyWith(clearError: true);
        expect(cleared.error, isNull);
      });

      test('error can be set', () {
        const state = FeedState();
        final withError = state.copyWith(error: 'Network error');
        expect(withError.error, 'Network error');
      });

      test('tracks can be replaced', () {
        const state = FeedState();
        final tracks = [
          const FeedTrack(id: 'id1', title: 'T1', artistId: 'a1', artistName: 'Alice'),
        ];
        final updated = state.copyWith(tracks: tracks);
        expect(updated.tracks, hasLength(1));
        expect(updated.tracks.first.title, 'T1');
      });

      test('unchanged fields are preserved across copyWith', () {
        final state = FeedState(
          tracks: [const FeedTrack(id: 'id1', title: 'T', artistId: 'a', artistName: 'A')],
          hasMore: true,
          nextCursor: 'cursor',
        );
        final updated = state.copyWith(isLoading: false);
        expect(updated.tracks, hasLength(1));
        expect(updated.hasMore, isTrue);
        expect(updated.nextCursor, 'cursor');
      });
    });
  });

  // ── ParsedResourceLink ────────────────────────────────────────────────────

  group('ParsedResourceLink', () {
    group('user links (single segment)', () {
      test('single-segment path resolves to user', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://biobeats.duckdns.org/some-artist'));
        expect(parsed.kind, ResourceLinkKind.user);
        expect(parsed.userPermalink, 'some-artist');
      });

      test('@ prefix in first segment is stripped', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/@cool-artist'));
        expect(parsed.kind, ResourceLinkKind.user);
        expect(parsed.userPermalink, 'cool-artist');
      });
    });

    group('track links', () {
      test('two-segment path resolves to track', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/artist-name/my-track'));
        expect(parsed.kind, ResourceLinkKind.track);
        expect(parsed.userPermalink, 'artist-name');
        expect(parsed.trackPermalink, 'my-track');
      });

      test('/tracks/{permalink} resolves to track', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/tracks/specific-track'));
        expect(parsed.kind, ResourceLinkKind.track);
        expect(parsed.trackPermalink, 'specific-track');
      });
    });

    group('playlist by id', () {
      test('/playlists/{id} resolves to playlistById', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/playlists/pl-id-123'));
        expect(parsed.kind, ResourceLinkKind.playlistById);
        expect(parsed.playlistId, 'pl-id-123');
      });

      test('secretToken query param is captured', () {
        final parsed = ParsedResourceLink.parse(
          Uri.parse('https://example.com/playlists/pl-123?secretToken=abc'),
        );
        expect(parsed.kind, ResourceLinkKind.playlistById);
        expect(parsed.secretToken, 'abc');
      });

      test('secret_token query param alias is captured', () {
        final parsed = ParsedResourceLink.parse(
          Uri.parse('https://example.com/playlists/pl-123?secret_token=xyz'),
        );
        expect(parsed.secretToken, 'xyz');
      });
    });

    group('playlist by permalink', () {
      test('{user}/sets/{playlist} resolves to playlistByPermalink', () {
        final parsed = ParsedResourceLink.parse(
          Uri.parse('https://example.com/artist/sets/my-playlist'),
        );
        expect(parsed.kind, ResourceLinkKind.playlistByPermalink);
        expect(parsed.userPermalink, 'artist');
        expect(parsed.playlistPermalink, 'my-playlist');
      });

      test('secretToken included in playlistByPermalink', () {
        final parsed = ParsedResourceLink.parse(
          Uri.parse('https://example.com/artist/sets/secret-set?secretToken=tok'),
        );
        expect(parsed.kind, ResourceLinkKind.playlistByPermalink);
        expect(parsed.secretToken, 'tok');
      });
    });

    group('reserved/unknown paths', () {
      test('empty path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });

      test('reserved "login" path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/login'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });

      test('reserved "register" path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/register'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });

      test('reserved "verify-email" path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/verify-email/token'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });

      test('reserved "reset-password" path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/reset-password'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });

      test('reserved "payment-success" path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/payment-success'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });

      test('reserved "splash" path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/splash'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });

      test('reserved "google" path resolves to unknown', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/google'));
        expect(parsed.kind, ResourceLinkKind.unknown);
      });
    });

    group('secretToken absent', () {
      test('secretToken is null when not in query params', () {
        final parsed = ParsedResourceLink.parse(Uri.parse('https://example.com/playlists/pl-1'));
        expect(parsed.secretToken, isNull);
      });
    });
  });

  // ── ResourceResolution constructors ───────────────────────────────────────

  group('ResourceResolution', () {
    test('user factory sets kind and userPermalink', () {
      const r = ResourceResolution.user(permalink: 'my-user');
      expect(r.kind, ResolvedResourceKind.user);
      expect(r.userPermalink, 'my-user');
    });

    test('track factory sets kind and required fields', () {
      const r = ResourceResolution.track(
        trackId: 'tid',
        title: 'Song',
        artworkUrl: null,
        durationSeconds: 180,
        trackPermalink: 'song',
        artistId: 'aid',
        artistName: 'Artist',
        artistPermalink: null,
      );
      expect(r.kind, ResolvedResourceKind.track);
      expect(r.trackId, 'tid');
      expect(r.title, 'Song');
      expect(r.durationSeconds, 180);
      expect(r.trackPermalink, 'song');
    });

    test('playlist factory sets kind, playlistId, and secretToken', () {
      const r = ResourceResolution.playlist(playlistId: 'pid', secretToken: 'tok');
      expect(r.kind, ResolvedResourceKind.playlist);
      expect(r.playlistId, 'pid');
      expect(r.secretToken, 'tok');
    });

    test('ignored factory sets kind to ignored', () {
      const r = ResourceResolution.ignored();
      expect(r.kind, ResolvedResourceKind.ignored);
    });

    test('notFound factory sets kind and message', () {
      const r = ResourceResolution.notFound(message: 'Not found');
      expect(r.kind, ResolvedResourceKind.notFound);
      expect(r.message, 'Not found');
    });
  });

  // ── formatRelativeTime ─────────────────────────────────────────────────────

  group('formatRelativeTime', () {
    test('returns "now" for time within the last minute', () {
      final recent = DateTime.now().subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(recent), 'now');
    });

    test('returns minutes for time 1-59 minutes ago', () {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(fiveMinutesAgo), '5m');
    });

    test('returns hours for time 1-23 hours ago', () {
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      expect(formatRelativeTime(twoHoursAgo), '2h');
    });

    test('returns days for time 1+ days ago', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      expect(formatRelativeTime(threeDaysAgo), '3d');
    });

    test('boundary: exactly 60 seconds returns minutes format', () {
      final exactlyOneMinute = DateTime.now().subtract(const Duration(seconds: 60));
      // inSeconds >= 60 => falls into minutes bucket
      final result = formatRelativeTime(exactlyOneMinute);
      expect(result, '1m');
    });

    test('boundary: exactly 60 minutes returns hours format', () {
      final exactlyOneHour = DateTime.now().subtract(const Duration(minutes: 60));
      final result = formatRelativeTime(exactlyOneHour);
      expect(result, '1h');
    });

    test('boundary: exactly 24 hours returns days format', () {
      final exactlyOneDay = DateTime.now().subtract(const Duration(hours: 24));
      final result = formatRelativeTime(exactlyOneDay);
      expect(result, '1d');
    });
  });
}
