import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/core/utils/waveform_parser.dart';

void main() {
  // ── parseWaveform ──────────────────────────────────────────────────────────

  group('parseWaveform', () {
    group('null / empty input', () {
      test('returns null for null input', () {
        expect(parseWaveform(null), isNull);
      });

      test('returns null for empty list', () {
        expect(parseWaveform([]), isNull);
      });

      test('returns null for empty map', () {
        expect(parseWaveform({}), isNull);
      });

      test('returns null for empty string', () {
        expect(parseWaveform(''), isNull);
      });
    });

    group('list of integers', () {
      test('normalises values already in 0-100 range and clamps', () {
        final result = parseWaveform([0, 50, 100]);
        expect(result, isNotNull);
        expect(result!.every((v) => v >= 0 && v <= 100), isTrue);
      });

      test('returns correct length for int list', () {
        final input = List.generate(200, (i) => i % 100);
        final result = parseWaveform(input);
        expect(result, hasLength(200));
      });

      test('negative values are treated as absolute', () {
        final result = parseWaveform([-50, -100]);
        expect(result, isNotNull);
        // Absolute values should be non-negative after normalisation
        expect(result!.every((v) => v >= 0), isTrue);
      });

      test('all-zero list returns list of zeros', () {
        final result = parseWaveform([0, 0, 0]);
        expect(result, isNotNull);
        expect(result!.every((v) => v == 0), isTrue);
      });

      test('large values are scaled down to 0-100', () {
        final result = parseWaveform([500, 1000, 750]);
        expect(result, isNotNull);
        expect(result!.every((v) => v >= 0 && v <= 100), isTrue);
      });

      test('values already in 0-1 float range scale up to 0-100', () {
        final result = parseWaveform([0.0, 0.5, 1.0]);
        expect(result, isNotNull);
        expect(result!.every((v) => v >= 0 && v <= 100), isTrue);
      });
    });

    group('string input', () {
      test('parses space-separated integers from string', () {
        final result = parseWaveform('10 20 30 40 50');
        expect(result, isNotNull);
        expect(result!.length, greaterThan(0));
      });

      test('parses comma-separated numbers', () {
        final result = parseWaveform('10,20,30');
        expect(result, isNotNull);
        expect(result!.length, greaterThan(0));
      });

      test('returns null for purely non-numeric string', () {
        final result = parseWaveform('no-numbers-here');
        expect(result, isNull);
      });
    });

    group('map input with known keys', () {
      test('parses "waveform" key', () {
        final result = parseWaveform({'waveform': [10, 20, 30]});
        expect(result, isNotNull);
        expect(result!.length, 3);
      });

      test('parses "peaks" key', () {
        final result = parseWaveform({'peaks': [5, 15, 25]});
        expect(result, isNotNull);
      });

      test('parses "samples" key', () {
        final result = parseWaveform({'samples': [1, 2, 3]});
        expect(result, isNotNull);
      });

      test('parses "amplitudes" key', () {
        final result = parseWaveform({'amplitudes': [20, 40, 60]});
        expect(result, isNotNull);
      });

      test('parses numerically-keyed map in order', () {
        final result = parseWaveform({'0': 10, '1': 20, '2': 30});
        expect(result, isNotNull);
        expect(result!.length, 3);
      });
    });

    group('output range invariant', () {
      test('all output values are clamped to 0-100 for any valid input', () {
        final inputs = [
          [0, 255, 128],
          [1.0, 0.5, 0.25],
          {'peaks': [1000, 2000, 500]},
          '100 200 300',
        ];
        for (final input in inputs) {
          final result = parseWaveform(input);
          if (result != null) {
            expect(result.every((v) => v >= 0 && v <= 100), isTrue,
                reason: 'Failed for input: $input');
          }
        }
      });
    });
  });

  // ── parseWaveformFromMap ───────────────────────────────────────────────────

  group('parseWaveformFromMap', () {
    test('extracts waveform from top-level "waveform" key', () {
      final result = parseWaveformFromMap({'waveform': [10, 50, 90]});
      expect(result, isNotNull);
      expect(result!.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('extracts waveform from top-level "peaks" key', () {
      final result = parseWaveformFromMap({'peaks': [20, 40, 60]});
      expect(result, isNotNull);
    });

    test('extracts waveform from top-level "bars" key', () {
      final result = parseWaveformFromMap({'bars': [5, 50, 95]});
      expect(result, isNotNull);
    });

    test('finds waveform nested inside "audio" map', () {
      final result = parseWaveformFromMap({
        'audio': {'waveform': [10, 20, 30]}
      });
      expect(result, isNotNull);
    });

    test('finds waveform nested inside "metadata" map', () {
      final result = parseWaveformFromMap({
        'metadata': {'peaks': [5, 10, 15]}
      });
      expect(result, isNotNull);
    });

    test('finds waveform nested inside "analysis" map', () {
      final result = parseWaveformFromMap({
        'analysis': {'waveformData': [1, 2, 3]}
      });
      expect(result, isNotNull);
    });

    test('returns null when no recognised key present', () {
      final result = parseWaveformFromMap({'title': 'Song', 'artist': 'A'});
      expect(result, isNull);
    });

    test('returns null for empty map', () {
      final result = parseWaveformFromMap({});
      expect(result, isNull);
    });

    test('returns null when waveform key exists but is empty list', () {
      final result = parseWaveformFromMap({'waveform': []});
      expect(result, isNull);
    });

    test('all returned values are in 0-100 range', () {
      final result = parseWaveformFromMap({'waveformPeaks': [1000, 500, 250]});
      if (result != null) {
        expect(result.every((v) => v >= 0 && v <= 100), isTrue);
      }
    });

    test('prefers top-level waveform key over nested', () {
      final result = parseWaveformFromMap({
        'waveform': [10, 20],
        'audio': {'waveform': [30, 40, 50]},
      });
      expect(result, isNotNull);
      // Top-level key has 2 elements, nested has 3 — top-level wins
      expect(result!.length, 2);
    });
  });
}
