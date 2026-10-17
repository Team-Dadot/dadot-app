import 'package:flutter/painting.dart';

/// 색상 토큰. 피그마 "스위프 7기 > 와이어프레임" 페이지의 그레이 스케일 값.
/// 화면 코드에서는 Color(0xFF...) 를 직접 쓰지 말고 반드시 AppColors 를 쓴다.
/// 브랜드 컬러가 나오면 이 파일의 값만 바꾸면 앱 전체 색이 바뀐다.
class AppColors {
  AppColors._();

  // ---- 브랜드 (와이어프레임은 검정) ----
  static const Color primary = Color(0xFF212121);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ---- 배경 · 표면 ----
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  /// 회색 안내 박스 (해설, 알림 예시, 변환된 내용)
  static const Color surfaceMuted = Color(0xFFF0F0F0);

  /// 보조 버튼 · 태그 · 번호 박스
  static const Color fillSecondary = Color(0xFFE6E6E6);

  /// 보기 알파벳 박스
  static const Color fillChoice = Color(0xFFEBEBEB);

  /// 로고 · 이미지 자리
  static const Color placeholder = Color(0xFFE0E0E0);

  // ---- 글자 ----
  static const Color textPrimary = Color(0xFF212121);
  static const Color textStrong = Color(0xFF404040);
  static const Color textBody = Color(0xFF4D4D4D);
  static const Color textSub = Color(0xFF595959);
  static const Color textSecondary = Color(0xFF737373);
  static const Color textHint = Color(0xFF808080);
  static const Color textTertiary = Color(0xFF8C8C8C);
  static const Color textPlaceholder = Color(0xFF999999);
  static const Color white = Color(0xFFFFFFFF);

  // ---- 선 ----
  /// 카드 · 입력창 테두리
  static const Color border = Color(0xFFBFBFBF);

  /// 보기 · 피드백 카드 테두리
  static const Color borderLight = Color(0xFFCCCCCC);

  /// 기업 칩 테두리
  static const Color borderChip = Color(0xFFB3B3B3);

  /// 아웃라인 버튼 테두리
  static const Color borderStrong = Color(0xFF999999);

  /// 구분선 · 선택 안 된 타일 테두리 · 진행 막대 바탕
  static const Color divider = Color(0xFFD9D9D9);

  // ---- 상태 (와이어프레임은 별도 색 없음) ----
  static const Color danger = Color(0xFF212121);
  static const Color disabledFill = Color(0xFFD9D9D9);
  static const Color textDisabled = Color(0xFF999999);
  static const Color progressTrack = Color(0xFFD9D9D9);
  static const Color scoreTrack = Color(0xFFE6E6E6);
  static const Color scrim = Color(0x80000000);
  static const Color homeIndicator = Color(0xFF1A1A1A);
}
