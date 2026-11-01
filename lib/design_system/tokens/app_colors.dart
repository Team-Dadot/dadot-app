import 'package:flutter/painting.dart';

/// 색상 토큰. 피그마 "스위프 7기 > 최종" 페이지(작업 완료된거) 402×874 프레임 값.
/// 화면 코드에서는 Color(0xFF...) 를 직접 쓰지 말고 반드시 AppColors 를 쓴다.
class AppColors {
  AppColors._();

  // ---- 브랜드 ----
  /// 진한 차콜 (버튼 · 선택 칩 · 홈 카드 · 기업 칩)
  static const Color primary = Color(0xFF303237);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// 가장 진한 글자·버튼 (#15171B — 오늘의 학습하기 버튼, 팝업 진행하기)
  static const Color ink = Color(0xFF15171B);
  static const Color primaryDeep = Color(0xFF15171B);

  /// 어두운 카드 몸통 (홈 오늘의 학습 · 공시 근거 카드 · 집중 모드 기업)
  static const Color cardDark = Color(0xFF30323A);

  /// 어두운 카드 안 구분선
  static const Color cardDarkLine = Color(0xFF3C3E46);

  // ---- 포인트 라임 (최종 디자인 브랜드 색) ----
  static const Color point = Color(0xFFC8E324);

  /// 라임 폴더 뒤 탭 · 작성 중 태그 바탕
  static const Color pointSoft = Color(0xFFE4ECAF);

  /// 라임 위 글자 (오늘의 학습 · 기업 변경 · 답변에 활용할 정보)
  static const Color onPoint = Color(0xFF7A8828);

  /// 라임 위 날짜 글자
  static const Color onPointSub = Color(0xFF8A9C1F);

  /// 작성 중 태그 글자
  static const Color pointText = Color(0xFF5E6B0B);

  // ---- 주황 (보완 필요 · 오답) ----
  static const Color accent = Color(0xFFEC6A3F);
  static const Color accentSoft = Color(0xFFFFE8E0);

  // ---- 파랑 (완성 답변 · 정답) ----
  static const Color info = Color(0xFF3D91FF);
  static const Color infoSoft = Color(0xFFE0F4FF);

  // ---- 학습 현황 막대 ----
  static const Color statTrack = Color(0xFF3D434B);
  static const Color statQuiz = Color(0xFFFFB74C);

  // ---- 배경 · 표면 ----
  /// 화면 바탕 (연회색)
  static const Color background = Color(0xFFF3F5F7);

  /// 카드 · 입력창 (흰색)
  static const Color surface = Color(0xFFFFFFFF);

  /// 회색 안내 박스 (해설, 변환된 내용, 말로 답하기 카드)
  static const Color surfaceMuted = Color(0xFFEBEDF0);

  /// 보조 버튼 (해설 보기 · 평가 보기)
  static const Color fillSecondary = Color(0xFFEBEBEB);

  /// 팝업 왼쪽 버튼 · 비활성 큰 버튼 바탕
  static const Color fillMuted = Color(0xFFDCE0E7);

  /// 고른 보기 바탕 (예전 회색 보기, 지금은 테두리로 표시)
  static const Color fillChoice = Color(0xFFD5D5D5);

  /// 바텀 시트 바탕
  static const Color sheet = Color(0xFFF1F1F1);

  /// 홈 카드 뒤 폴더 탭
  static const Color folderBack = Color(0xFFDFEB9A);

  /// 로고 · 이미지 자리 (회색 원)
  static const Color placeholder = Color(0xFFD9D9D9);

  // ---- 글자 ----
  static const Color textPrimary = Color(0xFF25262C);
  static const Color textStrong = Color(0xFF303237);
  static const Color textBody = Color(0xFF4D4D4D);
  static const Color textSub = Color(0xFF55565A);
  static const Color textSecondary = Color(0xFF737373);
  static const Color textHint = Color(0xFF7A7A7A);
  static const Color textTertiary = Color(0xFF8B8B8B);
  static const Color textPlaceholder = Color(0xFF9C9D9F);
  static const Color white = Color(0xFFFFFFFF);

  /// 어두운 카드 위 보조 글자
  static const Color onDarkSub = Color(0x99FFFFFF);

  // ---- 선 ----
  /// 카드 · 입력창 테두리 (필요할 때만)
  static const Color border = Color(0xFFD8D8D8);

  /// 보기 테두리 (퀴즈 보기 · 체크 원)
  static const Color borderLight = Color(0xFFC5C5C5);

  /// 기업 칩 테두리
  static const Color borderChip = Color(0xFFD8D8D8);

  /// 아웃라인 버튼 테두리
  static const Color borderStrong = Color(0xFFBDBDBD);

  /// 구분선 (카드 안 0.5px · 내비 바 아래)
  static const Color divider = Color(0xFFECECEC);

  // ---- 상태 ----
  static const Color danger = Color(0xFFFF6B6B);
  static const Color disabledFill = Color(0xFFDCE0E7);
  static const Color textDisabled = Color(0xFF9C9D9F);
  static const Color progressTrack = Color(0xFFF1F1F1);
  static const Color progressFill = Color(0xFFC8E324);
  static const Color scoreTrack = Color(0xFFE6E6E6);
  static const Color scrim = Color(0x66000000);

  /// 확인 팝업 뒤 (70%)
  static const Color scrimStrong = Color(0xB3000000);
  static const Color homeIndicator = Color(0xFF1A1A1A);

  // ---- 하단 탭 바 ----
  static const Color tabBar = Color(0xFF303137);
  static const Color tabActive = Color(0xFFBCBEC2);
  static const Color tabInactive = Color(0xFF5C5D63);

  // ---- 최종 개발 확인 화면 (763:14784) ----
  /// 빈·오류 화면 아이콘 (회색 ⚠ · 🔍)
  static const Color statusIcon = Color(0xFFC0C3CA);

  /// 섹션 이름 ("면접 피드백" · "기업별 직무 고르기")
  static const Color textCaption = Color(0xFF767A82);

  /// 해설 본문 회색
  static const Color textMuted = Color(0xFF727479);

  /// "더보기" 같은 안내 글자
  static const Color textGuide = Color(0xFF9A9DA4);

  /// 피드백 화면 질문 칸 (연라임)
  static const Color pointPale = Color(0xFFE9F4A8);

  /// 맞힌 문제 아이콘 안쪽
  static const Color pointPaler = Color(0xFFF9FFCF);

  /// 라임 배지 글자 (보완필요)
  static const Color pointDeep = Color(0xFF95AE00);

  /// 평가 막대 바탕
  static const Color barTrack = Color(0xFFEBF0F6);

  /// 피드백 카드 테두리 (1px)
  static const Color cardLine = Color(0xFFE3E5EE);

  /// 맞힌 문제 줄 사이 선
  static const Color rowLine = Color(0xFFEFF1F8);

  /// 삭제하기 버튼 · 입력 오류
  static const Color destructive = Color(0xFFFF5A5A);

  /// 삭제 안내 띠 바탕
  static const Color destructiveSoft = Color(0xFFFFE6E6);

  // ---- 외부 ----
  static const Color kakao = Color(0xFFFEE500);
}
