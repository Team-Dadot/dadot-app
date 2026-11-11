import 'dart:convert';
import 'dart:math';

/// 한 로그인과 진행 중인 갱신 작업. 토큰 원문은 로그로 출력하지 않는다.
class AuthTokenState {
  const AuthTokenState({
    required this.sessionId,
    required this.accessToken,
    this.refreshToken,
    this.refreshKey,
  });

  factory AuthTokenState.create(String access, String? refresh) {
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return AuthTokenState(sessionId: id, accessToken: access, refreshToken: refresh);
  }

  factory AuthTokenState.decode(String raw) {
    final data = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return AuthTokenState(
      sessionId: data['sessionId'] as String,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      refreshKey: data['refreshKey'] as String?,
    );
  }

  final String sessionId;
  final String accessToken;
  final String? refreshToken;
  final String? refreshKey;

  String encode() => jsonEncode({
    'sessionId': sessionId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'refreshKey': refreshKey,
  });

  @override
  String toString() => 'AuthTokenState(REDACTED)';
}
