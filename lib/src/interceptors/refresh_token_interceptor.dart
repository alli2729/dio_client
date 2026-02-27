import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../token_storage.dart';
import 'logger_interceptor.dart';

class RefreshTokenInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage tokenStorage;
  final String refreshEndpoint;
  final String refreshHttpMethod;
  final Map<String, dynamic>? refreshExtraData;
  final int maxRetry;
  final VoidCallback onLogout;

  Completer<bool>? _refreshCompleter;

  static const String _kAccessToken = 'accessToken';
  static const String _kRefreshToken = 'refreshToken';
  static const String _kTokenExpired = 'token_expired';
  static const String _kErrorReason = 'reason';

  RefreshTokenInterceptor({
    required this.dio,
    required this.tokenStorage,
    required this.refreshEndpoint,
    required this.onLogout,
    this.refreshHttpMethod = 'POST',
    this.refreshExtraData,
    this.maxRetry = 1,
  });

  bool _isRefreshRequest(RequestOptions req) {
    return req.extra['isRefresh'] == true;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final data = err.response?.data;
    final errReason = data is Map ? data[_kErrorReason] : null;
    final isTokenExpired = errReason == _kTokenExpired;

    final req = err.requestOptions;
    final retryCount = (req.extra['retry'] as int?) ?? 0;

    if (retryCount >= maxRetry) {
      handler.next(err);
      return;
    }

    if (_isRefreshRequest(req)) {
      await tokenStorage.clearTokensOnLogout();
      handler.next(err);
      return;
    }

    if (status != 401 || !isTokenExpired) {
      handler.next(err);
      return;
    }

    if (_refreshCompleter != null) {
      final success = await _refreshCompleter!.future;
      if (success) {
        try {
          final r = await _retryRequest(req);
          return handler.resolve(r);
        } catch (e) {
          return handler.next(e is DioException ? e : err);
        }
      } else {
        return handler.next(err);
      }
    }

    _refreshCompleter = Completer<bool>();
    final success = await _performRefresh();
    _refreshCompleter?.complete(success);
    _refreshCompleter = null;

    if (!success) {
      await tokenStorage.clearTokensOnLogout();
      onLogout();
      return handler.next(err);
    }

    try {
      final r = await _retryRequest(req);
      handler.resolve(r);
    } catch (e) {
      handler.next(e is DioException ? e : err);
    }
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: dio.options.connectTimeout,
          receiveTimeout: dio.options.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      refreshDio.interceptors.add(LoggerInterceptor());

      final access = await tokenStorage.getAccessToken();
      final refresh = await tokenStorage.getRefreshToken();

      final data = {
        ...?refreshExtraData,
        _kAccessToken: access,
        _kRefreshToken: refresh,
      };

      final reqOptions = Options(extra: {'isRefresh': true});

      late Response res;

      switch (refreshHttpMethod.toUpperCase()) {
        case 'POST':
          res = await refreshDio.post(refreshEndpoint, data: data, options: reqOptions);
          break;
        case 'PUT':
          res = await refreshDio.put(refreshEndpoint, data: data, options: reqOptions);
          break;
        case 'GET':
          res = await refreshDio.get(
            refreshEndpoint,
            queryParameters: data,
            options: reqOptions,
          );
          break;
        default:
          res = await refreshDio.post(refreshEndpoint, data: data, options: reqOptions);
          break;
      }

      final newAT = res.data[_kAccessToken] as String?;
      final newRT = res.data[_kRefreshToken] as String?;

      if (newAT == null || newRT == null) return false;

      await tokenStorage.saveTokens(accessToken: newAT, refreshToken: newRT);
      return true;
    } catch (e) {
      debugPrint("Refresh failed: $e");
      _refreshCompleter?.complete(false);
      return false;
    }
  }

  Future<Response> _retryRequest(RequestOptions req) async {
    final token = await tokenStorage.getAccessToken();

    final cloned = RequestOptions(
      path: req.path,
      method: req.method,
      data: req.data,
      queryParameters: req.queryParameters,
      baseUrl: req.baseUrl,
      headers: {
        ...req.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      },
      contentType: req.contentType,
      responseType: req.responseType,
      extra: {
        ...req.extra,
        'retry': (req.extra['retry'] ?? 0) + 1,
      },
    );

    return dio.fetch(cloned);
  }
}
