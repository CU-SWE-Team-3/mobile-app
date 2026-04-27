import 'package:dio/dio.dart';
import '../../domain/models/search_models.dart';

class SearchRepository {
  final Dio _dio;

  const SearchRepository(this._dio);

  /// Lightweight prefix-match autocomplete — public endpoint, no auth required.
  Future<AutocompleteResult> autocomplete(String prefix) async {
    final resp = await _dio.get(
      '/tracks/autocomplete',
      queryParameters: {'q': prefix},
    );
    final body = resp.data;
    if (body is! Map<String, dynamic>) return const AutocompleteResult.empty();
    return AutocompleteResult.fromJson(body);
  }

  /// Full text search across tracks, users, and playlists.
  /// [type] maps to the API's `type` param: 'tracks', 'users', or 'playlists'.
  /// Pass null (or 'all') to search all three.
  Future<FullSearchResult> fullSearch(
    String query, {
    String? type,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, dynamic>{
      'q': query,
      'page': page,
      'limit': limit,
    };
    if (type != null && type != 'all') params['type'] = type;

    final resp = await _dio.get('/tracks/search', queryParameters: params);
    final body = resp.data;
    if (body is! Map<String, dynamic>) return const FullSearchResult.empty();
    return FullSearchResult.fromJson(body);
  }
}
