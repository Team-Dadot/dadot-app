import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/experience_sheet.dart';
import 'onboarding_common.dart';

/// 피그마 최종 STEP 4 "면접에서 꺼낼 경험을 알려주세요" (763:17585 · 942:4635 · 942:4700 · 942:4460):
/// "+ 내 경험 추가하기" 카드 → 시트에서 제목·내용 → "추가한 내 경험" 접는 목록 → 다음으로 / 일단 넘어갈게요
class OnboardingExperienceScreen extends ConsumerStatefulWidget {
  const OnboardingExperienceScreen({super.key});

  @override
  ConsumerState<OnboardingExperienceScreen> createState() => _OnboardingExperienceScreenState();
}

class _OnboardingExperienceScreenState extends ConsumerState<OnboardingExperienceScreen> {
  bool _saving = false;

  Future<void> _add(int count) async {
    if (count >= AppPolicy.maxExperiences) {
      showToast(context, '경험은 최대 ${AppPolicy.maxExperiences}개까지 저장할 수 있어요.');
      return;
    }
    final draft = await showExperienceSheet(context);
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).addExperiences([draft]);
      ref.invalidate(experiencesProvider);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(experiencesProvider);
    final items = list.asData?.value ?? const [];
    return OnboardingStepScaffold(
      step: 4,
      title: '면접에서 꺼낼\n경험을 알려주세요',
      bottom: [
        AppButton(
          label: '다음으로',
          loading: _saving,
          onPressed: items.isEmpty || _saving ? null : () => context.push(Routes.onboardingNotification),
        ),
        AppButton(
          label: '일단 넘어갈게요',
          variant: AppButtonVariant.secondary,
          onPressed: _saving ? null : () => context.push(Routes.onboardingNotification),
        ),
      ],
      children: [
        AddExperienceCard(onTap: _saving ? null : () => _add(items.length)),
        if (list.hasError) ErrorView(error: list.error!, compact: true, onRetry: () => ref.invalidate(experiencesProvider)),
        if (items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const OnboardingLabel('추가한 내 경험'),
          for (final e in items) ...[
            ExperienceAccordion(key: ValueKey(e.id), experience: e),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}
