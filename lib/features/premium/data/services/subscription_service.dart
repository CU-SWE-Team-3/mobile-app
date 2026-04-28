import 'package:flutter/foundation.dart';
import 'package:soundcloud_clone/core/network/dio_client.dart';

class SubscriptionService {
  final DioClient _client;
  const SubscriptionService(this._client);

  Future<String> checkout(String planType) async {
    final response = await _client.dio.post(
      '/subscriptions/checkout',
      data: {'planType': planType},
    );
    return response.data['checkoutUrl'] as String;
  }

  // Returns expiresAt ISO string, or null if backend omits it.
  // Auth uses the DioClient global Bearer header — same as checkout(), which works.
  Future<String?> cancel() async {
    const endpoint = 'DELETE /subscriptions/cancel';

    // [1] Endpoint + full constructed URL
    final fullUrl = '${_client.dio.options.baseUrl}/subscriptions/cancel';
    debugPrint('[Cancel] endpoint: $endpoint  →  full URL: $fullUrl');

    // [2] Authorization header presence (value intentionally NOT printed)
    final authHeader = _client.dio.options.headers['Authorization'] as String?;
    final hasAuth = authHeader != null && authHeader.isNotEmpty;
    debugPrint('[Cancel] Authorization header exists: $hasAuth');

    final response = await _client.dio.delete('/subscriptions/cancel');

    // [3] Status code
    debugPrint('[Cancel] status code: ${response.statusCode}');

    // [4] Raw response body
    debugPrint('[Cancel] response body: ${response.data}');

    final data = response.data;
    if (data is! Map) {
      debugPrint('[Cancel] expiresAt: null (response body is not a Map)');
      return null;
    }

    // YAML: { success, data: { message, expiresAt } }
    // Use .toString() to avoid TypeError if field comes back as non-String.
    String? expiresAt;
    final inner = data['data'];
    if (inner is Map) {
      expiresAt = inner['expiresAt']?.toString();
    }
    // Fallback: some backends flatten the response.
    expiresAt ??= data['expiresAt']?.toString();

    // [5] Parsed expiresAt
    debugPrint('[Cancel] parsed expiresAt: $expiresAt');

    return expiresAt;
  }
}
