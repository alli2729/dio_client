import 'package:dio/dio.dart';

import '../token_storage.dart';

class AccessTokenInterceptor extends Interceptor {
  final TokenStorage tokenStorage;

  AccessTokenInterceptor({required this.tokenStorage});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final accessToken = await tokenStorage.getAccessToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }

      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e, type: DioExceptionType.unknown),
      );
    }
  }
}
