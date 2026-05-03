import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/core/utils/track_url_builder.dart';

void main() {
  const base = 'https://biobeats.duckdns.org';

  group('buildTrackUrl', () {
    group('using trackPermalink when provided', () {
      test('builds URL using trackPermalink over trackId', () {
        final url = buildTrackUrl(
          trackId: 'abc123',
          trackPermalink: 'my-awesome-song',
        );
        expect(url, '$base/tracks/my-awesome-song');
      });

      test('uses trackPermalink with whitespace trimmed', () {
        final url = buildTrackUrl(
          trackId: 'abc123',
          trackPermalink: '  cool-track  ',
        );
        expect(url, '$base/tracks/cool-track');
      });

      test('falls back to trackId when trackPermalink is empty string', () {
        final url = buildTrackUrl(
          trackId: 'fallback-id',
          trackPermalink: '',
        );
        expect(url, '$base/tracks/fallback-id');
      });

      test('falls back to trackId when trackPermalink is whitespace only', () {
        final url = buildTrackUrl(
          trackId: 'fallback-id',
          trackPermalink: '   ',
        );
        expect(url, '$base/tracks/fallback-id');
      });

      test('falls back to trackId when trackPermalink is null', () {
        final url = buildTrackUrl(trackId: 'fallback-id');
        expect(url, '$base/tracks/fallback-id');
      });
    });

    group('using trackId as fallback', () {
      test('builds URL using trackId when no permalink supplied', () {
        final url = buildTrackUrl(trackId: 'id-only');
        expect(url, '$base/tracks/id-only');
      });

      test('trackId is trimmed before use', () {
        final url = buildTrackUrl(trackId: '  spaced-id  ');
        expect(url, '$base/tracks/spaced-id');
      });
    });

    group('artistPermalink is ignored (not part of URL)', () {
      test('artistPermalink does not appear in the returned URL', () {
        final url = buildTrackUrl(
          trackId: 'track-id',
          artistPermalink: 'some-artist',
          trackPermalink: 'some-track',
        );
        expect(url.contains('some-artist'), isFalse);
        expect(url, '$base/tracks/some-track');
      });
    });

    group('URL structure', () {
      test('always starts with the correct base URL', () {
        final url = buildTrackUrl(trackId: 'any-id');
        expect(url.startsWith(base), isTrue);
      });

      test('always contains /tracks/ path segment', () {
        final url = buildTrackUrl(trackId: 'any-id');
        expect(url.contains('/tracks/'), isTrue);
      });

      test('returns valid URI that can be parsed without error', () {
        final url = buildTrackUrl(
          trackId: 'track-123',
          trackPermalink: 'my-song',
        );
        expect(() => Uri.parse(url), returnsNormally);
      });

      test('produced URI has correct path segments', () {
        final url = buildTrackUrl(
          trackId: 'id',
          trackPermalink: 'slug',
        );
        final uri = Uri.parse(url);
        expect(uri.pathSegments, ['tracks', 'slug']);
      });

      test('produced URI has correct host', () {
        final url = buildTrackUrl(trackId: 'id');
        final uri = Uri.parse(url);
        expect(uri.host, 'biobeats.duckdns.org');
      });

      test('produced URI uses HTTPS scheme', () {
        final url = buildTrackUrl(trackId: 'id');
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https');
      });
    });

    group('special characters in ids', () {
      test('URL-safe permalink passes through correctly', () {
        final url = buildTrackUrl(trackId: 'id', trackPermalink: 'track-2024');
        expect(url, '$base/tracks/track-2024');
      });
    });
  });
}
