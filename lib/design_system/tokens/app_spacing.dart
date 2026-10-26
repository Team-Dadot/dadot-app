import 'package:flutter/widgets.dart';

/// 간격 · 모서리 · 크기 토큰. 피그마 작업 프레임(402×874) 값.
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
  static const double ctaGap = 8;

  /// 카드 안쪽 여백
  static const double card = 20;

  /// 시작 화면 로고·문구 사이 간격
  static const double introGap = 14;
}

class AppRadius {
  AppRadius._();

  static const double none = 0;

  /// 작은 버튼 (해설 보기 · 다시 풀기), 체크 박스
  static const double sm = 10;

  /// 입력창 · 안내 박스
  static const double md = 16;

  /// 카드 · 바텀 시트 위
  static const double lg = 20;

  /// 큰 버튼 · 보기 · 팝업 (최종 디자인 16)
  static const double button = 16;

  /// 팝업 버튼
  static const double dialogButton = 12;

  /// 홈 폴더 카드 · 바텀 시트 위
  static const double xl = 24;

  /// 하단 탭 바 위
  static const double tabBar = 24;
  static const double pill = 999;
}

class AppSizes {
  AppSizes._();

  /// 터치 영역 최소 크기
  static const double minTouch = 44;

  /// 하단 큰 버튼 (피그마 56, 모서리 20)
  static const double buttonHeight = 56;

  /// 카드 안 작은 버튼 (피그마 42, 모서리 10)
  static const double buttonHeightSmall = 42;

  /// 팝업 버튼 (피그마 48)
  static const double buttonHeightDialog = 48;
  static const double ctaHeight = 56;
  static const double inputHeight = 52;
  static const double navBarHeight = 56;
  static const double headerHeight = 52;
  static const double tabBarHeight = 84;
  static const double tabIcon = 24;

  /// 보기 한 줄 높이
  static const double choiceHeight = 64;

  /// 로고 자리
  static const double logo = 72;
  static const double logoTile = 44;
  static const double logoHeader = 26;
  static const double profile = 48;
  static const double indexBox = 28;
  static const double progressHeight = 8;
  static const double scoreBarHeight = 8;

  /// 로딩 · 빈 화면 회색 원
  static const double illustration = 72;

  /// 말로 답하기 마이크 버튼
  static const double micButton = 168;
}
