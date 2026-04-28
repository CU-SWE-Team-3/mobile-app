class AppConstants {
  // App Info
  static const String appName = 'SoundCloud';

  // Network — both values must point to the same host.
  // dioClient baseUrl: 'https://biobeats.duckdns.org/api'
  // Socket.IO sits at the transport layer (no /api path).
  static const String socketBaseUrl = 'https://biobeats.duckdns.org';

  // Google Sign-In
  static const String googleAndroidClientId =
      '718123581836-1kee9i09ce4h2teu8rp6b722eppbdmeu.apps.googleusercontent.com';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';

  // Pagination
  static const int pageSize = 20;
}
