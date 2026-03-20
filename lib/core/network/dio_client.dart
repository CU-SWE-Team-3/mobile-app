import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
<<<<<<< HEAD
=======
import 'package:shared_preferences/shared_preferences.dart';
>>>>>>> main

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl:
          'https://biobeats-api-dwe8abgwg3e9agcu.francecentral-01.azurewebsites.net/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

<<<<<<< HEAD
=======
  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

>>>>>>> main
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final cookieJar =
        PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
    dio.interceptors.add(CookieManager(cookieJar));
<<<<<<< HEAD
=======

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
          if (error.response?.statusCode == 401) {
            try {
              final refreshPrefs = await SharedPreferences.getInstance();
              final refreshToken = refreshPrefs.getString('refreshToken');
              if (refreshToken == null) return handler.next(error);

              final refreshResponse = await Dio().post(
                'https://biobeats-api-dwe8abgwg3e9agcu.francecentral-01.azurewebsites.net/api/auth/refresh',
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
              opts.headers['Authorization'] = dio.options.headers['Authorization'];
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
>>>>>>> main
  }
}

final dioClient = DioClient();
