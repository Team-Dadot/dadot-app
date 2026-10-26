import 'dart:ui' show FontVariation;

import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// 글자 스타일 토큰. 피그마 작업 프레임(Pretendard, 줄 높이 140~145%, 자간 -3%) 기준.
/// 이름 = 크기·굵기 용도, 색은 기본값이고 화면에서 copyWith(color:) 로 바꾼다.
/// 숫자·영문 표시용 Mabry Pro 는 상용 폰트라 Pretendard 로 대신한다.
class AppTypography {
  AppTypography._();

  /// pubspec.yaml 의 fonts family 이름
  static const String fontFamily = 'Pretendard';

  /// 숫자 · D-day · Q1 표시용 (피그마 Zalando Sans SemiExpanded, 가변 폰트)
  static const String numberFamily = 'ZalandoSansSemiExpanded';

  /// 숫자 글꼴 스타일 (가변 폰트라 굵기는 wght 축으로 준다)
  static TextStyle number(double size, {FontWeight weight = FontWeight.w600, Color color = AppColors.ink, double height = 1.4}) =>
      TextStyle(
        fontFamily: numberFamily,
        fontSize: size,
        height: height,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        letterSpacing: size * -0.05,
        color: color,
      );

  static const double _h = 1.45;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;

  static TextStyle _s(double size, FontWeight weight, [Color color = AppColors.textPrimary, double height = _h]) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: height,
        fontWeight: weight,
        color: color,
        letterSpacing: size * -0.03,
      );

  /// 25 Bold — 탭 화면 상단 워드마크 (Dadot / Review)
  static final TextStyle brand = _s(25, bold, AppColors.textStrong, 1.2);

  /// 28 Bold — 시작 화면 문구
  static final TextStyle display = _s(28, bold);

  /// 28 Medium — 홈 학습 현황 숫자 (78%)
  static final TextStyle statNumber = _s(28, medium, const Color(0xFF111111), 1.3);

  /// 32 Bold — 피드백 점수
  static final TextStyle score = _s(32, bold);

  /// 24 Bold — 단계 화면 제목, 마이 화면 제목
  static final TextStyle title1 = _s(24, bold);

  /// 24 Medium — 홈 카드 D-day
  static final TextStyle dday = _s(24, medium, AppColors.white, 1.4);

  /// 22 Bold — 탭 화면 제목
  static final TextStyle title2 = _s(22, bold);

  /// 26 Bold — 퀴즈 문제
  static final TextStyle title3 = _s(26, bold, AppColors.textStrong).copyWith(letterSpacing: -0.52);

  /// 20 SemiBold — 면접 질문, 팝업 제목, 복습 카드 질문
  static final TextStyle title4 = _s(20, semibold);

  /// 18 Medium — 내비 바 제목
  static final TextStyle navTitle = _s(18, medium, AppColors.textPrimary, 1.3);

  /// 17 SemiBold — 섹션 제목
  static final TextStyle heading = _s(17, semibold);

  /// 16 SemiBold — 소제목, 보기, 카드 제목
  static final TextStyle subheading = _s(16, semibold);

  /// 16 SemiBold — 카드 제목
  static final TextStyle cardTitle = _s(16, semibold);

  /// 16 Medium — 목록 행 제목 (기업 퀴즈 0/5, 메뉴)
  static final TextStyle rowTitle = _s(16, medium, AppColors.textPrimary, 1.4);

  /// 15 Regular — 본문, 입력
  static final TextStyle body1 = _s(15, regular);
  static final TextStyle body1Medium = _s(15, medium);
  static final TextStyle body1Strong = _s(15, semibold);

  /// 14 Regular — 보조 본문
  static final TextStyle body2 = _s(14, regular, AppColors.textBody);
  static final TextStyle body2Medium = _s(14, medium);
  static final TextStyle body2Strong = _s(14, semibold);

  /// 12 Regular — 설명 · 메타
  static final TextStyle caption = _s(12, medium, AppColors.textHint, 1.4);
  static final TextStyle captionMedium = _s(12, medium, AppColors.textSub, 1.4);
  static final TextStyle captionStrong = _s(12, semibold, AppColors.textPrimary, 1.4);

  /// 11 — 태그 · 아주 작은 설명
  static final TextStyle micro = _s(11, regular, AppColors.textSecondary, 1.4);
  static final TextStyle microStrong = _s(11, semibold, AppColors.textBody, 1.4);

  /// 18 SemiBold — 하단 큰 버튼 (다음 · 답변하기 · 제출하기)
  static final TextStyle button = _s(18, semibold, AppColors.white, 1.4).copyWith(letterSpacing: -0.36);

  /// 14 SemiBold — 작은 버튼 · 팝업 버튼
  static final TextStyle buttonSmall = _s(14, semibold, AppColors.textStrong, 1.4);

  /// 12 Medium — 하단 탭
  static final TextStyle tab = TextStyle(fontFamily: fontFamily, fontSize: 12, height: 1.2, fontWeight: medium);
}
