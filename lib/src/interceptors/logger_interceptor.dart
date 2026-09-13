import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only logging with full detail — including the real Authorization
/// header and token bodies — so the refresh-token flow can be debugged from
/// the console. kDebugMode keeps every log out of release builds entirely.
class LoggerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('➡️ [REQUEST]');
      debugPrint('🔸 METHOD: ${options.method}');
      debugPrint('🔸 URL: ${options.uri}');
      if (options.queryParameters.isNotEmpty) {
        debugPrint('🔸 QUERY: ${options.queryParameters}');
      }
      if (options.data != null) {
        debugPrint('🔸 DATA: ${options.data}');
      }
      debugPrint('🔸 HEADERS: ${options.headers}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('✅ [RESPONSE]');
      debugPrint('🔸 STATUS: ${response.statusCode}');
      debugPrint('🔸 URL: ${response.realUri}');
      debugPrint('🔸 DATA: ${response.data}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR]');
      debugPrint('🔸 TYPE: ${err.type}');
      debugPrint('🔸 MESSAGE: ${err.message}');
      debugPrint('🔸 URL: ${err.requestOptions.uri}');
      if (err.response != null) {
        debugPrint('🔸 STATUS: ${err.response?.statusCode}');
        debugPrint('🔸 DATA: ${err.response?.data}');
      }
    }
    handler.next(err);
  }
}
