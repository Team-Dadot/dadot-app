import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/format.dart';
import '../common/pickers.dart';
import 'onboarding_common.dart';

/// 피그마 최종 STEP 3 면접 일정 (942:4378 · 942:3771 달력 시트). 오늘 이전 날짜는 고를 수 없다.
class OnboardingDatesScreen extends ConsumerStatefulWidget {
  const OnboardingDatesScreen({super.key});

  @override
  ConsumerState<OnboardingDatesScreen> createState() => _OnboardingDatesScreenState();
}

class _OnboardingDatesScreenState extends ConsumerState<OnboardingDatesScreen> {
  bool _saving = false;

  Future<void> _pick(Preparation p) async {
    final date = await pickInterviewDate(context, initial: p.interviewDate);
    if (date == null || !mounted) return;
    ref.read(onboardingPrepsProvider.notifier).replace(p.copyWith(interviewDate: date));
  }

  Future<void> _next() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingPrepsProvider.notifier).save();
      if (mounted) await context.push(Routes.onboardingExperience);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLoadGate(builder: (preps) {
      return OnboardingStepScaffold(
        step: 3,
        title: '면접 일정이 잡힌\n기업이 있나요?',
        description: '정해진 곳이 있다면 넣어주세요.',
        bottom: [AppButton(label: '다음', loading: _saving, onPressed: _next)],
        children: [
          for (final p in preps) ...[
            CompanyTile(
              name: p.companyName,
              subtitle: p.jobName,
              onTap: () => _pick(p),
              trailing: TileValue(
                p.interviewDate == null ? '날짜 선택' : formatDot(p.interviewDate!),
                filled: p.interviewDate != null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    });
  }
}
