import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<void> _authInvalidatedController =
      StreamController<void>.broadcast();

  Stream<String> get tokenRefreshes => _tokenRefreshController.stream;
  Stream<void> get authInvalidated => _authInvalidatedController.stream;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: 'https://biobeats.duckdns.org/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
      
    ));
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String?> refreshAccessToken() async {
    if (_isRefreshing) return _refreshCompleter?.future;

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();
    SharedPreferences? refreshPrefs;

    try {
      refreshPrefs = await SharedPreferences.getInstance();
      final refreshToken = refreshPrefs.getString('refreshToken');
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final refreshResponse = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      )).post(
        'https://biobeats.duckdns.org/api/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Cookie': 'refreshToken=$refreshToken'}),
      );

      String? newToken;
      String? newRefreshToken;

      final body = refreshResponse.data;
      if (body is Map<String, dynamic>) {
        final bodyData = body['data'] as Map<String, dynamic>?;
        final userData = bodyData?['user'] as Map<String, dynamic>?;
        newToken = bodyData?['token'] as String? ??
            bodyData?['accessToken'] as String? ??
            userData?['token'] as String? ??
            userData?['accessToken'] as String?;
        newRefreshToken = bodyData?['refreshToken'] as String? ??
            userData?['refreshToken'] as String?;
      }

      final cookies = refreshResponse.headers['set-cookie'];
      if (cookies != null) {
        newToken = _cookieValue(cookies, 'accessToken') ?? newToken;
        newRefreshToken =
            _cookieValue(cookies, 'refreshToken') ?? newRefreshToken;
      }

      if (newToken != null && newToken.isNotEmpty) {
        setAuthToken(newToken);
        await refreshPrefs.setString('accessToken', newToken);
        _tokenRefreshController.add(newToken);
        debugPrint(
          '[DioClient] Token refreshed successfully ${_jwtSummary(newToken)}',
        );
      }
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await refreshPrefs.setString('refreshToken', newRefreshToken);
      }

      _refreshCompleter!.complete(newToken);
      return newToken;
    } catch (e) {
      debugPrint('[DioClient] Token refresh failed: $e');
      if (e is DioException) {
        debugPrint('[DioClient] Refresh response data: ${e.response?.data}');
        if (e.response?.statusCode == 401 && refreshPrefs != null) {
          await _clearStoredAuth(refreshPrefs);
        }
      }
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  static String? _cookieValue(List<String> cookies, String name) {
    final pattern = RegExp('(?:^|[,\\s])$name=([^;]+)');
    for (final cookie in cookies) {
      final match = pattern.firstMatch(cookie);
      if (match != null) return match.group(1);
    }
    return null;
  }

  Future<void> _clearStoredAuth(SharedPreferences prefs) async {
    dio.options.headers.remove('Authorization');
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');
    _authInvalidatedController.add(null);
    debugPrint('[DioClient] Cleared expired session after refresh rejection');
  }

  static String _jwtSummary(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return '';
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final id = payload['id'] ?? payload['sub'] ?? payload['userId'];
      final iat = payload['iat'];
      final exp = payload['exp'];
      return '(id=$id iat=$iat exp=$exp)';
    } catch (_) {
      return '';
    }
  }

  Future<void> init() async {
    // No cookie jar — pure Bearer token auth
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token != null && token.isNotEmpty) {
      setAuthToken(token);
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          if (status == 401) {
            final newToken = await refreshAccessToken();
            if (newToken != null) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              return handler.resolve(await dio.fetch(opts));
            }
            return handler.next(error);
          }
          return handler.next(error);
        },
      ),
    );
  }
}

final dioClient = DioClient();

final dioClientProvider = Provider<DioClient>((ref) {
  return dioClient;
});

