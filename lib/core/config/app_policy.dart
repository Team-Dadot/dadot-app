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

  /// 면접 3일 전부터 집중 모드 (2-2)
  static const int focusModeDays = 3;

  /// 내 경험
  static const int maxExperiences = 100;
  static const int experienceMaxLength = 5000;
  static const int experienceTitleMaxLength = 40;

  /// 답변 (4-3)
  // TODO(결정 8): 최소 답변 글자수
  static const int minAnswerLength = 30;
  static const int maxAnswerLength = 3000;

  /// 말로 답하기 (4-4 "3:00 권장"). 3분이 지나면 자동으로 멈춘다.
  static const Duration voiceMaxDuration = Duration(minutes: 3);

  /// 문의 내용 길이
  static const int maxInquiryLength = 1000;

  /// 비밀번호 (6-12 "영문·숫자 포함 8자 이상")
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 20;

  /// 피그마 이메일 가입: 영문·숫자·특수문자 조합 8-20자
  static bool isValidPassword(String v) =>
      v.length >= minPasswordLength &&
      v.length <= maxPasswordLength &&
      RegExp('[A-Za-z]').hasMatch(v) &&
      RegExp(r'\d').hasMatch(v) &&
      RegExp(r'[^A-Za-z0-9\s]').hasMatch(v);

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
  static const bool emailLogin = false;

  /// 광고 SDK 연결 전: 버튼을 누르면 광고 없이 바로 1개 더 열어 준다
  static const bool adsConnected = false;

  /// 자소서·이력서 파일 첨부 (서버 파일 분석 연결 전)
  static const bool fileAttach = false;
}
