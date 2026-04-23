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

  // Returns expiresAt ISO string, or null if not provided.
  Future<String?> cancel() async {
    final response = await _client.dio.post('/subscriptions/cancel');
    return response.data['data']?['expiresAt'] as String?;
  }
}
