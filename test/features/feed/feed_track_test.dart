import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/feed/data/models/feed_track.dart';

void main() {
  group('FeedTrack', () {
    // ── Constructor ────────────────────────────────────────────────────────

    group('constructor', () {
      test('can be constructed with required fields only', () {
        const track = FeedTrack(id: 'id1', title: 'Title', artistId: 'a1', artistName: 'Alice');
        expect(track.id, 'id1');
        expect(track.title, 'Title');
        expect(track.artistId, 'a1');
        expect(track.artistName, 'Alice');
        expect(track.likeCount, 0);
        expect(track.repostCount, 0);
        expect(track.commentCount, 0);
        expect(track.isLiked, isFalse);
        expect(track.isReposted, isFalse);
      });
    });

    // ── fromJson ──────────────────────────────────────────────────────────

    group('fromJson', () {
      Map<String, dynamic> fullJson() => {
            '_id': 'track-id-1',
            'title': 'Test Song',
            'artworkUrl': 'https://example.com/art.jpg',
            'hlsUrl': 'https://example.com/stream.m3u8',
            'artist': {
              '_id': 'artist-id',
              'displayName': 'DJ Sample',
              'avatarUrl': 'https://example.com/avatar.jpg',
              'permalink': 'dj-sample',
            },
            'permalink': 'test-song',
            'likeCount': 42,
            'repostCount': 7,
            'commentCount': 3,
            'isLiked': true,
            'isReposted': false,
          };

      test('maps _id to id', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.id, 'track-id-1');
      });

      test('maps title correctly', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.title, 'Test Song');
      });

      test('maps artworkUrl correctly', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.artworkUrl, 'https://example.com/art.jpg');
      });

      test('maps hlsUrl to audioUrl', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.audioUrl, 'https://example.com/stream.m3u8');
      });

      test('maps artist.displayName to artistName', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.artistName, 'DJ Sample');
      });

      test('maps artist._id to artistId', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.artistId, 'artist-id');
      });

      test('maps artist.avatarUrl to artistAvatarUrl', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.artistAvatarUrl, 'https://example.com/avatar.jpg');
      });

      test('maps artist.permalink to artistPermalink', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.artistPermalink, 'dj-sample');
      });

      test('maps permalink to trackPermalink', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.trackPermalink, 'test-song');
      });

      test('maps likeCount correctly', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.likeCount, 42);
      });

      test('maps repostCount correctly', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.repostCount, 7);
      });

      test('maps commentCount correctly', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.commentCount, 3);
      });

      test('maps isLiked true correctly', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.isLiked, isTrue);
      });

      test('maps isReposted false correctly', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.isReposted, isFalse);
      });

      test('uses "id" key when "_id" is absent', () {
        final json = fullJson()..remove('_id');
        json['id'] = 'alt-id';
        final track = FeedTrack.fromJson(json);
        expect(track.id, 'alt-id');
      });

      test('id is empty string when both _id and id are absent', () {
        final json = fullJson()..remove('_id');
        final track = FeedTrack.fromJson(json);
        expect(track.id, '');
      });

      test('artworkUrl is null when absent', () {
        final json = fullJson()..remove('artworkUrl');
        final track = FeedTrack.fromJson(json);
        expect(track.artworkUrl, isNull);
      });

      test('falls back to coverUrl for artwork', () {
        final json = fullJson()
          ..remove('artworkUrl')
          ..['coverUrl'] = 'https://cover.jpg';
        final track = FeedTrack.fromJson(json);
        expect(track.artworkUrl, 'https://cover.jpg');
      });

      test('falls back to "user" when "artist" is absent', () {
        final json = fullJson()..remove('artist');
        json['user'] = {'_id': 'user-id', 'displayName': 'User Name'};
        final track = FeedTrack.fromJson(json);
        expect(track.artistName, 'User Name');
        expect(track.artistId, 'user-id');
      });

      test('artist fields are empty strings when both artist and user are absent', () {
        final json = fullJson()
          ..remove('artist')
          ..remove('user');
        final track = FeedTrack.fromJson(json);
        expect(track.artistId, '');
        expect(track.artistName, '');
      });

      test('artist field as non-map (e.g. genre string) is handled gracefully', () {
        final json = fullJson();
        json['artist'] = 'Electronic'; // genre string, not a map
        expect(() => FeedTrack.fromJson(json), returnsNormally);
        final track = FeedTrack.fromJson(json);
        expect(track.artistName, isEmpty);
      });

      test('activity fields are null when underscore keys are absent', () {
        final track = FeedTrack.fromJson(fullJson());
        expect(track.activityType, isNull);
        expect(track.actorName, isNull);
        expect(track.actorAvatarUrl, isNull);
        expect(track.activityTimestamp, isNull);
      });

      test('maps _activityType when present', () {
        final json = fullJson();
        json['_activityType'] = 'repost';
        final track = FeedTrack.fromJson(json);
        expect(track.activityType, 'repost');
      });

      test('maps _actor.displayName to actorName', () {
        final json = fullJson();
        json['_activityType'] = 'repost';
        json['_actor'] = {'displayName': 'Reposter', 'avatarUrl': 'https://av.jpg'};
        final track = FeedTrack.fromJson(json);
        expect(track.actorName, 'Reposter');
        expect(track.actorAvatarUrl, 'https://av.jpg');
      });

      test('maps _activityTimestamp as DateTime', () {
        final json = fullJson();
        json['_activityTimestamp'] = '2024-03-15T12:00:00.000Z';
        final track = FeedTrack.fromJson(json);
        expect(track.activityTimestamp, isA<DateTime>());
        expect(track.activityTimestamp!.year, 2024);
        expect(track.activityTimestamp!.month, 3);
        expect(track.activityTimestamp!.day, 15);
      });

      test('invalid _activityTimestamp results in null DateTime', () {
        final json = fullJson();
        json['_activityTimestamp'] = 'not-a-date';
        final track = FeedTrack.fromJson(json);
        expect(track.activityTimestamp, isNull);
      });

      test('isLiked defaults to false when absent', () {
        final json = fullJson()..remove('isLiked');
        final track = FeedTrack.fromJson(json);
        expect(track.isLiked, isFalse);
      });

      test('isReposted defaults to false when absent', () {
        final json = fullJson()..remove('isReposted');
        final track = FeedTrack.fromJson(json);
        expect(track.isReposted, isFalse);
      });

      test('like/repost/comment counts default to 0 when absent', () {
        final json = fullJson()
          ..remove('likeCount')
          ..remove('repostCount')
          ..remove('commentCount');
        final track = FeedTrack.fromJson(json);
        expect(track.likeCount, 0);
        expect(track.repostCount, 0);
        expect(track.commentCount, 0);
      });

      test('like/repost counts work with double/num values', () {
        final json = fullJson();
        json['likeCount'] = 5.0;
        json['repostCount'] = 2.0;
        final track = FeedTrack.fromJson(json);
        expect(track.likeCount, 5);
        expect(track.repostCount, 2);
      });
    });

    // ── toPlayerTrack ──────────────────────────────────────────────────────

    group('toPlayerTrack', () {
      test('maps id, title, artistName correctly', () {
        const track = FeedTrack(
          id: 'feed-id',
          title: 'Feed Song',
          artistId: 'a1',
          artistName: 'Feed Artist',
          audioUrl: 'https://stream.m3u8',
        );
        final pt = track.toPlayerTrack();
        expect(pt.id, 'feed-id');
        expect(pt.title, 'Feed Song');
        expect(pt.artist, 'Feed Artist');
      });

      test('maps audioUrl to PlayerTrack.audioUrl', () {
        const track = FeedTrack(
          id: 'id',
          title: 'T',
          artistId: 'a',
          artistName: 'B',
          audioUrl: 'https://stream.m3u8',
        );
        final pt = track.toPlayerTrack();
        expect(pt.audioUrl, 'https://stream.m3u8');
      });

      test('null audioUrl maps to empty string in PlayerTrack', () {
        const track = FeedTrack(id: 'id', title: 'T', artistId: 'a', artistName: 'B');
        final pt = track.toPlayerTrack();
        expect(pt.audioUrl, '');
      });

      test('maps artworkUrl to PlayerTrack.coverUrl', () {
        const track = FeedTrack(
          id: 'id',
          title: 'T',
          artistId: 'a',
          artistName: 'B',
          artworkUrl: 'https://art.jpg',
        );
        final pt = track.toPlayerTrack();
        expect(pt.coverUrl, 'https://art.jpg');
      });

      test('maps artistId when non-empty', () {
        const track = FeedTrack(
          id: 'id',
          title: 'T',
          artistId: 'artist-123',
          artistName: 'B',
        );
        final pt = track.toPlayerTrack();
        expect(pt.artistId, 'artist-123');
      });

      test('artistId is null in PlayerTrack when empty string', () {
        const track = FeedTrack(id: 'id', title: 'T', artistId: '', artistName: 'B');
        final pt = track.toPlayerTrack();
        expect(pt.artistId, isNull);
      });

      test('maps trackPermalink and artistPermalink', () {
        const track = FeedTrack(
          id: 'id',
          title: 'T',
          artistId: 'a',
          artistName: 'B',
          trackPermalink: 'my-track',
          artistPermalink: 'my-artist',
        );
        final pt = track.toPlayerTrack();
        expect(pt.trackPermalink, 'my-track');
        expect(pt.artistPermalink, 'my-artist');
      });

      test('maps waveform list', () {
        const track = FeedTrack(
          id: 'id',
          title: 'T',
          artistId: 'a',
          artistName: 'B',
          waveform: [10, 50, 90],
        );
        final pt = track.toPlayerTrack();
        expect(pt.waveform, [10, 50, 90]);
      });
    });
  });
}
