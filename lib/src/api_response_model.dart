import 'package:either_dart/either.dart';

import 'default_error.dart';

class ApiResponse<T> {
  /// Value used for [error] when no error message is provided (e.g. success
  /// responses or backend errors with a missing/malformed error payload).
  ///
  /// Defaults to `'Unknown error'`; the consuming app can override it once
  /// via `DioClient.init(defaultError: ...)`.
  static String get defaultError => configuredDefaultError();

  final int statusCode;
  final T? data;

  /// Non-nullable: the backend error message, or [defaultError] if none.
  final String error;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  ApiResponse({
    required this.statusCode,
    this.data,
    String? error,
  }) : error = error ?? configuredDefaultError();

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
