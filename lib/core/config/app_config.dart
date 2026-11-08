/// 실행 환경 설정. 빌드할 때 --dart-define 으로 바꾼다.
///
/// 예) 백엔드 붙이기:
///   flutter run --dart-define=USE_MOCK=false   (기본 서버 https://api.dadot.store)
///
/// 기본값은 Mock 모드라서 백엔드 없이도 앱 전체 흐름을 돌려볼 수 있다.
class AppConfig {
  const AppConfig({
    required this.useMock,
    required this.apiBaseUrl,
    required this.privacyPolicyUrl,
    required this.termsUrl,
    required this.inquiryFormUrl,
    required this.mockLatency,
    required this.kakaoNativeAppKey,
    this.kakaoAppId = 0,
  });

  factory AppConfig.fromEnvironment() {
    const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
    // 다닷 서버. 경로는 Swagger 의 /v1/... 를 그대로 붙인다 (ApiPaths.basePath)
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.dadot.store');
    // 약관 · 개인정보 원문 (노션). 가입 화면 "보기" 와 마이 > 약관 링크가 이 주소로 열린다.
    const privacy = String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: 'https://app.notion.com/p/Dadot-40da1df4ae0481939c45e7eb3dcb17f3');
    const terms = String.fromEnvironment('TERMS_URL', defaultValue: 'https://app.notion.com/p/Dadot-40da1df4ae04803f8503ffdd2f6b2a5c');
    // TODO(운영): 팀 구글폼 주소로 바꾸거나 --dart-define=INQUIRY_FORM_URL=... 로 넣는다
    const inquiryForm = String.fromEnvironment('INQUIRY_FORM_URL', defaultValue: 'https://forms.gle/your-inquiry-form');
    // 카카오 디벨로퍼스 > 앱 > 앱 키 > 네이티브 앱 키. 앱에 들어가는 공개 키라 기본값으로 둔다.
    // 같은 값을 android/gradle.properties 와 ios/Flutter/Kakao.xcconfig 의 KAKAO_NATIVE_APP_KEY 에도 넣는다.
    const kakaoKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY', defaultValue: 'c7bad61811bc0fa198af5d8fb04a9db9');
    // 서버 app.env 의 KAKAO_APP_ID (서버는 카카오 토큰의 app_id 가 이 값이어야 받는다).
    // 네이티브 앱 키는 반드시 이 앱 ID 의 앱에서 발급한 키여야 한다.
    const kakaoAppId = int.fromEnvironment('KAKAO_APP_ID', defaultValue: 1620145);
    return const AppConfig(
      useMock: useMock,
      apiBaseUrl: baseUrl,
      privacyPolicyUrl: privacy,
      termsUrl: terms,
      inquiryFormUrl: inquiryForm,
      mockLatency: Duration(milliseconds: 350),
      kakaoNativeAppKey: kakaoKey,
      kakaoAppId: kakaoAppId,
    );
  }

  /// true 면 앱 안의 가짜 서버(MockBackend)를 쓴다.
  final bool useMock;

  /// 백엔드 주소. 끝에 / 없이.
  final String apiBaseUrl;

  /// 개인정보처리방침 · 이용약관 웹 주소 (스토어 심사에 필요)
  final String privacyPolicyUrl;
  final String termsUrl;

  /// 서비스 문의·오류 제보 구글폼 (6-4 "구글폼으로")
  final String inquiryFormUrl;

  /// Mock 서버 응답 지연 (로딩 화면 확인용)
  final Duration mockLatency;

  /// 카카오 네이티브 앱 키 (비어 있으면 카카오 로그인 대신 안내 오류)
  final String kakaoNativeAppKey;

  /// 서버가 받는 카카오 앱 ID (서버 KAKAO_APP_ID). 0 이면 확인하지 않는다.
  final int kakaoAppId;
}
