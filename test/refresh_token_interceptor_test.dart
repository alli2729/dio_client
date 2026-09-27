import 'package:dio_client/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestServer server;
  late TokenStore tokens;
  late DioClient client;

  // Reset by startServer(); field-initialised so tests that build their own
  // server inline can still assert on them.
  int refreshCalls = 0;
  int dataCalls = 0;
  int logoutCount = 0;

  /// Builds a server where:
  ///  - `/data` rejects `rejectedTokens` with the new backend error format;
  ///  - `/refresh` behaves according to [refreshStatus]/[refreshBody];
  ///  - refresh responses are delayed to exercise the concurrency path.
  Future<void> startServer({
    Set<String> rejectedTokens = const {'expired-token'},
    int refreshStatus = 200,
    Map<String, dynamic>? refreshBody,
    Duration refreshDelay = const Duration(milliseconds: 50),
  }) async {
    refreshCalls = 0;
    dataCalls = 0;
    logoutCount = 0;
    server = await TestServer.start((request) async {
      final path = request.uri.path;

      if (path == '/refresh') {
        refreshCalls++;
        await Future<void>.delayed(refreshDelay);
        writeJson(
          request,
          refreshStatus,
          refreshBody ?? {'access': 'new-access'},
        );
        return;
      }

      if (path == '/data') {
        dataCalls++;
        final auth = request.headers.value('authorization');
        if (auth != null && rejectedTokens.contains(auth.substring(7))) {
          writeJson(request, 401, {'error': 'invalid token'});
          return;
        }
        writeJson(request, 200, {'ok': true});
        return;
      }

      writeJson(request, 404, {'error': 'not found'});
    });
  }

  Future<void> initClient() async {
    client = DioClient.init(
      baseUrl: server.baseUrl,
      tokenStorage: tokens.toTokenStorage(),
      onLogout: () => logoutCount++,
      useGlobalVersion: false,
      refreshEndpoint: '/refresh',
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchData() => client.get(
    path: '/data',
    fromJson: (data) => data as Map<String, dynamic>,
  );

  setUp(() {
    // Reset shared counters for tests that build their own server inline.
    refreshCalls = 0;
    dataCalls = 0;
    logoutCount = 0;
  });

  tearDown(() async {
    await server.close();
  });

  group('RefreshTokenInterceptor', () {
    test(
      'invalid token → refresh → retry succeeds and updates tokens',
      () async {
        await startServer();
        tokens = TokenStore()
          ..accessToken = 'expired-token'
          ..refreshToken = 'valid-refresh';
        await initClient();

        final res = await fetchData();

        expect(res.isSuccess, isTrue);
        expect(res.statusCode, 200);
        expect(res.data, {'ok': true});
        expect(refreshCalls, 1);
        expect(dataCalls, 2, reason: 'original + one retry');
        expect(tokens.accessToken, 'new-access');
        expect(
          tokens.refreshToken,
          'valid-refresh',
          reason: 'no rotation when refresh response has no refresh field',
        );
        expect(logoutCount, 0);
      },
    );

    test(
      'refresh response with rotation persists both tokens',
      () async {
        await startServer(
          refreshBody: {'access': 'new-access', 'refresh': 'new-refresh'},
        );
        tokens = TokenStore()
          ..accessToken = 'expired-token'
          ..refreshToken = 'valid-refresh';
        await initClient();

        final res = await fetchData();

        expect(res.isSuccess, isTrue);
        expect(tokens.accessToken, 'new-access');
        expect(tokens.refreshToken, 'new-refresh');
      },
    );

    test('concurrent requests share a single refresh', () async {
      await startServer();
      tokens = TokenStore()
        ..accessToken = 'expired-token'
        ..refreshToken = 'valid-refresh';
      await initClient();

      final results = await Future.wait([
        fetchData(),
        fetchData(),
        fetchData(),
        fetchData(),
      ]);

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(results.every((r) => r.data != null), isTrue);
      expect(
        refreshCalls,
        1,
        reason: 'single-flight guard must collapse concurrent 401s',
      );
      expect(logoutCount, 0);
    });

    test(
      'failed refresh clears tokens, logs out, and surfaces the error',
      () async {
        await startServer(
          refreshStatus: 401,
          refreshBody: {'error': 'invalid token'},
        );
        tokens = TokenStore()
          ..accessToken = 'expired-token'
          ..refreshToken = 'invalid-refresh';
        await initClient();

        final res = await fetchData();

        expect(res.isSuccess, isFalse);
        expect(res.statusCode, 401);
        expect(res.error, 'invalid token');
        expect(refreshCalls, 1);
        expect(dataCalls, 1, reason: 'no retry after failed refresh');
        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
        expect(logoutCount, 1);
      },
    );

    test(
      'transient refresh failure keeps tokens and does not log out',
      () async {
        await startServer(
          refreshStatus: 500,
          refreshBody: {'error': 'server exploded'},
        );
        tokens = TokenStore()
          ..accessToken = 'expired-token'
          ..refreshToken = 'valid-refresh';
        await initClient();

        final res = await fetchData();

        expect(res.isSuccess, isFalse);
        expect(res.statusCode, 401);
        expect(res.error, 'invalid token');
        expect(tokens.accessToken, 'expired-token');
        expect(tokens.refreshToken, 'valid-refresh');
        expect(logoutCount, 0);
      },
    );

    test('no infinite retry loop when the retry is also rejected', () async {
      // /data rejects EVERY token, /refresh always "succeeds".
      await startServer(
        rejectedTokens: {'expired-token', 'new-access'},
        refreshBody: {'access': 'new-access'},
      );
      tokens = TokenStore()
        ..accessToken = 'expired-token'
        ..refreshToken = 'valid-refresh';
      await initClient();

      final res = await fetchData();

      expect(res.isSuccess, isFalse);
      expect(res.statusCode, 401);
      expect(res.error, 'invalid token');
      expect(refreshCalls, 1, reason: 'must not refresh again after retry');
      expect(
        dataCalls,
        2,
        reason: 'original request + exactly one retry (maxRetry default 1)',
      );
      expect(logoutCount, 0);
    });

    test(
      '401 with a different error message does not trigger refresh',
      () async {
        var refreshCallsOther = 0;
        server = await TestServer.start((request) async {
          if (request.uri.path == '/refresh') {
            refreshCallsOther++;
            writeJson(request, 200, {'access': 'new-access'});
            return;
          }
          writeJson(request, 401, {'error': 'credentials rejected'});
        });
        tokens = TokenStore()
          ..accessToken = 'expired-token'
          ..refreshToken = 'valid-refresh';
        await initClient();

        final res = await fetchData();

        expect(res.isSuccess, isFalse);
        expect(res.statusCode, 401);
        expect(res.error, 'credentials rejected');
        expect(refreshCallsOther, 0);
        expect(logoutCount, 0);
        expect(tokens.accessToken, 'expired-token');
      },
    );

    test('401 with malformed body does not trigger refresh', () async {
      var refreshCallsLocal = 0;
      server = await TestServer.start((request) async {
        if (request.uri.path == '/refresh') {
          refreshCallsLocal++;
          writeJson(request, 200, {'access': 'new-access'});
          return;
        }
        writeText(request, 401, 'not json at all');
      });
      tokens = TokenStore()
        ..accessToken = 'expired-token'
        ..refreshToken = 'valid-refresh';
      await initClient();

      final res = await fetchData();

      expect(res.isSuccess, isFalse);
      expect(refreshCallsLocal, 0);
      expect(logoutCount, 0);
    });

    test(
      'missing refresh token rejects the session without a refresh call',
      () async {
        var refreshCallsLocal = 0;
        server = await TestServer.start((request) async {
          if (request.uri.path == '/refresh') {
            refreshCallsLocal++;
            writeJson(request, 200, {'access': 'new-access'});
            return;
          }
          writeJson(request, 401, {'error': 'invalid token'});
        });
        tokens = TokenStore()..accessToken = 'expired-token';
        await initClient();

        final res = await fetchData();

        expect(res.isSuccess, isFalse);
        expect(refreshCallsLocal, 0);
        expect(logoutCount, 1);
      },
    );

    test('skipAuth requests never trigger the refresh flow', () async {
      var refreshCallsLocal = 0;
      server = await TestServer.start((request) async {
        if (request.uri.path == '/refresh') {
          refreshCallsLocal++;
          writeJson(request, 200, {'access': 'new-access'});
          return;
        }
        writeJson(request, 401, {'error': 'invalid token'});
      });
      tokens = TokenStore()
        ..accessToken = 'expired-token'
        ..refreshToken = 'valid-refresh';
      await initClient();

      final res = await client.get(
        path: '/data',
        fromJson: (data) => data as Map<String, dynamic>,
        skipAuth: true,
      );

      expect(res.isSuccess, isFalse);
      expect(res.error, 'invalid token');
      expect(refreshCallsLocal, 0);
      expect(logoutCount, 0);
    });
  });
}
