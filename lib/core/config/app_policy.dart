import '../../data/models/auth.dart';

/// 서비스 정책 값. 피그마 와이어프레임 문구 기준이며, 팀 결정이 필요한 값은 TODO(결정) 로 표시했다.
/// 서버가 내려주는 값(예: 남은 재도전 횟수)은 서버 값을 우선한다.
class AppPolicy {
  AppPolicy._();

  /// 준비 기업 (1-2 "최대 5개까지")
  static const int minCompanies = 1;
  static const int maxCompanies = 5;

  /// 하루 퀴즈 5문제 (모두 객관식, 주관식 없음)
  static const int quizQuestionCount = 5;

  /// 하루 면접 질문 (홈 "0 / 3"), 광고 보면 1개 더
  static const int interviewDailyCount = 3;
  static const int interviewAdBonus = 1;

  /// 같은 질문에 하루 답할 수 있는 횟수 (피드백 "오늘 2번 남음" → 첫 답 포함 3번)
  // TODO(결정 7): 재도전 횟수
  static const int retryPerQuestionDaily = 3;

  /// 피드백 평가 항목 (4-6 "4개 항목 평가": 기업 이해도 · 구체성 · 논리와 구성 · 명확성, 각 25점)
  static const int criteriaCount = 4;
  static const int criterionMaxScore = 25;

  /// 항목 기준 점수 (25점 중 20점 이상이면 충족) · 완성 기준 ("3개 이상이면 완성")
  static const int criterionPassScore = 20;
  static const int completeMetCount = 3;

  /// 서버 판정: 총점 80 이상이면 준비 완료 (미만은 보완 필요)
  static const int completeScore = 80;

  /// 면접 3일 전부터 집중 모드 (2-2)
  static const int focusModeDays = 3;

  /// 내 경험
  static const int maxExperiences = 100;
  static const int experienceMaxLength = 5000;
  static const int experienceTitleMaxLength = 50;

  /// 직접 입력 직무 이름 (서버: 1~50자)
  static const int jobNameMaxLength = 50;

  /// 직무 추가하기 "자주 찾는 직무" (피그마 1212:7788 그대로, 서버 목록과 상관없이 이 순서로 보여 준다).
  /// 서버 직무 목록에 같은 이름이 있으면 그 직무로, 없으면 직접 입력처럼 이름으로 저장한다.
  static const List<String> popularJobNames = ['영업', '마케팅', '인사', '재무·회계', '생산관리', '연구개발', '서버 개발', '앱 개발', '데이터 분석'];

  /// 답변 (4-3)
  // TODO(결정 8): 최소 답변 글자수
  static const int minAnswerLength = 30;
  static const int maxAnswerLength = 2000;

  /// 말로 답하기 (4-4 "3:00 권장"). 3분이 지나면 자동으로 멈춘다.
  static const Duration voiceMaxDuration = Duration(minutes: 3);

  /// 문의 내용 길이
  static const int maxInquiryLength = 1000;

  /// 서버 가입·비밀번호 변경·재설정 정책. 기존 계정 로그인 검증에는 쓰지 않는다.
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 20;
  static const String passwordHint = '8~20자, 영문·숫자·특수문자 포함';
  static const String passwordRule = '8~20자, 영문·숫자·특수문자를 포함하고 공백·제어문자는 사용할 수 없어요.';

  static String? passwordProblem(String value) {
    if (value.length < minPasswordLength || value.length > maxPasswordLength) {
      return '비밀번호는 8~20자로 입력해 주세요.';
    }
    // Java PasswordPolicy의 Unicode Z(공백 구분자)·C(제어/형식 등) 제외와 맞춘다.
    if (RegExp(r'[\s\p{Z}\p{C}]', unicode: true).hasMatch(value)) {
      return '비밀번호에 공백·제어문자를 사용할 수 없어요.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return '영문·숫자·특수문자를 모두 포함해 주세요.';
    }
    return null;
  }

  static bool isValidPassword(String value) => passwordProblem(value) == null;

  static bool isValidEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  /// 로그인 버튼으로 보여줄 소셜 수단 (+ 이메일 버튼은 항상).
  /// iOS 는 다른 소셜 로그인을 넣으면 Apple 로그인도 함께 요구받아서 iOS 에만 Apple 을 둔다.
  // TODO(결정 1): 로그인 수단 확정
  static const List<SocialProvider> loginProvidersAndroid = [SocialProvider.kakao];
  static const List<SocialProvider> loginProvidersIos = [SocialProvider.kakao, SocialProvider.apple];
}

/// ◐(여유 있으면 MVP) 기능 스위치. 개발이 끝나면 true 로 켠다.
class FeatureFlags {
  FeatureFlags._();

  /// 이메일 로그인 (피그마 "각 로그인별 화면 필요" — 아직 화면 없음)
  static const bool emailLogin = true;

  /// 광고 SDK 연결 전: 버튼을 누르면 광고 없이 바로 1개 더 열어 준다
  static const bool adsConnected = false;

  /// 자소서·이력서 파일 첨부 (서버 파일 분석 연결 전)
  static const bool fileAttach = false;
}
