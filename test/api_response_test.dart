import 'package:dio_client/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('ApiResponse', () {
    void initClient({String? defaultError}) {
      DioClient.init(
        baseUrl: 'http://localhost:1',
        tokenStorage: TokenStore().toTokenStorage(),
        onLogout: () {},
        refreshEndpoint: '/refresh',
        defaultError: defaultError,
      );
    }

    test('error defaults to a non-null "Unknown error"', () {
      initClient();

      final res = ApiResponse<int>(statusCode: 500);

      expect(res.error, 'Unknown error');
      expect(res.error, isA<String>());
      expect(() => res.error.length, returnsNormally);
    });

    test('error default is configurable via the constructor', () {
      final res = ApiResponse<int>(statusCode: 500, error: 'Server exploded');

      expect(res.error, 'Server exploded');
    });

    test('explicit error wins over the configured default', () {
      initClient(defaultError: 'خطای نامشخص');

      final res = ApiResponse<int>(statusCode: 500, error: 'boom');

      expect(res.error, 'boom');
    });

    test('uses the app-configured defaultError from DioClient.init', () {
      initClient(defaultError: 'خطای نامشخص');

      final res = ApiResponse<int>(statusCode: 500);

      expect(res.error, 'خطای نامشخص');
      expect(ApiResponse.defaultError, 'خطای نامشخص');
    });

    test('re-initializing without defaultError resets to "Unknown error"', () {
      initClient(defaultError: 'خطای نامشخص');
      expect(ApiResponse.defaultError, 'خطای نامشخص');

      initClient();
      expect(ApiResponse.defaultError, 'Unknown error');

      final res = ApiResponse<int>(statusCode: 500);
      expect(res.error, 'Unknown error');
    });

    test('fold onLeft receives the non-null error message', () {
      initClient();

      final res = ApiResponse<int>(statusCode: 401, error: 'invalid token');

      final either = res.fold((error) => error, (data) => 'should not run');

      expect(either.isLeft, isTrue);
      expect(either.left, 'invalid token');
    });

    test('fold onLeft receives the default when no error is given', () {
      initClient();

      final res = ApiResponse<int>(statusCode: 500);

      final either = res.fold((error) => error, (data) => 'right');

      expect(either.isLeft, isTrue);
      expect(either.left, 'Unknown error');
    });

    test('fold onLeft receives the configured default', () {
      initClient(defaultError: 'خطای نامشخص');

      final res = ApiResponse<int>(statusCode: 500);

      final either = res.fold((error) => error, (data) => 'right');

      expect(either.isLeft, isTrue);
      expect(either.left, 'خطای نامشخص');
    });

    test('fold returns Right on success with data', () {
      initClient();

      final res = ApiResponse<int>(statusCode: 200, data: 42);

      final either = res.fold((error) => 'left', (data) => data * 2);

      expect(either.isRight, isTrue);
      expect(either.right, 84);
    });

    test('fold maps failure when success status but data is null', () {
      initClient();

      final res = ApiResponse<int>(statusCode: 204);

      final either = res.fold((error) => error, (data) => 'right');

      expect(either.isLeft, isTrue);
      expect(either.left, 'Unknown error');
    });

    test('fold still supports transforming T to another type U', () {
      initClient();

      final res = ApiResponse<int>(statusCode: 200, data: 2);

      final either = res.fold((error) => error, (data) => data.toString());

      expect(either.isRight, isTrue);
      expect(either.right, '2');
    });

    test('isSuccess boundaries remain intact', () {
      expect(ApiResponse<void>(statusCode: 199).isSuccess, isFalse);
      expect(ApiResponse<void>(statusCode: 200).isSuccess, isTrue);
      expect(ApiResponse<void>(statusCode: 299).isSuccess, isTrue);
      expect(ApiResponse<void>(statusCode: 300).isSuccess, isFalse);
    });
  });
}
