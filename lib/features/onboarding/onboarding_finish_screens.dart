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
import '../common/format.dart';
import 'onboarding_common.dart';

/// 1-2 첫 설정 · 알림: "면접 준비에 필요할 때만 알려드릴게요." → 알림 허용하기 / 나중에 할게요
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '첫 설정'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const PageTitle('면접 준비에 필요할 때만\n알려드릴게요.', description: '오늘의 학습, 면접 D-day가 가까워질 때\n하루 한 번까지만 보내요.'),
          const SizedBox(height: AppSpacing.xl),
          Text('알림', style: AppTypography.body2Strong),
          const SizedBox(height: AppSpacing.xs),
          InfoBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  color: AppColors.placeholder,
                  alignment: Alignment.center,
                  child: Text('앱', style: AppTypography.micro),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$company 면접이 ${AppPolicy.focusModeDays}일 남았어요', style: AppTypography.body1Strong),
                      const SizedBox(height: 2),
                      Text('오늘은 틀렸던 문제와 답변을 다듬어 볼까요?', style: AppTypography.caption.copyWith(color: AppColors.textBody)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '알림 허용하기', loading: _busy, onPressed: _busy ? null : () => _set(allow: true)),
        AppButton(label: '나중에 할게요', variant: AppButtonVariant.secondary, onPressed: _busy ? null : () => _set(allow: false)),
      ]),
    );
  }
}

/// 1-2 첫 설정 · 완료: "준비가 끝났어요!" + 내 준비 정보 요약 → 오늘의 학습 시작하기
class OnboardingDoneScreen extends ConsumerStatefulWidget {
  const OnboardingDoneScreen({super.key});

  @override
  ConsumerState<OnboardingDoneScreen> createState() => _OnboardingDoneScreenState();
}

class _OnboardingDoneScreenState extends ConsumerState<OnboardingDoneScreen> {
  bool _starting = false;

  Future<void> _start(List<Preparation> preps) async {
    final router = GoRouter.of(context);
    setState(() => _starting = true);
    // 첫 설정이 끝나면 이 화면은 사라지므로(라우터가 홈으로 보냄) ref 는 완료 전에 쓴다
    final first = preps.firstOrNull;
    if (first != null) ref.read(selectedCompanyIdProvider.notifier).select(first.companyId);
    try {
      await ref.read(sessionProvider.notifier).completeOnboarding();
      // 홈 위에 첫 기업의 오늘 퀴즈를 연다 (뒤로 가면 홈)
      router.go(Routes.home);
      if (first != null) router.push(Routes.quiz(first.companyId));
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
    final experiences = ref.watch(experiencesProvider).asData?.value;
    final notification = ref.watch(notificationSettingsProvider).asData?.value;
    final now = DateTime.now();

    final jobs = {for (final p in preps) if (p.hasJob) p.jobName!}.join(' · ');
    final dates = [
      for (final p in preps)
        p.interviewDate == null
            ? '${p.companyName} 미정'
            : '${p.companyName} ${formatShort(p.interviewDate!)} (${formatDday(p.ddayFrom(now) ?? 0)})',
    ].join(' · ');
    final noti = notification == null
        ? '-'
        : notification.enabled
            ? '켜짐 · ${notification.summary.split(' · ').first}'
            : '꺼짐 · 마이에서 켤 수 있어요';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '완료', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const Center(child: LogoBox(size: AppSizes.logo, label: '완료')),
          const SizedBox(height: AppSpacing.gap),
          Text('준비가 끝났어요!', textAlign: TextAlign.center, style: AppTypography.title1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '오늘의 학습으로 첫 퀴즈와\n면접 질문을 시작해 볼까요?',
            textAlign: TextAlign.center,
            style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionTitle('내 준비 정보'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedBox(
            child: Column(
              children: [
                _SummaryRow(label: '준비 기업', value: preps.map((p) => p.companyName).join(' · ')),
                _SummaryRow(label: '지원 직무', value: jobs.isEmpty ? '-' : jobs),
                _SummaryRow(label: '면접일', value: dates.isEmpty ? '-' : dates),
                _SummaryRow(
                  label: '내 경험',
                  value: experiences == null ? '-' : experiences.isEmpty ? '아직 없어요' : '${experiences.length}개 저장',
                ),
                _SummaryRow(label: '학습 알림', value: noti, last: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('모든 정보는 마이에서 언제든 바꿀 수 있어요.', textAlign: TextAlign.center, style: AppTypography.caption),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '오늘의 학습 시작하기  →', loading: _starting, onPressed: _starting ? null : () => _start(preps)),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: AppTypography.caption)),
          Expanded(child: Text(value, style: AppTypography.body2Medium)),
        ],
      ),
    );
  }
}
