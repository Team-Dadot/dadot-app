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
  const SocialCredential({required this.provider, required this.token, this.authorizationCode});

  final SocialProvider provider;

  /// 카카오 accessToken / Apple identityToken / Google idToken
  final String token;

  /// Apple 은 authorizationCode 도 함께 보낸다 (탈퇴 시 토큰 철회용)
  final String? authorizationCode;

  Map<String, dynamic> toJson() => {
        'provider': provider.wire,
        'token': token,
        if (authorizationCode != null) 'authorizationCode': authorizationCode,
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
