import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
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
    final preps = ref.watch(onboardingPrepsProvider).asData?.value ?? const <Preparation>[];
    // 예시 알림은 면접일이 가장 가까운 기업으로
    final dated = preps.where((p) => p.interviewDate != null).toList()
      ..sort((a, b) => a.interviewDate!.compareTo(b.interviewDate!));
    final company = (dated.firstOrNull ?? preps.firstOrNull)?.companyName ?? '기아';
    return OnboardingStepScaffold(
      step: 5,
      title: '오늘의 학습\n놓치지 않게 챙겨드려요',
      bottom: [
        AppButton(label: '알림 허용하기', loading: _busy, onPressed: _busy ? null : () => _set(allow: true)),
        AppButton(label: '일단 넘어갈게요', variant: AppButtonVariant.secondary, onPressed: _busy ? null : () => _set(allow: false)),
      ],
      children: [
        const _CheckLine('하루 한 번, 학습할 시간에만 보내요.'),
        const SizedBox(height: AppSpacing.xs),
        const _CheckLine('알림은 설정에서 언제든 변경할 수 있어요'),
        const SizedBox(height: 56),
        // 피그마는 그래픽 자리("그래픽 고민중") — 알림 미리보기 카드 두 장을 겹쳐 둔다
        ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Opacity(
                  opacity: 0.5,
                  child: _NotificationPreview(title: '오늘의 학습이 기다리고 있어요', body: '퀴즈 5문제와 면접 질문을 풀어 볼까요?'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _NotificationPreview(
                  title: '$company 면접이 ${AppPolicy.focusModeDays}일 남았어요',
                  body: '오늘은 틀렸던 문제와 답변을 다듬어 볼까요?',
                ),
              ),
            ],
          ),
        ),
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
          Expanded(child: Text(text, style: AppTypography.body2Medium.copyWith(color: AppColors.textSub))),
        ],
      );
}

/// 알림 미리보기 카드 (앱 아이콘 + 제목 + 내용)
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      radius: AppRadius.button,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.point, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Image.asset(AppHeader.logoAsset, fit: BoxFit.contain),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body2Strong.copyWith(color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: AppColors.textCaption)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 피그마 최종 1-2 완료 (763:17615): 그래픽 + 오늘의 학습 시작하기 / 홈화면 둘러보기
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 피그마는 그래픽 자리("그래픽 고민중") — 결과 화면 폴더 그림을 쓴다
                Image.asset('assets/images/folder_result.png', width: 140, excludeFromSemantics: true),
                const SizedBox(height: AppSpacing.lg),
                Semantics(header: true, child: Text('준비가 끝났어요!', textAlign: TextAlign.center, style: AppTypography.title1.copyWith(color: AppColors.ink))),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '오늘의 학습으로 첫 퀴즈와\n면접 질문을 시작해 볼까요?',
                  textAlign: TextAlign.center,
                  style: AppTypography.body1.copyWith(color: AppColors.textCaption),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomCta(children: [
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
