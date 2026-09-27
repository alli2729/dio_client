import 'dart:async';

import 'package:dio/dio.dart';

import 'api_response_model.dart';
import 'default_error.dart';
import 'interceptors/access_token_interceptor.dart';
import 'interceptors/logger_interceptor.dart';
import 'interceptors/refresh_token_interceptor.dart';
import 'token_storage.dart';

class DioClient {
  static DioClient? _instance;

  final Dio _dio;
  final String baseUrl;
  final TokenStorage tokenStorage;
  final String? globalVersion;
  final bool useGlobalVersion;
  final VoidCallbackAsync onLogout;

  // refresh config
  final String refreshEndpoint;
  final String refreshHttpMethod;
  final Map<String, dynamic>? refreshExtraData;

  // interceptor retry limits
  final int maxRetry;

  /// Default error message used by [ApiResponse.error] when no error is
  /// provided; configurable app-wide via `DioClient.init(defaultError: ...)`.
  final String defaultError;

  DioClient._internal({
    required this.baseUrl,
    required this.tokenStorage,
    required this.onLogout,
    this.globalVersion,
    this.useGlobalVersion = true,
    required this.refreshEndpoint,
    this.refreshHttpMethod = 'POST',
    this.refreshExtraData,
    this.maxRetry = 1,
    String? defaultError,
    int? connectTimeoutSeconds,
    int? receiveTimeoutSeconds,
    Map<String, dynamic>? headers,
  }) : defaultError = resolveDefaultError(defaultError),
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: Duration(seconds: connectTimeoutSeconds ?? 10),
           receiveTimeout: Duration(seconds: receiveTimeoutSeconds ?? 10),
           headers: {'Content-Type': 'application/json', ...?headers},
         ),
       ) {
    // Apply app-wide before anything can build an ApiResponse, so both
    // client-generated and manually constructed responses use it.
    configureDefaultError(this.defaultError);

    _dio.interceptors.clear();
    _dio.interceptors.add(AccessTokenInterceptor(tokenStorage: tokenStorage));
    _dio.interceptors.add(
      RefreshTokenInterceptor(
        dio: _dio,
        tokenStorage: tokenStorage,
        refreshEndpoint: refreshEndpoint,
        refreshHttpMethod: refreshHttpMethod,
        refreshExtraData: refreshExtraData,
        maxRetry: maxRetry,
        onLogout: onLogout,
      ),
    );
    _dio.interceptors.add(LoggerInterceptor());
  }

  static DioClient init({
    required String baseUrl,
    required TokenStorage tokenStorage,
    required VoidCallbackAsync onLogout,
    String? globalVersion,
    bool useGlobalVersion = true,
    required String refreshEndpoint,
    String refreshHttpMethod = 'POST',
    Map<String, dynamic>? refreshExtraData,
    int? connectTimeoutSeconds,
    int? receiveTimeoutSeconds,
    Map<String, dynamic>? headers,
    int maxRetry = 1,
    String? defaultError,
  }) {
    _instance = DioClient._internal(
      baseUrl: baseUrl,
      onLogout: onLogout,
      tokenStorage: tokenStorage,
      globalVersion: globalVersion,
      useGlobalVersion: useGlobalVersion,
      refreshEndpoint: refreshEndpoint,
      refreshHttpMethod: refreshHttpMethod,
      refreshExtraData: refreshExtraData,
      connectTimeoutSeconds: connectTimeoutSeconds,
      receiveTimeoutSeconds: receiveTimeoutSeconds,
      headers: headers,
      maxRetry: maxRetry,
      defaultError: defaultError,
    );
    return _instance!;
  }

  factory DioClient() {
    if (_instance == null) {
      throw Exception(
        'DioClient not initialized. Call DioClient.init(...) first.',
      );
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
    bool skipAuth = false,
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
        options: _resolveOptions(options, skipAuth: skipAuth),
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
    bool skipAuth = false,
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
        options: _resolveOptions(options, skipAuth: skipAuth),
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
    bool skipAuth = false,
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
        options: _resolveOptions(options, skipAuth: skipAuth),
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
    bool skipAuth = false,
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
        options: _resolveOptions(options, skipAuth: skipAuth),
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
    bool skipAuth = false,
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
        options: _resolveOptions(options, skipAuth: skipAuth),
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
    final statusCode = response.statusCode ?? 200;

    // Non-2xx can reach here only with a custom validateStatus; treat them as
    // errors instead of attempting fromJson on an error payload.
    if (!_isSuccessStatus(statusCode)) {
      return ApiResponse<T>(
        statusCode: statusCode,
        error: _extractErrorMessage(response.data) ?? ApiResponse.defaultError,
      );
    }

    try {
      final raw = response.data;

      if (raw is String && T == String) {
        return ApiResponse(statusCode: statusCode, data: raw as T);
      }

      final parsed = fromJson(raw);
      return ApiResponse(statusCode: statusCode, data: parsed);
    } catch (e) {
      return ApiResponse(
        statusCode: statusCode,
        error: 'Failed to parse response: $e',
      );
    }
  }

  ApiResponse<T> _handleError<T>(DioException e) {
    final statusCode = e.response?.statusCode ?? 500;
    // Server responded: trust only its error body, else the safe default
    // (Dio's badResponse boilerplate is not a backend error message).
    // No response (timeout / connection error): surface Dio's message.
    final message =
        _extractErrorMessage(e.response?.data) ??
        (e.response == null ? e.message : null) ??
        ApiResponse.defaultError;
    return ApiResponse<T>(statusCode: statusCode, error: message);
  }

  bool _isSuccessStatus(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  /// Extracts the backend error message from a response body.
  ///
  /// The backend returns errors as `{"error": "message"}`. Falls back to the
  /// raw body when it is a non-empty plain-text string. Returns null for
  /// missing/malformed payloads so callers can apply [ApiResponse.defaultError].
  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is String) {
        final trimmed = error.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return null;
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      // A string that looks like JSON means a malformed/undecodable error
      // payload; expose the safe default instead of raw JSON text.
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) return null;
      return trimmed;
    }
    return null;
  }

  String _resolvePath(
    String path, {
    bool? includeVersion,
    String? overrideVersion,
  }) {
    if (overrideVersion != null) {
      return "/$overrideVersion$path";
    }

    if ((includeVersion ?? useGlobalVersion) && globalVersion != null) {
      return "/$globalVersion$path";
    }

    return path;
  }

  Options _resolveOptions(
    Options? options, {
    required bool skipAuth,
  }) {
    final resolvedOptions = options ?? Options();

    if (skipAuth) {
      resolvedOptions.extra = {
        ...?resolvedOptions.extra,
        'skipAuth': true,
      };
    }

    return resolvedOptions;
  }
}
