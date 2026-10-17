import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// 글자 스타일 토큰. 피그마 와이어프레임(Noto Sans KR, 줄 높이 145%) 기준.
/// 이름 = 크기·굵기 용도, 색은 기본값이고 화면에서 copyWith(color:) 로 바꾼다.
class AppTypography {
  AppTypography._();

  /// pubspec.yaml 의 fonts family 이름
  static const String fontFamily = 'NotoSansKR';

  static const double _h = 1.45;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight bold = FontWeight.w700;

  static TextStyle _s(double size, FontWeight weight, [Color color = AppColors.textPrimary]) =>
      TextStyle(fontFamily: fontFamily, fontSize: size, height: _h, fontWeight: weight, color: color);

  /// 28 Bold — 시작 화면 문구
  static final TextStyle display = _s(28, bold);

  /// 32 Bold — 피드백 점수
  static final TextStyle score = _s(32, bold);

  /// 24 Bold — 단계 화면 제목, 큰 숫자
  static final TextStyle title1 = _s(24, bold);

  /// 22 Bold — 탭 화면 제목, D-day
  static final TextStyle title2 = _s(22, bold);

  /// 20 Bold — 퀴즈 문제
  static final TextStyle title3 = _s(20, bold);

  /// 18 Bold — 면접 질문, 시트 제목
  static final TextStyle title4 = _s(18, bold);

  /// 17 Bold — 내비 바 제목, 섹션 제목
  static final TextStyle heading = _s(17, bold);

  /// 16 Bold — 소제목
  static final TextStyle subheading = _s(16, bold);

  /// 15 Bold — 카드 제목
  static final TextStyle cardTitle = _s(15, bold);

  /// 15 Medium — 목록 행 제목
  static final TextStyle rowTitle = _s(15, medium);

  /// 14 Regular — 본문, 입력
  static final TextStyle body1 = _s(14, regular);
  static final TextStyle body1Medium = _s(14, medium);
  static final TextStyle body1Strong = _s(14, bold);

  /// 13 Regular — 보조 본문
  static final TextStyle body2 = _s(13, regular, AppColors.textBody);
  static final TextStyle body2Medium = _s(13, medium);
  static final TextStyle body2Strong = _s(13, bold);

  /// 12 Regular — 설명 · 메타
  static final TextStyle caption = _s(12, regular, AppColors.textSecondary);
  static final TextStyle captionMedium = _s(12, medium, AppColors.textSub);
  static final TextStyle captionStrong = _s(12, bold);

  /// 11 — 태그 · 아주 작은 설명
  static final TextStyle micro = _s(11, regular, AppColors.textSecondary);
  static final TextStyle microStrong = _s(11, bold, AppColors.textBody);

  /// 16 Bold — 버튼
  static final TextStyle button = TextStyle(fontFamily: fontFamily, fontSize: 16, height: 1.2, fontWeight: bold);

  /// 11 — 하단 탭
  static final TextStyle tab = TextStyle(fontFamily: fontFamily, fontSize: 11, height: 1.2, fontWeight: regular);
}
