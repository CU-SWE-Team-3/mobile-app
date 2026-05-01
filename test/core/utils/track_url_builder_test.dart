import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/core/utils/track_url_builder.dart';

void main() {
  group('buildTrackUrl', () {
    test('uses BioBeats artist and track permalinks when available', () {
      expect(
        buildTrackUrl(
          trackId: 'track-123',
          artistPermalink: 'ziad-awad-1',
          trackPermalink: 'aslaha-btefr2',
        ),
        'biobeats://open/ziad-awad-1/aslaha-btefr2',
      );
    });

    test('falls back to BioBeats track id URL', () {
      expect(
        buildTrackUrl(trackId: 'track-123'),
        'biobeats://open/tracks/track-123',
      );
    });
  });
}
