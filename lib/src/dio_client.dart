import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_response_model.dart';

typedef TokenProvider = String Function();

class DioClient {
  static DioClient? _instance;

  final Dio _dio;
  final String baseUrl;
  final TokenProvider tokenProvider;
  final String? globalVersion;
  final bool useGlobalVersion;

  DioClient._internal({
    required this.baseUrl,
    required this.tokenProvider,
    this.globalVersion,
    this.useGlobalVersion = true,
    int? connectTimeoutSeconds,
    int? receiveTimeoutSeconds,
    Map<String, dynamic>? headers,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: Duration(seconds: connectTimeoutSeconds ?? 10),
           receiveTimeout: Duration(seconds: receiveTimeoutSeconds ?? 10),
           headers: {'Content-Type': 'application/json', ...?headers},
         ),
       ) {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider();
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

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
        },
        onResponse: (res, handler) {
          debugPrint('✅ [RESPONSE]');
          debugPrint('🔸 STATUS: ${res.statusCode}');
          debugPrint('🔸 URL: ${res.realUri}');
          debugPrint('🔸 DATA: ${res.data}');
          handler.next(res);
        },
        onError: (e, handler) {
          debugPrint('❌ [ERROR]');
          debugPrint('🔸 TYPE: ${e.type}');
          debugPrint('🔸 MESSAGE: ${e.message}');
          debugPrint('🔸 URL: ${e.requestOptions.uri}');
          if (e.response != null) {
            debugPrint('🔸 STATUS: ${e.response?.statusCode}');
            debugPrint('🔸 DATA: ${e.response?.data}');
          }
          handler.next(e);
        },
      ),
    );
  }

  factory DioClient.init({
    required String baseUrl,
    required TokenProvider tokenProvider,
    String? globalVersion,
    bool useGlobalVersion = true,
    int? connectTimeoutSeconds,
    int? receiveTimeoutSeconds,
    Map<String, dynamic>? headers,
  }) {
    _instance = DioClient._internal(
      baseUrl: baseUrl,
      tokenProvider: tokenProvider,
      globalVersion: globalVersion,
      useGlobalVersion: useGlobalVersion,
      connectTimeoutSeconds: connectTimeoutSeconds,
      receiveTimeoutSeconds: receiveTimeoutSeconds,
      headers: headers,
    );
    return _instance!;
  }

  factory DioClient() {
    if (_instance == null) {
      throw Exception('DioClient not initialized. Call DioClient.init(...) first.');
    }
    return _instance!;
  }

  Future<ApiResponse<T>> get<T>({
    required String path,
    required T Function(dynamic data) fromJson,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool? includeVersion,
    String? overrideVersion,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final resolvedPath = _resolvePath(
        path,
        includeVersion: includeVersion,
        overrideVersion: overrideVersion,
      );

      final res = await _dio.get(
        resolvedPath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse(res, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  Future<ApiResponse<T>> post<T>({
    required String path,
    required T Function(dynamic data) fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool? includeVersion,
    String? overrideVersion,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final resolvedPath = _resolvePath(
        path,
        includeVersion: includeVersion,
        overrideVersion: overrideVersion,
      );

      final res = await _dio.post(
        resolvedPath,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse(res, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  Future<ApiResponse<T>> put<T>({
    required String path,
    required T Function(dynamic data) fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool? includeVersion,
    String? overrideVersion,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final resolvedPath = _resolvePath(
        path,
        includeVersion: includeVersion,
        overrideVersion: overrideVersion,
      );

      final res = await _dio.put(
        resolvedPath,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse(res, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  Future<ApiResponse<T>> patch<T>({
    required String path,
    required T Function(dynamic data) fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool? includeVersion,
    String? overrideVersion,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final resolvedPath = _resolvePath(
        path,
        includeVersion: includeVersion,
        overrideVersion: overrideVersion,
      );

      final res = await _dio.patch(
        resolvedPath,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse(res, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  Future<ApiResponse<T>> delete<T>({
    required String path,
    required T Function(dynamic data) fromJson,
    dynamic data,
    bool? includeVersion,
    String? overrideVersion,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final resolvedPath = _resolvePath(
        path,
        includeVersion: includeVersion,
        overrideVersion: overrideVersion,
      );

      final res = await _dio.delete(
        resolvedPath,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse(res, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  ApiResponse<T> _handleResponse<T>(
    Response response,
    T Function(dynamic data) fromJson,
  ) {
    try {
      final raw = response.data;

      if (raw is String && T == String) {
        return ApiResponse(statusCode: response.statusCode ?? 200, data: raw as T);
      }

      final parsed = fromJson(raw);
      return ApiResponse(statusCode: response.statusCode ?? 200, data: parsed);
    } catch (e) {
      return ApiResponse(
        statusCode: response.statusCode ?? 500,
        error: 'Failed to parse response: $e',
      );
    }
  }

  ApiResponse<T> _handleError<T>(DioException e) {
    final statusCode = e.response?.statusCode ?? 500;
    final message = e.response?.data['message'] ?? e.message ?? 'Unknown error';
    return ApiResponse<T>(statusCode: statusCode, error: message);
  }

  String _resolvePath(String path, {bool? includeVersion, String? overrideVersion}) {
    if (overrideVersion != null) {
      return "/$overrideVersion$path";
    }

    if ((includeVersion ?? useGlobalVersion) && globalVersion != null) {
      return "/$globalVersion$path";
    }

    return path;
  }
}
