import 'dart:async';
import 'dart:io' show Cookie;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/app_router.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: 'https://biobeats.duckdns.org/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ));
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final cookieJar =
        PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(LogInterceptor(
  request: true,
  requestHeader: true,
  requestBody: true,
  responseBody: true,
  responseHeader: false,
  logPrint: (o) => debugPrint(o.toString()),
));

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
            // Guard: never retry a request that has already been retried once.
            if (error.requestOptions.extra.containsKey('_retry')) {
              return handler.next(error);
            }

            if (_isRefreshing) {
              final newToken = await _refreshCompleter!.future;
              if (newToken != null) {
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newToken';
                opts.extra['_retry'] = true;
                opts.headers.remove('cookie');
                try {
                  return handler.resolve(await dio.fetch(opts));
                } catch (_) {
                  return handler.next(error);
                }
              }
              return handler.next(error);
            }

            _isRefreshing = true;
            _refreshCompleter = Completer<String?>();

            String? newToken;
            try {
              final refreshPrefs = await SharedPreferences.getInstance();
              final refreshToken = refreshPrefs.getString('refreshToken');
              if (refreshToken == null) {
                _refreshCompleter!.complete(null);
                _refreshCompleter = null;
                _isRefreshing = false;
                return handler.next(error);
              }

              final refreshResponse = await Dio().post(
                'https://biobeats.duckdns.org/api/auth/refresh',
                data: {'refreshToken': refreshToken},
              );

              String? newRefreshToken;

              final body = refreshResponse.data;
              if (body is Map<String, dynamic>) {
                final bodyData = body['data'] as Map<String, dynamic>?;
                final userData = bodyData?['user'] as Map<String, dynamic>?;
                newToken = bodyData?['token'] as String?
                    ?? bodyData?['accessToken'] as String?
                    ?? userData?['token'] as String?
                    ?? userData?['accessToken'] as String?;
                newRefreshToken = bodyData?['refreshToken'] as String?
                    ?? userData?['refreshToken'] as String?;
              }

              if (newToken == null) {
                final cookies = refreshResponse.headers['set-cookie'];
                if (cookies != null) {
                  for (final cookie in cookies) {
                    if (cookie.startsWith('accessToken=')) {
                      newToken = cookie.split(';')[0].split('=')[1];
                    } else if (cookie.startsWith('refreshToken=')) {
                      newRefreshToken = cookie.split(';')[0].split('=')[1];
                    }
                  }
                }
              }

              if (newToken != null) {
                setAuthToken(newToken);
                await refreshPrefs.setString('accessToken', newToken);
                // Replace the stale accessToken cookie in the jar so that
                // CookieManager injects the new value on the retry request —
                // not the original expired one that the jar still holds.
                final freshCookie = Cookie('accessToken', newToken)..path = '/';
                await cookieJar.saveFromResponse(
                  Uri.parse('https://biobeats.duckdns.org'),
                  [freshCookie],
                );
                debugPrint('[DioClient] Token refreshed successfully');
              }
              if (newRefreshToken != null) {
                await refreshPrefs.setString('refreshToken', newRefreshToken);
              }
            } catch (e) {
              debugPrint('[DioClient] Token refresh failed: $e');
              if (e is DioException) {
                debugPrint('[DioClient] Refresh response data: ${e.response?.data}');
              }
            } finally {
              _refreshCompleter!.complete(newToken);
              _refreshCompleter = null;
              _isRefreshing = false;
            }

            if (newToken != null) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = dio.options.headers['Authorization'];
              opts.extra['_retry'] = true;
              opts.headers.remove('cookie');
              try {
                return handler.resolve(await dio.fetch(opts));
              } catch (_) {
                return handler.next(error);
              }
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