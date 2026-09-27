## 1.2.1

- Added `defaultError` option to `DioClient.init`: lets the consuming app set
  the app-wide default error message used by `ApiResponse.error` when no
  error is provided (e.g. `DioClient.init(defaultError: 'خطای نامشخص')`).
  Falls back to `'Unknown error'` when not configured. `ApiResponse.error`
  remains non-nullable.

## 1.2.0

- Standardized backend error parsing: error responses are now read from the
  `{"error": "message"}` JSON structure and exposed through
  `ApiResponse.error` (plain-text bodies are used as a fallback; missing or
  malformed payloads fall back to a safe default).
- Token refresh is now triggered by 401 responses whose body is exactly
  `{"error": "invalid token"}` (replacing the previous SimpleJWT
  `token_not_valid` payload matching). The single-flight guard, retry limit,
  stale-token retry and force-logout behaviour are preserved.
- Refresh responses containing only an `access` field no longer fail: the
  current refresh token is kept unless the backend rotates it.
- `ApiResponse.error` is now non-nullable, defaulting to
  `ApiResponse.defaultError` (`'Unknown error'`); `fold()` callbacks receive a
  non-null `String`.

## 1.1.6

- Maintenance release.

## 0.0.1

- TODO: Describe initial release.
