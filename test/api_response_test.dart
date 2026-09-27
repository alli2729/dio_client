import 'package:dio_client/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiResponse', () {
    test('error defaults to a non-null "Unknown error"', () {
      final res = ApiResponse<int>(statusCode: 500);

      expect(res.error, 'Unknown error');
      expect(res.error, isA<String>());
      expect(() => res.error.length, returnsNormally);
    });

    test('error default is configurable via the constructor', () {
      final res = ApiResponse<int>(statusCode: 500, error: 'Server exploded');

      expect(res.error, 'Server exploded');
    });

    test('fold onLeft receives the non-null error message', () {
      final res = ApiResponse<int>(statusCode: 401, error: 'invalid token');

      final either = res.fold((error) => error, (data) => 'should not run');

      expect(either.isLeft, isTrue);
      expect(either.left, 'invalid token');
    });

    test('fold onLeft receives the default when no error is given', () {
      final res = ApiResponse<int>(statusCode: 500);

      final either = res.fold((error) => error, (data) => 'right');

      expect(either.isLeft, isTrue);
      expect(either.left, 'Unknown error');
    });

    test('fold returns Right on success with data', () {
      final res = ApiResponse<int>(statusCode: 200, data: 42);

      final either = res.fold((error) => 'left', (data) => data * 2);

      expect(either.isRight, isTrue);
      expect(either.right, 84);
    });

    test('fold maps failure when success status but data is null', () {
      final res = ApiResponse<int>(statusCode: 204);

      final either = res.fold((error) => error, (data) => 'right');

      expect(either.isLeft, isTrue);
      expect(either.left, 'Unknown error');
    });

    test('fold still supports transforming T to another type U', () {
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
