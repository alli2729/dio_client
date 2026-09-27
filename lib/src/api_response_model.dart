import 'package:either_dart/either.dart';

class ApiResponse<T> {
  /// Value used for [error] when no error message is provided (e.g. success
  /// responses or backend errors with a missing/malformed error payload).
  static const String defaultError = 'Unknown error';

  final int statusCode;
  final T? data;

  /// Non-nullable: the backend error message, or [defaultError] if none.
  final String error;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  ApiResponse({
    required this.statusCode,
    this.data,
    this.error = defaultError,
  });

  /// Supports transforming T to any other type U for the right side
  Either<String, U> fold<U>(
    String Function(String error) onLeft,
    U Function(T data) onRight,
  ) {
    if (isSuccess && data != null) {
      return Right(onRight(data as T));
    } else {
      return Left(onLeft(error));
    }
  }
}
