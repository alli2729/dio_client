import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'api_response_model.dart';
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
  final VoidCallback onLogout;

  // refresh config
  final String refreshEndpoint;
  final String refreshHttpMethod;
  final Map<String, dynamic>? refreshExtraData;

  // interceptor retry limits
  final int maxRetry;

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
    required VoidCallback onLogout,
    String? globalVersion,
    bool useGlobalVersion = true,
    required String refreshEndpoint,
    String refreshHttpMethod = 'POST',
    Map<String, dynamic>? refreshExtraData,
    int? connectTimeoutSeconds,
    int? receiveTimeoutSeconds,
    Map<String, dynamic>? headers,
    int maxRetry = 1,
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
    final message = e.response?.data.toString() ?? e.message ?? 'Unknown error';
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
