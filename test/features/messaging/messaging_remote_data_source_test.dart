import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:soundcloud_clone/features/messaging/data/datasources/messaging_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

Response<dynamic> successResponse(dynamic data, {String path = ''}) => Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: data,
    );

Map<String, dynamic> fakeMessageJson() => {
      '_id': 'message-1',
      'conversationId': 'conversation-1',
      'senderId': 'sender-1',
      'content': '',
      'createdAt': '2024-01-01T00:00:00.000Z',
    };

void main() {
  late MockDio mockDio;
  late MessagingRemoteDataSource dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = MessagingRemoteDataSource(mockDio);
    registerFallbackValue(Options());
  });

  group('sendMessage', () {
    test('serializes track attachments with backend enum casing', () async {
      when(() => mockDio.post(
            '/messages',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => successResponse({
            'data': {'message': fakeMessageJson()},
          }));

      await dataSource.sendMessage(
        receiverId: 'receiver-1',
        conversationId: 'conversation-1',
        attachmentType: 'track',
        attachmentId: 'track-1',
      );

      final body = verify(() => mockDio.post(
            '/messages',
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          )).captured.first as Map<String, dynamic>;

      expect(body['attachmentType'], 'Track');
      expect(body['attachmentId'], 'track-1');
    });

    test('serializes playlist attachments with backend enum casing', () async {
      when(() => mockDio.post(
            '/messages',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => successResponse({
            'data': {'message': fakeMessageJson()},
          }));

      await dataSource.sendMessage(
        receiverId: 'receiver-1',
        attachmentType: 'playlist',
        attachmentId: 'playlist-1',
      );

      final body = verify(() => mockDio.post(
            '/messages',
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          )).captured.first as Map<String, dynamic>;

      expect(body['attachmentType'], 'Playlist');
      expect(body['attachmentId'], 'playlist-1');
    });
  });
}
