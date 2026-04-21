// test/features/player/player_api_service_test.dart
//
// Unit tests for PlayerApiService — verifies that each method calls the
// correct Dio verb + path with the right body, and that response shapes
// (including all key variants) are parsed into the right domain objects.
// All methods that are fire-and-forget (sync, reportProgress, clear) are
// confirmed to swallow exceptions rather than propagate them.
//
// Run with:
//   flutter test test/features/player/player_api_service_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/features/player/data/services/player_api_service.dart';

class MockDio extends Mock implements Dio {}

// ── Helpers ──────────────────────────────────────────────────────────────────

Response<dynamic> ok(dynamic data, {String path = ''}) => Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data,
    );

DioException dioErr({String path = ''}) => DioException(
      requestOptions: RequestOptions(path: path),
    );

// A minimal valid recently-played entry (all required keys present)
Map<String, dynamic> entryJson({
  String id = 't1',
  String title = 'Track One',
  String artist = 'Artist A',
  String audioUrl = 'https://cdn/t1.m3u8',
  String? playedAt,
}) =>
    <String, dynamic>{
      'track': <String, dynamic>{
        '_id': id,
        'title': title,
        'artist': artist,
        'hlsUrl': audioUrl,
      },
      'playedAt': playedAt ?? '2024-06-01T10:00:00.000Z',
    };

void main() {
  late MockDio mockDio;
  late PlayerApiService service;

  setUp(() {
    mockDio = MockDio();
    service = PlayerApiService(mockDio);
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: ''));
  });

  // ── getStreamUrl ─────────────────────────────────────────────────────────

  group('getStreamUrl', () {
    test('returns streamUrl from nested data object', () async {
      when(() => mockDio.get('/player/t1/stream')).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{'streamUrl': 'https://cdn/stream.m3u8'}
              }));

      expect(await service.getStreamUrl('t1'), 'https://cdn/stream.m3u8');
    });

    test('returns url key when streamUrl is absent', () async {
      when(() => mockDio.get('/player/t1/stream')).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{'url': 'https://cdn/fallback.m3u8'}
              }));

      expect(await service.getStreamUrl('t1'), 'https://cdn/fallback.m3u8');
    });

    test('falls back to root-level streamUrl when no data wrapper', () async {
      when(() => mockDio.get('/player/t1/stream')).thenAnswer(
          (_) async => ok(
              <String, dynamic>{'streamUrl': 'https://cdn/root.m3u8'}));

      expect(await service.getStreamUrl('t1'), 'https://cdn/root.m3u8');
    });

    test('returns null when no URL keys are present', () async {
      when(() => mockDio.get(any())).thenAnswer(
          (_) async => ok(<String, dynamic>{'data': <String, dynamic>{}}));

      expect(await service.getStreamUrl('t1'), isNull);
    });

    test('returns null when streamUrl is an empty string', () async {
      when(() => mockDio.get(any())).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{'streamUrl': ''}
              }));

      expect(await service.getStreamUrl('t1'), isNull);
    });

    test('returns null on DioException (swallowed silently)', () async {
      when(() => mockDio.get(any())).thenThrow(dioErr());

      expect(await service.getStreamUrl('t1'), isNull);
    });
  });

  // ── syncPlayerState ───────────────────────────────────────────────────────

  group('syncPlayerState', () {
    test('issues PUT /player/state with correct body', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => ok({}));

      await service.syncPlayerState(
        trackId: 't1',
        position: 30.5,
        isPlaying: true,
        volume: 0.8,
      );

      final body = verify(() => mockDio.put(
            '/player/state',
            data: captureAny(named: 'data'),
          )).captured.first as Map<String, dynamic>;

      expect(body['trackId'], 't1');
      expect(body['position'], 30.5);
      expect(body['isPlaying'], isTrue);
      expect(body['volume'], 0.8);
    });

    test('swallows DioException silently', () async {
      when(() => mockDio.put(any(), data: any(named: 'data')))
          .thenThrow(dioErr());

      // Should not throw
      await expectLater(
        service.syncPlayerState(
            trackId: 't1', position: 0, isPlaying: false, volume: 0.5),
        completes,
      );
    });
  });

  // ── reportProgress ────────────────────────────────────────────────────────

  group('reportProgress', () {
    test('issues POST /history/progress with trackId and progress', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => ok({}));

      await service.reportProgress(
          trackId: 't2', listenedSeconds: 120, totalSeconds: 200);

      final body = verify(() => mockDio.post(
            '/history/progress',
            data: captureAny(named: 'data'),
          )).captured.first as Map<String, dynamic>;

      expect(body['trackId'], 't2');
      expect(body['progress'], 120);
    });

    test('swallows DioException silently', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(dioErr());

      await expectLater(
        service.reportProgress(
            trackId: 't2', listenedSeconds: 90, totalSeconds: 200),
        completes,
      );
    });
  });

  // ── getRecentlyPlayed ─────────────────────────────────────────────────────

  group('getRecentlyPlayed — response shapes', () {
    test('parses list when body data contains recentlyPlayed key', () async {
      when(() => mockDio.get('/history/recently-played')).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'recentlyPlayed': [entryJson(id: 't1'), entryJson(id: 't2')]
                }
              }));

      final result = await service.getRecentlyPlayed();
      expect(result.length, 2);
      expect(result[0].track.id, 't1');
      expect(result[1].track.id, 't2');
    });

    test('parses list when body data contains tracks key', () async {
      when(() => mockDio.get('/history/recently-played')).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'tracks': [entryJson(id: 't3')]
                }
              }));

      final result = await service.getRecentlyPlayed();
      expect(result.length, 1);
      expect(result.first.track.id, 't3');
    });

    test('parses list when body data contains history key', () async {
      when(() => mockDio.get('/history/recently-played')).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'history': [entryJson(id: 't4')]
                }
              }));

      final result = await service.getRecentlyPlayed();
      expect(result.first.track.id, 't4');
    });

    test('parses list when body data contains items key', () async {
      when(() => mockDio.get('/history/recently-played')).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'items': [entryJson(id: 't5')]
                }
              }));

      final result = await service.getRecentlyPlayed();
      expect(result.first.track.id, 't5');
    });

    test('parses list when inner data is itself a list', () async {
      when(() => mockDio.get('/history/recently-played')).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': [entryJson(id: 't6')]
              }));

      final result = await service.getRecentlyPlayed();
      expect(result.first.track.id, 't6');
    });

    test('parses list when body is a raw list (no wrapper)', () async {
      when(() => mockDio.get('/history/recently-played'))
          .thenAnswer((_) async => ok([entryJson(id: 't7')]));

      final result = await service.getRecentlyPlayed();
      expect(result.first.track.id, 't7');
    });

    test('returns empty list on DioException', () async {
      when(() => mockDio.get(any())).thenThrow(dioErr());
      expect(await service.getRecentlyPlayed(), isEmpty);
    });

    test('returns empty list when data key is missing entirely', () async {
      when(() => mockDio.get('/history/recently-played'))
          .thenAnswer((_) async => ok(<String, dynamic>{}));
      expect(await service.getRecentlyPlayed(), isEmpty);
    });
  });

  group('getRecentlyPlayed — entry parsing', () {
    test('parses track id, title, and hlsUrl correctly', () async {
      when(() => mockDio.get(any())).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'recentlyPlayed': [
                    entryJson(id: 'abc', title: 'My Track',
                        audioUrl: 'https://cdn/abc.m3u8')
                  ]
                }
              }));

      final entries = await service.getRecentlyPlayed();
      expect(entries.first.track.id, 'abc');
      expect(entries.first.track.title, 'My Track');
      expect(entries.first.track.audioUrl, 'https://cdn/abc.m3u8');
    });

    test('parses artist name from artist object (displayName key)', () async {
      when(() => mockDio.get(any())).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'recentlyPlayed': [
                    <String, dynamic>{
                      'track': <String, dynamic>{
                        '_id': 'ta',
                        'title': 'T',
                        'artist': <String, dynamic>{
                          '_id': 'u1',
                          'displayName': 'Ziad Awad',
                          'permalink': 'ziad',
                        },
                        'hlsUrl': 'https://cdn/ta.m3u8',
                      },
                      'playedAt': '2024-06-01T10:00:00.000Z',
                    }
                  ]
                }
              }));

      final entries = await service.getRecentlyPlayed();
      expect(entries.first.track.artist, 'Ziad Awad');
      expect(entries.first.track.artistId, 'u1');
      expect(entries.first.track.artistPermalink, 'ziad');
    });

    test('parses artist name from plain string artist field', () async {
      when(() => mockDio.get(any())).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'recentlyPlayed': [
                    <String, dynamic>{
                      'track': <String, dynamic>{
                        '_id': 'tb',
                        'title': 'T',
                        'artist': 'Khaled Mostafa',
                        'hlsUrl': '',
                      },
                      'playedAt': '2024-06-01T10:00:00.000Z',
                    }
                  ]
                }
              }));

      final entries = await service.getRecentlyPlayed();
      expect(entries.first.track.artist, 'Khaled Mostafa');
      expect(entries.first.track.artistId, isNull);
    });

    test('parses playedAt date from playedAt key', () async {
      when(() => mockDio.get(any())).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'recentlyPlayed': [entryJson(playedAt: '2024-03-15T08:30:00.000Z')]
                }
              }));

      final entries = await service.getRecentlyPlayed();
      expect(entries.first.playedAt, DateTime.parse('2024-03-15T08:30:00.000Z'));
    });

    test('parses duration from duration field in seconds', () async {
      when(() => mockDio.get(any())).thenAnswer(
          (_) async => ok(<String, dynamic>{
                'data': <String, dynamic>{
                  'recentlyPlayed': [
                    <String, dynamic>{
                      'track': <String, dynamic>{
                        '_id': 'td',
                        'title': 'T',
                        'artist': 'A',
                        'hlsUrl': '',
                        'duration': 240,
                      },
                      'playedAt': '2024-06-01T10:00:00.000Z',
                    }
                  ]
                }
              }));

      final entries = await service.getRecentlyPlayed();
      expect(entries.first.track.duration, const Duration(seconds: 240));
    });
  });

  // ── clearServerHistory ────────────────────────────────────────────────────

  group('clearServerHistory', () {
    test('issues DELETE /history', () async {
      when(() => mockDio.delete('/history'))
          .thenAnswer((_) async => ok({}));

      await service.clearServerHistory();

      verify(() => mockDio.delete('/history')).called(1);
    });

    test('swallows DioException silently', () async {
      when(() => mockDio.delete(any())).thenThrow(dioErr());

      await expectLater(service.clearServerHistory(), completes);
    });
  });
}
