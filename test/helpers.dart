import 'dart:convert';
import 'dart:io';

import 'package:dio_client/src/token_storage.dart';

/// Minimal loopback HTTP server used to exercise the real
/// request → 401 → refresh → retry flow through Dio's network stack.
class TestServer {
  final HttpServer _server;

  TestServer._(this._server);

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<TestServer> start(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await handler(request);
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
      } finally {
        await request.response.close();
      }
    });
    return TestServer._(server);
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

/// Writes a JSON error/success body in the backend's standard format.
void writeJson(HttpRequest request, int statusCode, Map<String, dynamic> body) {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
}

/// Writes a plain-text body.
void writeText(HttpRequest request, int statusCode, String body) {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.text;
  request.response.write(body);
}

/// In-memory [TokenStorage] whose fields can be inspected and mutated by
/// tests.
class TokenStore {
  String? accessToken;
  String? refreshToken;

  TokenStorage toTokenStorage() {
    return TokenStorage(
      getAccessToken: () async => accessToken,
      getRefreshToken: () async => refreshToken,
      saveTokens:
          ({
            required String accessToken,
            required String refreshToken,
          }) async {
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
          },
      clearTokensOnLogout: () async {
        accessToken = null;
        refreshToken = null;
      },
    );
  }
}
