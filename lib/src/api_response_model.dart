import 'package:either_dart/either.dart';

class ApiResponse<T> {
  final int statusCode;
  final T? data;
  final String? error;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  ApiResponse({required this.statusCode, this.data, this.error});

  /// Supports transforming T to any other type U for the right side
  Either<String, U> fold<U>(
    String Function(String? error) onLeft,
    U Function(T data) onRight,
  ) {
    if (isSuccess && data != null) {
      return Right(onRight(data as T));
    } else {
      return Left(onLeft(error ?? 'Unknown error'));
    }
  }
}
