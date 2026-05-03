import 'package:flutter_test/flutter_test.dart';
import 'package:soundcloud_clone/features/search/domain/entities/search_result.dart';

void main() {
  // ── SearchResultTrack ──────────────────────────────────────────────────────

  group('SearchResultTrack', () {
    Map<String, dynamic> fullJson() => {
          '_id': 'track-1',
          'title': 'Sunrise',
          'artist': {
            '_id': 'artist-1',
            'displayName': 'SunArtist',
            'permalink': 'sun-artist',
          },
          'artworkUrl': 'https://example.com/art.jpg',
          'hlsUrl': 'https://example.com/stream.m3u8',
          'duration': 210,
          'playCount': 1500,
          'waveform': [10, 20, 30, 40, 50],
          'permalink': 'sunrise',
        };

    group('fromJson', () {
      test('maps _id to id', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.id, 'track-1');
      });

      test('maps title correctly', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.title, 'Sunrise');
      });

      test('maps artist.displayName to artistName', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.artistName, 'SunArtist');
      });

      test('maps artist._id to artistId', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.artistId, 'artist-1');
      });

      test('maps artist.permalink to artistPermalink', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.artistPermalink, 'sun-artist');
      });

      test('maps hlsUrl', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.hlsUrl, 'https://example.com/stream.m3u8');
      });

      test('falls back to audioUrl when hlsUrl absent', () {
        final json = fullJson()..remove('hlsUrl');
        json['audioUrl'] = 'https://example.com/audio.mp3';
        final t = SearchResultTrack.fromJson(json);
        expect(t.hlsUrl, 'https://example.com/audio.mp3');
      });

      test('falls back to streamUrl when hlsUrl and audioUrl absent', () {
        final json = fullJson()..remove('hlsUrl');
        json['streamUrl'] = 'https://example.com/stream.mp3';
        final t = SearchResultTrack.fromJson(json);
        expect(t.hlsUrl, 'https://example.com/stream.mp3');
      });

      test('hlsUrl defaults to empty string when all url keys absent', () {
        final json = fullJson()..remove('hlsUrl');
        final t = SearchResultTrack.fromJson(json);
        expect(t.hlsUrl, '');
      });

      test('maps duration to durationSeconds', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.durationSeconds, 210);
      });

      test('maps playCount', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.playCount, 1500);
      });

      test('maps waveform as list of int', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.waveform, [10, 20, 30, 40, 50]);
      });

      test('maps permalink', () {
        final t = SearchResultTrack.fromJson(fullJson());
        expect(t.permalink, 'sunrise');
      });

      test('uses "user" when "artist" is absent', () {
        final json = fullJson()..remove('artist');
        json['user'] = {'_id': 'u1', 'displayName': 'UserArtist'};
        final t = SearchResultTrack.fromJson(json);
        expect(t.artistName, 'UserArtist');
        expect(t.artistId, 'u1');
      });

      test('uses "username" fallback when displayName absent', () {
        final json = fullJson();
        json['artist'] = {'_id': 'a1', 'username': 'username_only'};
        final t = SearchResultTrack.fromJson(json);
        expect(t.artistName, 'username_only');
      });

      test('falls back to top-level artistName when artist map absent', () {
        final json = fullJson()..remove('artist');
        json['artistName'] = 'FallbackName';
        final t = SearchResultTrack.fromJson(json);
        expect(t.artistName, 'FallbackName');
      });

      test('playCount defaults to 0 when absent', () {
        final json = fullJson()..remove('playCount');
        final t = SearchResultTrack.fromJson(json);
        expect(t.playCount, 0);
      });

      test('waveform is null when absent', () {
        final json = fullJson()..remove('waveform');
        final t = SearchResultTrack.fromJson(json);
        expect(t.waveform, isNull);
      });
    });
  });

  // ── SearchResultUser ───────────────────────────────────────────────────────

  group('SearchResultUser', () {
    Map<String, dynamic> userJson() => {
          '_id': 'user-1',
          'displayName': 'Cool User',
          'permalink': 'cool-user',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'bio': 'Music producer',
          'followerCount': 1200,
        };

    group('fromJson', () {
      test('maps _id to id', () {
        final u = SearchResultUser.fromJson(userJson());
        expect(u.id, 'user-1');
      });

      test('maps displayName', () {
        final u = SearchResultUser.fromJson(userJson());
        expect(u.displayName, 'Cool User');
      });

      test('uses username fallback when displayName absent', () {
        final json = userJson()..remove('displayName');
        json['username'] = 'username_fallback';
        final u = SearchResultUser.fromJson(json);
        expect(u.displayName, 'username_fallback');
      });

      test('maps permalink', () {
        final u = SearchResultUser.fromJson(userJson());
        expect(u.permalink, 'cool-user');
      });

      test('maps avatarUrl', () {
        final u = SearchResultUser.fromJson(userJson());
        expect(u.avatarUrl, 'https://example.com/avatar.jpg');
      });

      test('maps bio', () {
        final u = SearchResultUser.fromJson(userJson());
        expect(u.bio, 'Music producer');
      });

      test('maps followerCount as int', () {
        final u = SearchResultUser.fromJson(userJson());
        expect(u.followerCount, 1200);
      });

      test('parses followerCount from string', () {
        final json = userJson();
        json['followerCount'] = '500';
        final u = SearchResultUser.fromJson(json);
        expect(u.followerCount, 500);
      });

      test('followerCount defaults to 0 when absent', () {
        final json = userJson()..remove('followerCount');
        final u = SearchResultUser.fromJson(json);
        expect(u.followerCount, 0);
      });

      test('avatarUrl is null when absent', () {
        final json = userJson()..remove('avatarUrl');
        final u = SearchResultUser.fromJson(json);
        expect(u.avatarUrl, isNull);
      });

      test('bio is null when absent', () {
        final json = userJson()..remove('bio');
        final u = SearchResultUser.fromJson(json);
        expect(u.bio, isNull);
      });
    });
  });

  // ── SearchResultPlaylist ───────────────────────────────────────────────────

  group('SearchResultPlaylist', () {
    Map<String, dynamic> playlistJson() => {
          '_id': 'pl-1',
          'title': 'Chill Vibes',
          'artworkUrl': 'https://example.com/pl-art.jpg',
          'creator': {
            '_id': 'creator-1',
            'displayName': 'Curator',
          },
          'trackCount': 12,
        };

    group('fromJson', () {
      test('maps _id to id', () {
        final pl = SearchResultPlaylist.fromJson(playlistJson());
        expect(pl.id, 'pl-1');
      });

      test('maps title', () {
        final pl = SearchResultPlaylist.fromJson(playlistJson());
        expect(pl.title, 'Chill Vibes');
      });

      test('maps artworkUrl', () {
        final pl = SearchResultPlaylist.fromJson(playlistJson());
        expect(pl.artworkUrl, 'https://example.com/pl-art.jpg');
      });

      test('maps creator.displayName to creatorName', () {
        final pl = SearchResultPlaylist.fromJson(playlistJson());
        expect(pl.creatorName, 'Curator');
      });

      test('maps creator._id to creatorId', () {
        final pl = SearchResultPlaylist.fromJson(playlistJson());
        expect(pl.creatorId, 'creator-1');
      });

      test('maps trackCount from int', () {
        final pl = SearchResultPlaylist.fromJson(playlistJson());
        expect(pl.trackCount, 12);
      });

      test('derives trackCount from tracks list length when trackCount absent', () {
        final json = playlistJson()..remove('trackCount');
        json['tracks'] = [1, 2, 3];
        final pl = SearchResultPlaylist.fromJson(json);
        expect(pl.trackCount, 3);
      });

      test('uses "user" key when "creator" absent', () {
        final json = playlistJson()..remove('creator');
        json['user'] = {'_id': 'u1', 'displayName': 'Uploader'};
        final pl = SearchResultPlaylist.fromJson(json);
        expect(pl.creatorName, 'Uploader');
      });

      test('falls back to ownerName when creator and user maps absent', () {
        final json = playlistJson()..remove('creator');
        json['ownerName'] = 'OwnerFallback';
        final pl = SearchResultPlaylist.fromJson(json);
        expect(pl.creatorName, 'OwnerFallback');
      });

      test('trackCount defaults to 0 when absent and no tracks list', () {
        final json = playlistJson()..remove('trackCount');
        final pl = SearchResultPlaylist.fromJson(json);
        expect(pl.trackCount, 0);
      });
    });
  });

  // ── SearchHistoryEntry ─────────────────────────────────────────────────────

  group('SearchHistoryEntry', () {
    final now = DateTime(2024, 6, 1, 12, 0, 0);

    SearchHistoryEntry makeEntry({
      String id = 'e1',
      SearchEntityType type = SearchEntityType.track,
    }) =>
        SearchHistoryEntry(
          id: id,
          type: type,
          displayName: 'Test Entry',
          subtitle: 'Subtitle',
          addedAt: now,
        );

    group('toJson / fromJson round-trip', () {
      test('round-trips required fields', () {
        final entry = makeEntry();
        final json = entry.toJson();
        final restored = SearchHistoryEntry.fromJson(json);
        expect(restored.id, entry.id);
        expect(restored.type, entry.type);
        expect(restored.displayName, entry.displayName);
        expect(restored.subtitle, entry.subtitle);
        expect(restored.addedAt, entry.addedAt);
      });

      test('round-trips optional fields when present', () {
        final entry = SearchHistoryEntry(
          id: 'e2',
          type: SearchEntityType.user,
          displayName: 'User',
          subtitle: 'Sub',
          imageUrl: 'https://img.jpg',
          permalink: 'user-perm',
          hlsUrl: 'https://audio.m3u8',
          artistId: 'art-id',
          addedAt: now,
        );
        final restored = SearchHistoryEntry.fromJson(entry.toJson());
        expect(restored.imageUrl, 'https://img.jpg');
        expect(restored.permalink, 'user-perm');
        expect(restored.hlsUrl, 'https://audio.m3u8');
        expect(restored.artistId, 'art-id');
      });

      test('optional fields omitted from json when null', () {
        final entry = makeEntry();
        final json = entry.toJson();
        expect(json.containsKey('imageUrl'), isFalse);
        expect(json.containsKey('permalink'), isFalse);
        expect(json.containsKey('hlsUrl'), isFalse);
        expect(json.containsKey('artistId'), isFalse);
      });

      test('type is stored as string name', () {
        final json = makeEntry(type: SearchEntityType.playlist).toJson();
        expect(json['type'], 'playlist');
      });

      test('fromJson with unknown type defaults to track', () {
        final json = makeEntry().toJson();
        json['type'] = 'unknown_type';
        final restored = SearchHistoryEntry.fromJson(json);
        expect(restored.type, SearchEntityType.track);
      });

      test('fromJson with missing addedAt defaults to recent DateTime', () {
        final json = makeEntry().toJson()..remove('addedAt');
        final restored = SearchHistoryEntry.fromJson(json);
        // Should not throw and should produce a recent date
        expect(restored.addedAt, isA<DateTime>());
      });
    });

    group('copyWith', () {
      test('can update displayName', () {
        final updated = makeEntry().copyWith(displayName: 'Updated');
        expect(updated.displayName, 'Updated');
      });

      test('can update type', () {
        final updated = makeEntry().copyWith(type: SearchEntityType.user);
        expect(updated.type, SearchEntityType.user);
      });

      test('preserves unchanged fields', () {
        final original = makeEntry();
        final updated = original.copyWith(subtitle: 'New Sub');
        expect(updated.id, original.id);
        expect(updated.addedAt, original.addedAt);
      });
    });

    group('factory constructors', () {
      test('fromTrack maps correct fields', () {
        const track = SearchResultTrack(
          id: 't1',
          title: 'My Track',
          artistName: 'My Artist',
          hlsUrl: 'https://stream.m3u8',
          artworkUrl: 'https://art.jpg',
        );
        final entry = SearchHistoryEntry.fromTrack(track);
        expect(entry.id, 't1');
        expect(entry.type, SearchEntityType.track);
        expect(entry.displayName, 'My Track');
        expect(entry.subtitle, 'My Artist');
        expect(entry.imageUrl, 'https://art.jpg');
        expect(entry.hlsUrl, 'https://stream.m3u8');
      });

      test('fromTrack sets hlsUrl to null when empty', () {
        const track = SearchResultTrack(
          id: 't1',
          title: 'T',
          artistName: 'A',
          hlsUrl: '',
        );
        final entry = SearchHistoryEntry.fromTrack(track);
        expect(entry.hlsUrl, isNull);
      });

      test('fromUser maps correct fields', () {
        const user = SearchResultUser(
          id: 'u1',
          displayName: 'Cool User',
          bio: 'Producer',
          avatarUrl: 'https://av.jpg',
          permalink: 'cool-user',
          followerCount: 500,
        );
        final entry = SearchHistoryEntry.fromUser(user);
        expect(entry.id, 'u1');
        expect(entry.type, SearchEntityType.user);
        expect(entry.displayName, 'Cool User');
        expect(entry.subtitle, 'Producer');
        expect(entry.imageUrl, 'https://av.jpg');
        expect(entry.permalink, 'cool-user');
      });

      test('fromUser uses follower count in subtitle when bio absent', () {
        const user = SearchResultUser(
          id: 'u1',
          displayName: 'User',
          followerCount: 1200,
        );
        final entry = SearchHistoryEntry.fromUser(user);
        expect(entry.subtitle.contains('1200'), isTrue);
      });

      test('fromPlaylist maps correct fields', () {
        const pl = SearchResultPlaylist(
          id: 'p1',
          title: 'Playlist Title',
          artworkUrl: 'https://pl-art.jpg',
          creatorName: 'Creator',
        );
        final entry = SearchHistoryEntry.fromPlaylist(pl);
        expect(entry.id, 'p1');
        expect(entry.type, SearchEntityType.playlist);
        expect(entry.displayName, 'Playlist Title');
        expect(entry.subtitle, 'Creator');
        expect(entry.imageUrl, 'https://pl-art.jpg');
      });

      test('fromPlaylist subtitle is empty string when creatorName null', () {
        const pl = SearchResultPlaylist(id: 'p1', title: 'PL');
        final entry = SearchHistoryEntry.fromPlaylist(pl);
        expect(entry.subtitle, '');
      });
    });
  });

  // ── SearchEntityType enum ──────────────────────────────────────────────────

  group('SearchEntityType', () {
    test('has three values: track, user, playlist', () {
      expect(SearchEntityType.values, hasLength(3));
      expect(SearchEntityType.values, contains(SearchEntityType.track));
      expect(SearchEntityType.values, contains(SearchEntityType.user));
      expect(SearchEntityType.values, contains(SearchEntityType.playlist));
    });

    test('each value has correct name', () {
      expect(SearchEntityType.track.name, 'track');
      expect(SearchEntityType.user.name, 'user');
      expect(SearchEntityType.playlist.name, 'playlist');
    });
  });
}
