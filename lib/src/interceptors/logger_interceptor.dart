import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class LoggerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
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
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('✅ [RESPONSE]');
    debugPrint('🔸 STATUS: ${response.statusCode}');
    debugPrint('🔸 URL: ${response.realUri}');
    debugPrint('🔸 DATA: ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ [ERROR]');
    debugPrint('🔸 TYPE: ${err.type}');
    debugPrint('🔸 MESSAGE: ${err.message}');
    debugPrint('🔸 URL: ${err.requestOptions.uri}');
    if (err.response != null) {
      debugPrint('🔸 STATUS: ${err.response?.statusCode}');
      debugPrint('🔸 DATA: ${err.response?.data}');
    }
    handler.next(err);
  }
}
