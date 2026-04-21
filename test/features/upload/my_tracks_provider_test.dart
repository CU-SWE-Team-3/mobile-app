// test/features/upload/my_tracks_provider_test.dart
//
// Unit tests for myTracksProvider JSON parsing — verifies that GET /tracks/my-tracks
// responses are correctly mapped to UploadTrack domain objects.
//
// myTracksProvider is a FutureProvider that uses dioClientProvider.
// We override dioClientProvider in a ProviderContainer to inject a MockDioClient
// so the real network is never called.
//
// Covers:
//   • string artist field (displayName from object)
//   • artist as plain string (fallback path)
//   • waveform list parsed to List<int>
//   • isPublic defaults to true when absent from response
//   • nullable hlsUrl / artworkUrl
//   • duration field
//   • genre and description fields
//   • empty data list returns empty result
//   • non-list data returns empty result
//
// Run with:
//   flutter test test/features/upload/my_tracks_provider_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/core/network/dio_client.dart';
import 'package:soundcloud_clone/features/library/presentation/providers/my_tracks_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockDioClient extends Mock implements DioClient {}

class MockDio extends Mock implements Dio {}

// ── Helpers ──────────────────────────────────────────────────────────────────

Response<dynamic> ok(dynamic data) => Response(
      requestOptions: RequestOptions(path: '/tracks/my-tracks'),
      statusCode: 200,
      data: data,
    );

/// A minimal valid track JSON object (all required keys present).
Map<String, dynamic> trackJson({
  String id = 'track-id-1',
  String title = 'My Track',
  dynamic artist = 'Artist Name',
  String? hlsUrl,
  String? artworkUrl,
  List<int>? waveform,
  bool? isPublic,
  int? duration,
  String? genre,
  String? description,
}) =>
    {
      '_id': id,
      'title': title,
      'artist': artist,
      if (hlsUrl != null) 'hlsUrl': hlsUrl,
      if (artworkUrl != null) 'artworkUrl': artworkUrl,
      if (waveform != null) 'waveform': waveform,
      if (isPublic != null) 'isPublic': isPublic,
      if (duration != null) 'duration': duration,
      if (genre != null) 'genre': genre,
      if (description != null) 'description': description,
    };

/// Builds a ProviderContainer with dioClientProvider overridden by [mockDioClient].
ProviderContainer buildContainer(MockDioClient mockDioClient) {
  return ProviderContainer(overrides: [
    dioClientProvider.overrideWithValue(mockDioClient),
  ]);
}

void main() {
  late MockDioClient mockDioClient;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    mockDioClient = MockDioClient();
    when(() => mockDioClient.dio).thenReturn(mockDio);
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: ''));
  });

  // ── Empty / non-list responses ────────────────────────────────────────────

  group('myTracksProvider — empty / non-list responses', () {
    test('returns empty list when data is an empty list', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({'data': []}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks, isEmpty);
    });

    test('returns empty list when data key is not a list', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({'data': 'unexpected string'}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks, isEmpty);
    });

    test('returns empty list when data key is null', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({'data': null}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks, isEmpty);
    });
  });

  // ── Basic field parsing ───────────────────────────────────────────────────

  group('myTracksProvider — basic field parsing', () {
    test('parses _id into track.id', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(id: 'abc-123')]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.id, 'abc-123');
    });

    test('parses title', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(title: 'Sunset Drive')]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.title, 'Sunset Drive');
    });

    test('parses hlsUrl', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(hlsUrl: 'https://cdn/t.m3u8')]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.hlsUrl, 'https://cdn/t.m3u8');
    });

    test('hlsUrl is null when absent', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({'data': [trackJson()]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.hlsUrl, isNull);
    });

    test('parses artworkUrl', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(artworkUrl: 'https://cdn/art.jpg')]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.artworkUrl, 'https://cdn/art.jpg');
    });

    test('artworkUrl is null when absent', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({'data': [trackJson()]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.artworkUrl, isNull);
    });

    test('parses genre', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(genre: 'Electronic')]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.genre, 'Electronic');
    });

    test('parses description', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(description: 'A great track')]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.description, 'A great track');
    });

    test('parses duration', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(duration: 240)]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.duration, 240);
    });
  });

  // ── Artist field parsing ──────────────────────────────────────────────────

  group('myTracksProvider — artist field parsing', () {
    test('reads displayName from artist object', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({
                'data': [
                  trackJson(artist: {'_id': 'u1', 'displayName': 'Ziad Awad'})
                ]
              }));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.artist, 'Ziad Awad');
    });

    test('returns empty string when artist object has no displayName', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({
                'data': [
                  trackJson(artist: {'_id': 'u1'}) // no displayName key
                ]
              }));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.artist, '');
    });

    test('returns empty string when artist is a plain string (non-Map)', () async {
      // myTracksProvider: artist is only read when it is a Map
      // When artist is a string the condition `t['artist'] is Map` is false → ''
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({
                'data': [trackJson(artist: 'Khaled Mostafa')]
              }));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      // The provider only reads displayName from Map artist; plain string → ''
      expect(tracks.first.artist, '');
    });
  });

  // ── Waveform parsing ──────────────────────────────────────────────────────

  group('myTracksProvider — waveform parsing', () {
    test('parses waveform list to List<int>', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({
                'data': [
                  trackJson(waveform: [0, 64, 128, 192, 255])
                ]
              }));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.waveform, [0, 64, 128, 192, 255]);
    });

    test('waveform is null when absent', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({'data': [trackJson()]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.waveform, isNull);
    });

    test('parses waveform with single element', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({
                'data': [trackJson(waveform: [42])]
              }));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.waveform!.length, 1);
      expect(tracks.first.waveform!.first, 42);
    });
  });

  // ── isPublic field ────────────────────────────────────────────────────────

  group('myTracksProvider — isPublic field', () {
    test('defaults to true when isPublic absent', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({'data': [trackJson()]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.isPublic, isTrue);
    });

    test('parses isPublic: false', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(isPublic: false)]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.isPublic, isFalse);
    });

    test('parses isPublic: true explicitly', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async =>
              ok({'data': [trackJson(isPublic: true)]}));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.first.isPublic, isTrue);
    });
  });

  // ── Multiple tracks ───────────────────────────────────────────────────────

  group('myTracksProvider — multiple tracks', () {
    test('parses list of two tracks correctly', () async {
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({
                'data': [
                  trackJson(id: 't1', title: 'First'),
                  trackJson(id: 't2', title: 'Second'),
                ]
              }));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.length, 2);
      expect(tracks[0].id, 't1');
      expect(tracks[1].id, 't2');
    });

    test('preserves order of tracks as returned by server', () async {
      final ids = ['z', 'a', 'm'];
      when(() => mockDio.get('/tracks/my-tracks'))
          .thenAnswer((_) async => ok({
                'data': ids.map((id) => trackJson(id: id)).toList(),
              }));

      final container = buildContainer(mockDioClient);
      addTearDown(container.dispose);

      final tracks = await container.read(myTracksProvider.future);
      expect(tracks.map((t) => t.id).toList(), ids);
    });
  });
}
