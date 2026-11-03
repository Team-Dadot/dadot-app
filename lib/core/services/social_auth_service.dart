import '../../data/models/auth.dart';

/// 사용자가 로그인 창을 닫은 경우. 화면은 조용히 무시한다.
class SocialAuthCancelled implements Exception {
  const SocialAuthCancelled();
}

/// 카카오 · Apple · Google SDK 로그인을 감싼다.
/// SDK 에서 받은 토큰을 [SocialCredential] 로 넘기면 서버가 우리 토큰으로 바꿔 준다.
///
/// 실제 SDK 연결 (docs/RELEASE_CHECKLIST.md 2장):
///  - 카카오: kakao_flutter_sdk_user → UserApi.instance.loginWithKakaoTalk / loginWithKakaoAccount
///  - Apple : sign_in_with_apple → SignInWithApple.getAppleIDCredential(nonce: sha256(nonce)) (identityToken, authorizationCode)
///            [nonce] 는 서버 POST /v1/auth/social/apple/challenges 에서 받은 원문. SDK 에는 SHA-256 값을, 서버에는 원문을 보낸다.
///  - Google: google_sign_in → idToken
/// 위 패키지를 넣은 뒤 [SocialAuthService] 를 구현한 클래스를 만들고
/// core/providers.dart 의 socialAuthServiceProvider 에서 바꿔 끼우면 된다.
abstract interface class SocialAuthService {
  Future<SocialCredential> signIn(SocialProvider provider, {String? nonce});

  /// SDK 쪽 로그인 상태도 정리 (로그아웃 · 탈퇴)
  Future<void> signOut();
}

/// SDK 연결 전 개발용. 바로 가짜 토큰을 돌려준다.
class FakeSocialAuthService implements SocialAuthService {
  const FakeSocialAuthService();

  @override
  Future<SocialCredential> signIn(SocialProvider provider, {String? nonce}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return SocialCredential(
      provider: provider,
      token: 'fake-${provider.wire.toLowerCase()}-token',
      authorizationCode: provider == SocialProvider.apple ? 'fake-apple-code' : null,
      nonce: nonce,
    );
  }

  @override
  Future<void> signOut() async {}
}
