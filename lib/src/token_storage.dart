import 'dart:async';

typedef TokenGetter = FutureOr<String?> Function();
typedef TokenSaver =
    FutureOr<void> Function({
      required String accessToken,
      required String refreshToken,
    });
typedef VoidCallbackAsync = FutureOr<void> Function();

class TokenStorage {
  final TokenGetter getAccessToken;
  final TokenGetter getRefreshToken;
  final TokenSaver saveTokens;
  final VoidCallbackAsync clearTokensOnLogout;

  TokenStorage({
    required this.getAccessToken,
    required this.getRefreshToken,
    required this.saveTokens,
    required this.clearTokensOnLogout,
  });
}
