/// 로그인 · 사용자 모델. JSON 키는 docs/API_CONTRACT.md 기준.
library;

enum SocialProvider {
  kakao('KAKAO', '카카오로 시작하기'),
  apple('APPLE', 'Apple로 시작하기'),
  google('GOOGLE', 'Google로 시작하기');

  const SocialProvider(this.wire, this.buttonLabel);

  /// 서버로 보내는 값
  final String wire;
  final String buttonLabel;
}

/// 가입·로그인 방식 (마이 "이메일로 이용 중", 회원정보 "로그인 방식")
enum LoginMethod {
  kakao('KAKAO', '카카오'),
  apple('APPLE', 'Apple'),
  google('GOOGLE', 'Google'),
  email('EMAIL', '이메일');

  const LoginMethod(this.wire, this.label);
  final String wire;
  final String label;

  /// 회원정보 수정 화면 표기
  String get detailLabel => this == LoginMethod.email ? '이메일·비밀번호' : '$label 계정';

  static LoginMethod fromWire(String? v) => LoginMethod.values.firstWhere((e) => e.wire == v, orElse: () => LoginMethod.email);
}

/// 소셜 SDK 로그인 결과 (서버에 보내서 우리 토큰으로 바꾼다)
class SocialCredential {
  const SocialCredential({required this.provider, required this.token, this.authorizationCode, this.nonce});

  final SocialProvider provider;

  /// 카카오 accessToken / Apple identityToken / Google idToken
  final String token;

  /// Apple 은 authorizationCode 도 함께 보낸다 (탈퇴 시 토큰 철회용)
  final String? authorizationCode;

  /// Apple: 서버 인증 준비 API(POST /v1/auth/social/apple/challenges)에서 받은 nonce 원문
  final String? nonce;

  /// 다닷 서버 요청 본문. 카카오 {accessToken} / Apple {identityToken, authorizationCode, nonce}
  Map<String, dynamic> toJson() => switch (provider) {
        SocialProvider.apple => {'identityToken': token, 'authorizationCode': authorizationCode, 'nonce': nonce},
        SocialProvider.kakao => {'accessToken': token},
        SocialProvider.google => {'idToken': token},
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.nickname,
    required this.loginMethod,
    required this.onboardingCompleted,
    this.email,
    this.avatarIndex = 0,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'].toString(),
        nickname: json['nickname'] as String? ?? '',
        email: json['email'] as String?,
        loginMethod: LoginMethod.fromWire(json['loginMethod'] as String?),
        avatarIndex: json['avatarIndex'] as int? ?? 0,
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      );

  final String id;
  final String nickname;
  final String? email;
  final LoginMethod loginMethod;

  /// 프로필 이미지 (기본 이미지 5개 중 번호)
  final int avatarIndex;
  final bool onboardingCompleted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'email': email,
        'loginMethod': loginMethod.wire,
        'avatarIndex': avatarIndex,
        'onboardingCompleted': onboardingCompleted,
      };

  AppUser copyWith({String? nickname, int? avatarIndex, bool? onboardingCompleted}) => AppUser(
        id: id,
        nickname: nickname ?? this.nickname,
        email: email,
        loginMethod: loginMethod,
        avatarIndex: avatarIndex ?? this.avatarIndex,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.user, required this.isNewUser});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
        isNewUser: json['isNewUser'] as bool? ?? false,
      );

  final String accessToken;
  final String? refreshToken;
  final AppUser user;
  final bool isNewUser;
}

/// 가입 약관 (GET /v1/app-config → signupTerms). 가입 요청의 acceptedTermsIds 로 보낸다.
class SignupTerm {
  const SignupTerm({required this.id, required this.title, required this.required, this.url});

  factory SignupTerm.fromJson(Map<String, dynamic> json) => SignupTerm(
        id: json['termsId'].toString(),
        title: json['title'] as String? ?? '',
        required: json['required'] as bool? ?? true,
        url: json['url'] as String?,
      );

  final String id;
  final String title;
  final bool required;
  final String? url;
}

/// 소셜 로그인 결과가 SIGN_UP_REQUIRED 일 때. 약관 동의 후 [registrationToken] 으로 가입을 마친다 (10분 유효).
class SocialSignUpRequired implements Exception {
  const SocialSignUpRequired({required this.registrationToken, required this.provider});

  final String registrationToken;
  final SocialProvider provider;
}

/// 서버 앱 설정 (GET /v1/app-config): 가입 약관 · 문서 링크 · 문의 구글폼
class ServerAppConfig {
  const ServerAppConfig({required this.terms, this.termsUrl, this.privacyPolicyUrl, this.inquiryFormUrl, this.signupAvailable = true});

  factory ServerAppConfig.fromJson(Map<String, dynamic> json) => ServerAppConfig(
        terms: (json['signupTerms'] as List<dynamic>? ?? const [])
            .map((e) => SignupTerm.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        termsUrl: json['termsUrl'] as String?,
        privacyPolicyUrl: json['privacyPolicyUrl'] as String?,
        inquiryFormUrl: json['inquiryFormUrl'] as String?,
        signupAvailable: json['signupAvailable'] as bool? ?? true,
      );

  final List<SignupTerm> terms;
  final String? termsUrl;
  final String? privacyPolicyUrl;

  /// 문의는 구글폼으로 받는다. null 이면 앱 안 문의 화면 (Mock)
  final String? inquiryFormUrl;
  final bool signupAvailable;
}

/// 이메일 인증 목적 (POST /v1/auth/email-verifications)
enum EmailCodePurpose {
  signUp('SIGN_UP'),
  passwordReset('PASSWORD_RESET'),
  passwordChange('PASSWORD_CHANGE');

  const EmailCodePurpose(this.wire);
  final String wire;
}
