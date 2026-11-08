import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe/app.dart';
import 'package:swipe/core/config/app_config.dart';
import 'package:swipe/core/providers.dart';
import 'package:swipe/core/storage/token_storage.dart';

/// 앱이 Mock 모드로 뜨고 로그인 → 첫 설정 5단계 → 완료 → 첫 퀴즈 → 홈까지 가는지 확인하는 스모크 테스트
void main() {
  testWidgets('로그인 → 첫 설정 → 홈', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          appConfigProvider.overrideWithValue(const AppConfig(
            useMock: true,
            apiBaseUrl: 'http://localhost',
            privacyPolicyUrl: 'https://example.com/privacy',
            termsUrl: 'https://example.com/terms',
            inquiryFormUrl: 'https://example.com/form',
            mockLatency: Duration.zero,
            kakaoNativeAppKey: '',
          )),
        ],
        child: const SwipeApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 처음 실행: 스플래시(최소 1.5초) → 튜토리얼 3장 → 로그인
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('복잡한 기업 분석을 한 번에'), findsWidgets);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    // 1-1: 테스트 환경(Android 로 취급)에서는 카카오 + 이메일
    expect(find.text('공시 기반 퀴즈로 익히고\n내 경험을 담아 답해보세요'), findsOneWidget);
    expect(find.text('이메일로 시작하기'), findsOneWidget);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump(const Duration(milliseconds: 300)); // FakeSocialAuthService 지연
    await tester.pumpAndSettle();

    // STEP 1 준비 기업: 검색창 → 기업 추가하기 화면에서 추가 → 돌아오기
    expect(find.text('어떤 기업을\n준비하고 있나요?'), findsOneWidget);
    await tester.tap(find.text('기업 이름을 검색해보세요'));
    await tester.pumpAndSettle();
    expect(find.text('기업 추가하기'), findsOneWidget);
    await tester.tap(find.text('기아').first);
    await tester.pumpAndSettle();
    expect(find.text('추가한 기업'), findsOneWidget);
    await tester.tap(find.text('추가 완료'));
    await tester.pumpAndSettle();
    expect(find.text('내가 추가한 기업'), findsOneWidget);
    expect(find.text('준비 중인 기업이 1개 추가되었어요'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // STEP 2 직무 → 직무 추가하기 화면 (피그마 1212:7788)
    expect(find.text('기업별 지원 직무를\n알려주세요'), findsOneWidget);
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    expect(find.text('직무 추가하기'), findsOneWidget);
    await tester.tap(find.text('마케팅').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('‘마케팅’ 직무로 지원해요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // STEP 3 면접일 (건너뜀)
    expect(find.text('면접 일정이 잡힌\n기업이 있나요?'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // STEP 4 경험 → 나중에 추가하기
    expect(find.text('면접에서 꺼낼\n경험을 알려주세요'), findsOneWidget);
    await tester.tap(find.text('나중에 추가하기'));
    await tester.pumpAndSettle();

    // STEP 5 알림 → 일단 넘어갈게요
    expect(find.text('오늘의 학습\n놓치지 않게 챙겨드려요'), findsOneWidget);
    await tester.tap(find.text('일단 넘어갈게요'));
    await tester.pumpAndSettle();

    // 완료 → 오늘의 학습 시작하기 → 첫 퀴즈
    expect(find.text('준비가 끝났어요!'), findsOneWidget);
    await tester.tap(find.text('오늘의 학습 시작하기'));
    await tester.pumpAndSettle();
    // 3-1 퀴즈 (피그마 최종: 제목 없는 내비 + "Q1." + 문제)
    expect(find.textContaining('Q1.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-back')));
    await tester.pumpAndSettle();

    // 홈 (라임 폴더 카드: 오늘의 학습 · 기업 퀴즈 0/5 · 면접 연습 0/3 + 학습 현황)
    expect(find.text('오늘의 학습'), findsOneWidget);
    expect(find.text('기업 퀴즈'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('학습 현황'), findsOneWidget);
    expect(find.text('오늘의 학습하기'), findsOneWidget);

    // 기업 변경 → "기업 선택하기" 시트
    await tester.tap(find.text('기업 변경'));
    await tester.pumpAndSettle();
    expect(find.text('기업 선택하기'), findsOneWidget);
  });
}
