import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/feed/data/services/resource_resolver_service.dart';

void main() {
  group('ParsedResourceLink', () {
    test('parses BioBeats artist track share URLs as track links', () {
      final parsed = ParsedResourceLink.parse(
        Uri.parse('https://biobeats.duckdns.org/ziad-awad-1/aslaha-btefr2'),
      );

      expect(parsed.kind, ResourceLinkKind.track);
      expect(parsed.userPermalink, 'ziad-awad-1');
      expect(parsed.trackPermalink, 'aslaha-btefr2');
    });

    test('parses BioBeats custom app track URLs as track links', () {
      final parsed = ParsedResourceLink.parse(
        Uri.parse('biobeats://open/ziad-awad-1/aslaha-btefr2'),
      );

      expect(parsed.kind, ResourceLinkKind.track);
      expect(parsed.userPermalink, 'ziad-awad-1');
      expect(parsed.trackPermalink, 'aslaha-btefr2');
    });

    test('parses BioBeats track id fallback URLs as track links', () {
      final parsed = ParsedResourceLink.parse(
        Uri.parse('biobeats://open/tracks/track-123'),
      );

      expect(parsed.kind, ResourceLinkKind.track);
      expect(parsed.trackPermalink, 'track-123');
    });
  });
}
