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

  bool _isRefreshing = false;
  final List<_QueuedRequest> _queue = [];

  RefreshTokenInterceptor({
    required this.dio,
    required this.tokenStorage,
    required this.refreshEndpoint,
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

    if (status != 401) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      _queue.add(_QueuedRequest(requestOptions: req, handler: handler));
      return;
    }

    _isRefreshing = true;
    final success = await _performRefresh();
    _isRefreshing = false;

    if (!success) {
      await tokenStorage.clearTokensOnLogout();
      for (final qr in _queue) {
        qr.handler.next(err);
      }
      _queue.clear();
      handler.next(err);
      return;
    }

    // success → retry queued
    _queue.clear();
    await Future.wait(_queue.map(_retryQueued));

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
        'accessToken': access,
        'refreshToken': refresh,
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

      final newAT = res.data['accessToken'] as String?;
      final newRT = res.data['refreshToken'] as String?;

      if (newAT == null || newRT == null) return false;

      await tokenStorage.saveTokens(accessToken: newAT, refreshToken: newRT);
      return true;
    } catch (e) {
      debugPrint("Refresh failed: $e");
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

  Future<void> _retryQueued(_QueuedRequest qr) async {
    try {
      final r = await _retryRequest(qr.requestOptions);
      qr.handler.resolve(r);
    } catch (e) {
      qr.handler.next(
        e is DioException ? e : DioException(requestOptions: qr.requestOptions),
      );
    }
  }
}

class _QueuedRequest {
  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;

  _QueuedRequest({required this.requestOptions, required this.handler});
}
