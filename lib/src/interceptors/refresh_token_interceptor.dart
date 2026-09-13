import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../token_storage.dart';
import 'logger_interceptor.dart';

enum _RefreshOutcome {
  /// Refresh succeeded: both tokens saved; retry the original request.
  success,

  /// Backend explicitly rejected the refresh token (400/401/403) or there is
  /// no refresh token stored: clear tokens and log out.
  rejected,

  /// Timeout / connection error / 5xx / unusable-but-not-rejecting response:
  /// keep tokens and surface the original error.
  transient,
}

class RefreshTokenInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage tokenStorage;
  final String refreshEndpoint;
  final String refreshHttpMethod;
  final Map<String, dynamic>? refreshExtraData;
  final int maxRetry;
  final VoidCallbackAsync onLogout;

  /// Single-flight guard: while a refresh is in flight, concurrent 401s await
  /// this completer instead of starting their own refresh. Only the leader
  /// creates, completes and resets it.
  Completer<bool>? _refreshCompleter;

  /// Guards against overlapping force-logouts while one is still running.
  bool _logoutInFlight = false;

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
    final req = err.requestOptions;
    final status = err.response?.statusCode;
    final retryExtra = req.extra['retry'];
    final retryCount = retryExtra is int ? retryExtra : 0;

    // Refresh ONLY a normal authenticated request whose 401 body is exactly
    // SimpleJWT's expired-AccessToken payload. Unrelated 401s, skipAuth
    // requests, the refresh request itself and already-retried requests pass
    // through untouched.
    final shouldRefresh =
        status == 401 &&
        retryCount < maxRetry &&
        req.extra['skipAuth'] != true &&
        !_isRefreshRequest(req) &&
        _isExpiredAccessToken(err.response?.data);

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    // Stale 401: another request already refreshed the token since this one
    // was sent. Retry with the newer token instead of rotating again.
    final currentToken = await _currentAccessToken();
    final sentAuth = req.headers['Authorization'];
    if (currentToken != null &&
        sentAuth != null &&
        sentAuth != 'Bearer $currentToken') {
      await _retryAndResolve(req, err, handler);
      return;
    }

    // Join an in-flight refresh started by another request.
    final ongoing = _refreshCompleter;
    if (ongoing != null) {
      final success = await ongoing.future;
      if (success) {
        await _retryAndResolve(req, err, handler);
      } else {
        handler.next(err);
      }
      return;
    }

    // Leader: creates the completer. The flow below guarantees it is
    // completed exactly once and reset even if the refresh throws.
    final completer = Completer<bool>();
    _refreshCompleter = completer;
    var outcome = _RefreshOutcome.transient;
    try {
      outcome = await _performRefresh();
    } finally {
      if (!completer.isCompleted) {
        completer.complete(outcome == _RefreshOutcome.success);
      }
      _refreshCompleter = null;
    }

    if (outcome == _RefreshOutcome.success) {
      await _retryAndResolve(req, err, handler);
      return;
    }

    if (outcome == _RefreshOutcome.rejected) {
      await _forceLogout();
    }

    // transient: keep tokens, surface the original error.
    handler.next(err);
  }

  /// Strict SimpleJWT expired-access-token match: code == token_not_valid AND
  /// messages contains exactly {token_class: AccessToken, token_type: access,
  /// message: "Token is expired"}. Invalid / blacklisted tokens and any other
  /// 401 never trigger a refresh.
  bool _isExpiredAccessToken(dynamic data) {
    if (data is! Map) return false;

    if (data['code'] != 'token_not_valid') {
      return false;
    }

    final messages = data['messages'];

    if (messages is! List) {
      return false;
    }

    return messages.any(
      (message) =>
          message is Map &&
          message['token_class'] == 'AccessToken' &&
          message['token_type'] == 'access' &&
          message['message'] == 'Token is expired',
    );
  }

  Future<_RefreshOutcome> _performRefresh() async {
    try {
      final refresh = await tokenStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        return _RefreshOutcome.rejected;
      }

      // Separate Dio instance: the refresh call never re-enters this
      // interceptor, and with no AccessTokenInterceptor attached it carries
      // no Authorization header.
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: dio.options.connectTimeout,
          receiveTimeout: dio.options.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      );
      refreshDio.interceptors.add(LoggerInterceptor());

      final body = {...?refreshExtraData, 'refresh': refresh};
      final options = Options(extra: {'isRefresh': true});

      late Response res;
      switch (refreshHttpMethod.toUpperCase()) {
        case 'PUT':
          res = await refreshDio.put(
            refreshEndpoint,
            data: body,
            options: options,
          );
          break;
        case 'GET':
          res = await refreshDio.get(
            refreshEndpoint,
            queryParameters: body,
            options: options,
          );
          break;
        default:
          res = await refreshDio.post(
            refreshEndpoint,
            data: body,
            options: options,
          );
          break;
      }

      final data = res.data;
      final newAccess = data is Map ? data['access'] as String? : null;
      final newRefresh = data is Map ? data['refresh'] as String? : null;

      if (newAccess == null ||
          newAccess.isEmpty ||
          newRefresh == null ||
          newRefresh.isEmpty) {
        // 200 but unusable body: no evidence the refresh token was rejected,
        // so keep the session and surface the error instead.
        debugPrint('Refresh response is missing access/refresh fields');
        return _RefreshOutcome.transient;
      }

      await tokenStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return _RefreshOutcome.success;
    } on DioException catch (e) {
      debugPrint(
        'Refresh failed: ${e.type}'
        '${e.response?.statusCode != null ? ' (${e.response?.statusCode})' : ''}',
      );
      // Only an explicit server rejection (400/401/403) destroys the session.
      // Timeouts, connection errors and 5xx are transient.
      final status = e.response?.statusCode;
      return (status == 400 || status == 401 || status == 403)
          ? _RefreshOutcome.rejected
          : _RefreshOutcome.transient;
    } catch (e) {
      debugPrint('Refresh failed: $e');
      return _RefreshOutcome.transient;
    }
  }

  Future<void> _retryAndResolve(
    RequestOptions req,
    DioException originalError,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final token = await tokenStorage.getAccessToken();
      final previousRetries = req.extra['retry'] is int
          ? req.extra['retry'] as int
          : 0;
      // copyWith preserves method, path, query, body, headers, timeouts,
      // responseType, cancelToken, validateStatus and progress callbacks;
      // only Authorization and the retry counter are overridden.
      final cloned = req.copyWith(
        headers: {
          ...req.headers,
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        extra: {
          ...req.extra,
          'retry': previousRetries + 1,
        },
      );
      final response = await dio.fetch<dynamic>(cloned);
      handler.resolve(response);
    } catch (e) {
      handler.next(e is DioException ? e : originalError);
    }
  }

  Future<void> _forceLogout() async {
    if (_logoutInFlight) return;
    _logoutInFlight = true;
    try {
      final hadSession = await _hasAnyToken();
      await tokenStorage.clearTokensOnLogout();
      // Stragglers arriving after the first logout find no tokens and must
      // not trigger onLogout (duplicate navigation) again.
      if (hadSession) {
        await onLogout();
      }
    } catch (e) {
      debugPrint('Force logout failed: $e');
    } finally {
      _logoutInFlight = false;
    }
  }

  Future<bool> _hasAnyToken() async {
    try {
      final access = await tokenStorage.getAccessToken();
      if (access != null && access.isNotEmpty) return true;
      final refresh = await tokenStorage.getRefreshToken();
      return refresh != null && refresh.isNotEmpty;
    } catch (_) {
      return true; // storage unreadable: assume a session may exist
    }
  }

  Future<String?> _currentAccessToken() async {
    try {
      return await tokenStorage.getAccessToken();
    } catch (_) {
      return null;
    }
  }
}
