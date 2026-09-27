import 'package:dio_client/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestServer server;
  late TokenStore tokens;
  late DioClient client;

  setUp(() async {
    tokens = TokenStore();
    server = await TestServer.start((request) async {
      final path = request.uri.path;

      if (path == '/text-error') {
        writeText(request, 400, 'plain text failure');
        return;
      }

      if (path == '/empty-error') {
        request.response.statusCode = 400;
        return;
      }

      if (path == '/malformed-error') {
        writeText(request, 400, '{"error": 12345}');
        return;
      }

      if (path == '/bad-json') {
        writeJson(request, 200, {'unexpected': true});
        return;
      }

      if (path == '/thing') {
        writeJson(request, 200, {'ok': true});
        return;
      }

      writeJson(request, 400, {'error': 'boom'});
    });
    client = DioClient.init(
      baseUrl: server.baseUrl,
      tokenStorage: tokens.toTokenStorage(),
      onLogout: () {},
      useGlobalVersion: false,
      refreshEndpoint: '/refresh',
    );
  });

  tearDown(() async {
    await server.close();
  });

  test('parses {"error": "..."} on 4xx into ApiResponse.error', () async {
    final res = await client.get<Map<String, dynamic>>(
      path: '/thing-fail',
      fromJson: (data) => data as Map<String, dynamic>,
    );

    expect(res.isSuccess, isFalse);
    expect(res.statusCode, 400);
    expect(res.error, 'boom');
  });

  test('parses {"error": "..."} on POST too', () async {
    final res = await client.post<String>(
      path: '/thing-fail',
      fromJson: (data) => data as String,
      data: {'x': 1},
    );

    expect(res.statusCode, 400);
    expect(res.error, 'boom');
  });

  test('falls back to a plain-text error body', () async {
    final res = await client.get<String>(
      path: '/text-error',
      fromJson: (data) => data as String,
    );

    expect(res.statusCode, 400);
    expect(res.error, 'plain text failure');
  });

  test('malformed/missing error payloads fall back to the default', () async {
    final malformed = await client.get<String>(
      path: '/malformed-error',
      fromJson: (data) => data as String,
    );
    expect(malformed.error, ApiResponse.defaultError);

    final empty = await client.get<String>(
      path: '/empty-error',
      fromJson: (data) => data as String,
    );
    expect(empty.error, ApiResponse.defaultError);
  });

  test('malformed payloads use the app-configured defaultError', () async {
    client = DioClient.init(
      baseUrl: server.baseUrl,
      tokenStorage: tokens.toTokenStorage(),
      onLogout: () {},
      useGlobalVersion: false,
      refreshEndpoint: '/refresh',
      defaultError: 'خطای نامشخص',
    );

    final res = await client.get<String>(
      path: '/malformed-error',
      fromJson: (data) => data as String,
    );

    expect(res.statusCode, 400);
    expect(res.error, 'خطای نامشخص');
  });

  test('successful responses still parse data with fromJson', () async {
    final res = await client.get<Map<String, dynamic>>(
      path: '/thing',
      fromJson: (data) => data as Map<String, dynamic>,
    );

    expect(res.isSuccess, isTrue);
    expect(res.data, {'ok': true});
    expect(res.error, ApiResponse.defaultError);
  });

  test('fromJson failures surface a parse error without throwing', () async {
    final res = await client.get<String>(
      path: '/thing',
      fromJson: (data) => throw const FormatException('nope'),
    );

    // Parse failures keep the HTTP status but carry no data.
    expect(res.statusCode, 200);
    expect(res.data, isNull);
    expect(res.error, startsWith('Failed to parse response'));
  });

  test('fold exposes parsed backend errors through Either.left', () async {
    final res = await client.get<String>(
      path: '/thing-fail',
      fromJson: (data) => data as String,
    );

    final message = res.fold((error) => error, (data) => 'right');

    expect(message.isLeft, isTrue);
    expect(message.left, 'boom');
  });
}
