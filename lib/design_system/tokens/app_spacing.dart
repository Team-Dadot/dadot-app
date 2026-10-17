import 'package:flutter/widgets.dart';

/// 간격 · 모서리 · 크기 토큰. 피그마 와이어프레임 값.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// 화면 좌우 여백
  static const double screenH = 20;
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: screenH);

  /// 본문 영역 (피그마 Content 프레임: 좌우 20, 위 12~16)
  static const EdgeInsets content = EdgeInsets.fromLTRB(screenH, sm, screenH, md);

  /// 본문 요소 사이 기본 간격
  static const double gap = 14;

  /// 하단 버튼 사이 간격
  static const double ctaGap = 6;

  /// 카드 안쪽 여백
  static const double card = 14;

  /// 시작 화면 로고·문구 사이 간격
  static const double introGap = 14;
}

class AppRadius {
  AppRadius._();

  /// 와이어프레임은 모서리가 각져 있다
  static const double none = 0;
  static const double sm = 0;
  static const double md = 0;
  static const double lg = 0;
  static const double pill = 999;
}

class AppSizes {
  AppSizes._();

  /// 터치 영역 최소 크기
  static const double minTouch = 44;

  /// 피그마 Button 컴포넌트 높이
  static const double buttonHeight = 52;
  static const double buttonHeightSmall = 40;
  static const double ctaHeight = 52;
  static const double inputHeight = 48;
  static const double navBarHeight = 44;
  static const double headerHeight = 52;
  static const double tabBarHeight = 75;
  static const double tabIcon = 24;

  /// 로고 자리
  static const double logo = 72;
  static const double logoTile = 40;
  static const double logoHeader = 26;
  static const double profile = 48;
  static const double indexBox = 28;
  static const double progressHeight = 4;
  static const double scoreBarHeight = 8;
}
