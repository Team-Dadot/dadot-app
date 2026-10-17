import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe/app.dart';
import 'package:swipe/core/config/app_config.dart';
import 'package:swipe/core/providers.dart';
import 'package:swipe/core/storage/token_storage.dart';

/// 앱이 Mock 모드로 뜨고 로그인 → 첫 설정 4단계 → 알림 → 완료 → 첫 퀴즈 → 홈까지 가는지 확인하는 스모크 테스트
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
          )),
        ],
        child: const SwipeApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1-1: 테스트 환경(Android 로 취급)에서는 카카오 + 이메일
    expect(find.text('기업의 이야기,\n나의 답변으로.'), findsOneWidget);
    expect(find.text('이메일로 시작하기'), findsOneWidget);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump(const Duration(milliseconds: 300)); // FakeSocialAuthService 지연
    await tester.pumpAndSettle();

    // 1-2 준비 기업
    expect(find.text('어떤 기업을\n준비하고 있나요?'), findsOneWidget);
    await tester.tap(find.text('기아'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 1-3 직무 → 1-4 시트
    expect(find.text('기업별 지원 직무를\n알려주세요.'), findsOneWidget);
    await tester.tap(find.text('선택 ›'));
    await tester.pumpAndSettle();
    expect(find.text('기아 지원 직무'), findsOneWidget);
    await tester.tap(find.text('마케팅').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 1-5 면접일 (건너뜀)
    expect(find.text('면접 일정이 잡힌\n기업이 있나요?'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // STEP 4 경험 → 건너뛰기
    expect(find.text('면접에서 꺼낼\n내 경험을 알려주세요.'), findsOneWidget);
    await tester.tap(find.text('건너뛰고 시작하기'));
    await tester.pumpAndSettle();

    // 알림 → 나중에
    expect(find.text('면접 준비에 필요할 때만\n알려드릴게요.'), findsOneWidget);
    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();

    // 완료 → 오늘의 학습 시작하기 → 첫 퀴즈
    expect(find.text('준비가 끝났어요!'), findsOneWidget);
    await tester.tap(find.text('오늘의 학습 시작하기  →'));
    await tester.pumpAndSettle();
    expect(find.text('기업 퀴즈'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.tap(find.text('〈'));
    await tester.pumpAndSettle();

    // 2-1 홈
    expect(find.text('지민님,'), findsOneWidget);
    expect(find.text('오늘도 한 걸음 준비해요.'), findsOneWidget);
    expect(find.text('오늘의 학습'), findsOneWidget);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text('0 / 3'), findsOneWidget);
  });
}
