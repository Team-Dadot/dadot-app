import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/catalog.dart';
import '../../data/models/settings.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'onboarding_common.dart';

/// 피그마 최종 STEP 5 알림 (763:17600): "오늘의 학습 놓치지 않게 챙겨드려요" → 알림 허용하기 / 일단 넘어갈게요
class OnboardingNotificationScreen extends ConsumerStatefulWidget {
  const OnboardingNotificationScreen({super.key});

  @override
  ConsumerState<OnboardingNotificationScreen> createState() => _OnboardingNotificationScreenState();
}

class _OnboardingNotificationScreenState extends ConsumerState<OnboardingNotificationScreen> {
  bool _busy = false;

  Future<void> _set({required bool allow}) async {
    setState(() => _busy = true);
    try {
      var enabled = false;
      if (allow) {
        enabled = await ref.read(pushServiceProvider).requestPermission();
        if (enabled) await ref.read(sessionProvider.notifier).registerPushToken();
        if (!enabled && mounted) showToast(context, '알림 권한이 꺼져 있어요. 나중에 마이 > 학습 알림에서 켤 수 있어요.');
      }
      await ref
          .read(profileRepositoryProvider)
          .updateNotificationSettings(NotificationSettings(enabled: enabled, hour: 9, minute: 0));
      ref.invalidate(notificationSettingsProvider);
      if (mounted) await context.push(Routes.onboardingDone);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 5,
      title: '오늘의 학습, 잊지 않게\n알림으로 챙겨드려요',
      bottom: [
        AppButton(label: '알림 허용하기', loading: _busy, onPressed: _busy ? null : () => _set(allow: true)),
        AppButton(label: '일단 넘어갈게요', variant: AppButtonVariant.secondary, onPressed: _busy ? null : () => _set(allow: false)),
      ],
      children: [
        const _CheckLine('하루 한 번, 학습할 시간에만 보내요.'),
        const SizedBox(height: AppSpacing.xs),
        const _CheckLine('알림은 설정에서 언제든 변경할 수 있어요'),
        const SizedBox(height: AppSpacing.sm),
        // 피그마 1468:9529: 휴대폰 속 라임 종 그림
        Image.asset('assets/images/onboarding_alarm.png', width: double.infinity, fit: BoxFit.fitWidth, excludeFromSemantics: true),
      ],
    );
  }
}

/// 라임 ✓ + 안내 한 줄
class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const CheckMark(checked: true, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: AppTypography.rowTitle.copyWith(color: AppColors.textStrong))),
        ],
      );
}

/// 피그마 1468:9563 준비 완료: 그래픽 + 오늘의 학습 시작하기 / 홈화면 둘러보기
class OnboardingDoneScreen extends ConsumerStatefulWidget {
  const OnboardingDoneScreen({super.key});

  @override
  ConsumerState<OnboardingDoneScreen> createState() => _OnboardingDoneScreenState();
}

class _OnboardingDoneScreenState extends ConsumerState<OnboardingDoneScreen> {
  bool _starting = false;

  /// [startQuiz] 면 홈 위에 첫 기업의 오늘 퀴즈를 연다 (뒤로 가면 홈)
  Future<void> _finish(List<Preparation> preps, {required bool startQuiz}) async {
    final router = GoRouter.of(context);
    setState(() => _starting = true);
    // 첫 설정이 끝나면 이 화면은 사라지므로(라우터가 홈으로 보냄) ref 는 완료 전에 쓴다
    final first = preps.firstOrNull;
    if (first != null) ref.read(selectedCompanyIdProvider.notifier).select(first.companyId);
    try {
      await ref.read(sessionProvider.notifier).completeOnboarding();
      router.go(Routes.home);
      if (startQuiz && first != null) router.push(Routes.quiz(first.companyId));
    } catch (e) {
      if (mounted) {
        showErrorToast(context, e);
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preps = ref.watch(onboardingPrepsProvider).asData?.value ?? const <Preparation>[];
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.background,
      // 피그마 1468:9563. QA: 글자·번개·폴더를 한 장 그림으로 넣어 화면 비율이 다른 폰에서 번개가 중간에 잘려 보였다
      // → 번개 무늬는 화면 전체를 덮는 배경(버튼 뒤까지), 글자는 진짜 글자, 폴더(O/X) 그림은 따로 가운데에 둔다
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/onboarding_done_bg.png', fit: BoxFit.cover, excludeFromSemantics: true),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              // 상태 바 아래 106 에 제목 (피그마 y 167), 81 아래 그림 (266×163)
              padding: EdgeInsets.fromLTRB(AppSpacing.screenH, top + 106, AppSpacing.screenH, 200),
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      '준비가 모두 끝났어요',
                      textAlign: TextAlign.center,
                      style: AppTypography.display.copyWith(color: const Color(0xFF303137), height: 1.6, letterSpacing: -0.72),
                    ),
                  ),
                  Text(
                    '퀴즈 5문제로 가볍게 시작해볼까요?',
                    textAlign: TextAlign.center,
                    style: AppTypography.rowTitle.copyWith(fontSize: 18, color: const Color(0xFF303137), height: 1.8, letterSpacing: -0.72),
                  ),
                  const SizedBox(height: 79),
                  Image.asset('assets/images/onboarding_done_graphic.png', width: 266, height: 163, excludeFromSemantics: true),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomCta(color: Colors.transparent, children: [
        AppButton(label: '오늘의 학습 시작하기', loading: _starting, onPressed: _starting ? null : () => _finish(preps, startQuiz: true)),
        AppButton(
          label: '홈화면 둘러보기',
          variant: AppButtonVariant.secondary,
          onPressed: _starting ? null : () => _finish(preps, startQuiz: false),
        ),
      ]),
    );
  }
}
