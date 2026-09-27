/// Package-internal, cross-library configuration for the default error
/// message used by [ApiResponse] when none is provided.
///
/// This file is intentionally not exported from `package:dio_client`; the
/// only supported way to configure it is `DioClient.init(defaultError: ...)`.
const String _fallbackError = 'Unknown error';

String? _configuredError;

/// The active default error message: the app-configured value if set,
/// otherwise `'Unknown error'`.
String configuredDefaultError() => _configuredError ?? _fallbackError;

/// Resolves the default error for an (re-)initialization: an explicit
/// override wins, otherwise the fallback `'Unknown error'` is used.
String resolveDefaultError(String? override) => override ?? _fallbackError;

/// Sets the app-configured default error message.
void configureDefaultError(String value) => _configuredError = value;
