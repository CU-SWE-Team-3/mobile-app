import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }
}

final dioClient = DioClient();
