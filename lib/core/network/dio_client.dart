import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;

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

    // Restore saved token if available
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token != null) {
      setAuthToken(token);
    }

    // Auto-refresh on 401
    dio.interceptors.add(
      InterceptorsWrapper(
       onError: (error, handler) async {
  final status = error.response?.statusCode;
  if (status == 401) {
    try {
      // ... your existing refresh logic
              final refreshPrefs = await SharedPreferences.getInstance();
              final refreshToken = refreshPrefs.getString('refreshToken');
              if (refreshToken == null) return handler.next(error);

              final refreshResponse = await Dio().post(
                'https://biobeats.duckdns.org/api/auth/refresh',
                data: {'refreshToken': refreshToken},
              );

              final cookies = refreshResponse.headers['set-cookie'];
              if (cookies != null) {
                for (final cookie in cookies) {
                  if (cookie.startsWith('accessToken=')) {
                    final newToken = cookie.split(';')[0].split('=')[1];
                    setAuthToken(newToken);
                    await refreshPrefs.setString('accessToken', newToken);
                    break;
                  }
                }
              }

              // Retry original request with updated token
              final opts = error.requestOptions;
              opts.headers['Authorization'] =
                  dio.options.headers['Authorization'];
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            } catch (_) {
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}

final dioClient = DioClient();

// Riverpod provider for DioClient
final dioClientProvider = Provider<DioClient>((ref) {
  return dioClient;
});
