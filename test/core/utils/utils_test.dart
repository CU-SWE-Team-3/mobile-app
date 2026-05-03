import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/core/utils/relative_time.dart';
import 'package:soundcloud_clone/core/utils/track_url_builder.dart';
import 'package:soundcloud_clone/core/utils/waveform_parser.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// formatRelativeTime
// ═══════════════════════════════════════════════════════════════════════════════
void main() {
  group('formatRelativeTime', () {
    DateTime _ago(Duration d) => DateTime.now().subtract(d);

    test('returns "now" when difference is less than 60 seconds', () {
      expect(formatRelativeTime(_ago(const Duration(seconds: 30))), 'now');
    });

    test('returns "now" for exactly 0 seconds', () {
      expect(formatRelativeTime(DateTime.now()), 'now');
    });

    test('returns minutes string when difference is 60s to 59m', () {
      final result = formatRelativeTime(_ago(const Duration(minutes: 5)));
      expect(result, '5m');
    });

    test('returns 1m for exactly 1 minute', () {
      expect(formatRelativeTime(_ago(const Duration(minutes: 1))), '1m');
    });

    test('returns 59m for 59 minutes', () {
      expect(formatRelativeTime(_ago(const Duration(minutes: 59))), '59m');
    });

    test('returns hours string when difference is 1h to 23h', () {
      final result = formatRelativeTime(_ago(const Duration(hours: 3)));
      expect(result, '3h');
    });

    test('returns 1h for exactly 1 hour', () {
      expect(formatRelativeTime(_ago(const Duration(hours: 1))), '1h');
    });

    test('returns 23h for 23 hours', () {
      expect(formatRelativeTime(_ago(const Duration(hours: 23))), '23h');
    });

    test('returns days string when difference is >= 24h', () {
      final result = formatRelativeTime(_ago(const Duration(days: 2)));
      expect(result, '2d');
    });

    test('returns 1d for exactly 1 day', () {
      expect(formatRelativeTime(_ago(const Duration(days: 1))), '1d');
    });

    test('returns large day count for very old datetime', () {
      final result = formatRelativeTime(_ago(const Duration(days: 365)));
      expect(result, '365d');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // buildTrackUrl
  // ═══════════════════════════════════════════════════════════════════════════
  group('buildTrackUrl', () {
    const base = 'https://biobeats.duckdns.org';

    test('builds URL using trackPermalink when provided', () {
      final url = buildTrackUrl(
        trackId: 'id_001',
        trackPermalink: 'my-awesome-track',
      );
      expect(url, '$base/tracks/my-awesome-track');
    });

    test('falls back to trackId when trackPermalink is null', () {
      final url = buildTrackUrl(trackId: 'id_001');
      expect(url, '$base/tracks/id_001');
    });

    test('falls back to trackId when trackPermalink is empty string', () {
      final url = buildTrackUrl(trackId: 'id_002', trackPermalink: '');
      expect(url, '$base/tracks/id_002');
    });

    test('falls back to trackId when trackPermalink is whitespace only', () {
      final url = buildTrackUrl(trackId: 'id_003', trackPermalink: '   ');
      expect(url, '$base/tracks/id_003');
    });

    test('strips whitespace from trackPermalink', () {
      final url =
          buildTrackUrl(trackId: 'id_004', trackPermalink: '  trimmed-track  ');
      expect(url, '$base/tracks/trimmed-track');
    });

    test('URL starts with the base domain', () {
      final url = buildTrackUrl(trackId: 'any_id');
      expect(url, startsWith(base));
    });

    test('URL contains /tracks/ path segment', () {
      final url = buildTrackUrl(trackId: 'track_999');
      expect(url, contains('/tracks/'));
    });

    test('ignores artistPermalink (not used in URL construction)', () {
      final withArtist = buildTrackUrl(
        trackId: 'id_005',
        artistPermalink: 'artist-name',
        trackPermalink: 'track-name',
      );
      final withoutArtist =
          buildTrackUrl(trackId: 'id_005', trackPermalink: 'track-name');
      expect(withArtist, withoutArtist);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // parseWaveform
  // ═══════════════════════════════════════════════════════════════════════════
  group('parseWaveform', () {
    test('returns null for null input', () {
      expect(parseWaveform(null), isNull);
    });

    test('returns null for empty list', () {
      expect(parseWaveform([]), isNull);
    });

    test('parses a simple list of ints and normalizes to 0–100', () {
      final result = parseWaveform([10, 50, 100]);
      expect(result, isNotNull);
      expect(result!.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('parses a list of doubles', () {
      final result = parseWaveform([0.1, 0.5, 0.9]);
      expect(result, isNotNull);
      expect(result!.length, 3);
    });

    test('handles negative values by taking absolute value', () {
      final result = parseWaveform([-10, -50, 100]);
      expect(result, isNotNull);
      expect(result!.every((v) => v >= 0), isTrue);
    });

    test('scales values > 100 down proportionally', () {
      final result = parseWaveform([0, 500, 1000]);
      expect(result, isNotNull);
      // max is 1000, so 1000 maps to 100
      expect(result!.last, 100);
    });

    test('values already in 0-1 range are scaled to 0-100', () {
      final result = parseWaveform([0.0, 0.5, 1.0]);
      expect(result, isNotNull);
      expect(result!.last, 100);
    });

    test('clamps output values to 0–100', () {
      final result = parseWaveform([0, 50, 200]);
      expect(result, isNotNull);
      expect(result!.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('parses waveform from a string of numbers', () {
      final result = parseWaveform('10,50,100');
      expect(result, isNotNull);
      expect(result!.length, 3);
    });

    test('returns null for a string with no numbers', () {
      expect(parseWaveform('no numbers here'), isNull);
    });

    test('parses from a Map with a "waveform" key', () {
      final result = parseWaveform({
        'waveform': [10, 20, 30]
      });
      expect(result, isNotNull);
      expect(result!.length, 3);
    });

    test('parses from a Map with a "peaks" key', () {
      final result = parseWaveform({
        'peaks': [5, 50, 90]
      });
      expect(result, isNotNull);
    });

    test('parses from a Map with a "samples" key', () {
      final result = parseWaveform({
        'samples': [1, 2, 3]
      });
      expect(result, isNotNull);
    });

    test('returns null for unsupported type (bool)', () {
      expect(parseWaveform(true), isNull);
    });

    test('output list length matches input length', () {
      final input = [10, 20, 30, 40, 50];
      final result = parseWaveform(input);
      expect(result!.length, 5);
    });

    test('single-element list is parseable', () {
      final result = parseWaveform([42]);
      expect(result, isNotNull);
      expect(result!.length, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // parseWaveformFromMap
  // ═══════════════════════════════════════════════════════════════════════════
  group('parseWaveformFromMap', () {
    test('extracts waveform from "waveform" key', () {
      final result = parseWaveformFromMap({
        'waveform': [10, 50, 90]
      });
      expect(result, isNotNull);
      expect(result!.length, 3);
    });

    test('extracts waveform from "waveformData" key', () {
      final result = parseWaveformFromMap({
        'waveformData': [20, 40, 60]
      });
      expect(result, isNotNull);
    });

    test('extracts waveform from "peaks" key', () {
      final result = parseWaveformFromMap({
        'peaks': [5, 25, 75]
      });
      expect(result, isNotNull);
    });

    test('extracts waveform from "bars" key', () {
      final result = parseWaveformFromMap({
        'bars': [10, 30, 70]
      });
      expect(result, isNotNull);
    });

    test('searches nested "audio" map for waveform', () {
      final result = parseWaveformFromMap({
        'audio': {
          'waveform': [1, 2, 3]
        },
      });
      expect(result, isNotNull);
    });

    test('searches nested "metadata" map for waveform', () {
      final result = parseWaveformFromMap({
        'metadata': {
          'peaks': [10, 20]
        },
      });
      expect(result, isNotNull);
    });

    test('returns null when map has no recognizable waveform keys', () {
      final result = parseWaveformFromMap({'unrelated': 'data'});
      expect(result, isNull);
    });

    test('returns null for empty map', () {
      final result = parseWaveformFromMap({});
      expect(result, isNull);
    });

    test('returns null when waveform list is empty', () {
      final result = parseWaveformFromMap({'waveform': []});
      expect(result, isNull);
    });

    test('prefers top-level keys over nested ones', () {
      // Top-level "waveform" should be found before nested "audio.waveform"
      final result = parseWaveformFromMap({
        'waveform': [10, 20],
        'audio': {
          'waveform': [99, 88]
        },
      });
      expect(result, isNotNull);
      expect(result!.length, 2);
    });
  });
}
