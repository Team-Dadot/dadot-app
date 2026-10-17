import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/pickers.dart';
import 'onboarding_common.dart';

/// 1-3 기업별 직무 (STEP 2/4) + 1-4 직무 선택 시트
class OnboardingJobsScreen extends ConsumerStatefulWidget {
  const OnboardingJobsScreen({super.key});

  @override
  ConsumerState<OnboardingJobsScreen> createState() => _OnboardingJobsScreenState();
}

class _OnboardingJobsScreenState extends ConsumerState<OnboardingJobsScreen> {
  bool _saving = false;

  Future<void> _change(Preparation p) async {
    final job = await showJobPicker(context, companyName: p.companyName, selectedName: p.jobName);
    if (job == null || !mounted) return;
    final ctrl = ref.read(onboardingPrepsProvider.notifier);
    final firstPick = ctrl.current.every((x) => !x.hasJob);
    // "같은 직무면 한 번에": 처음 고른 직무는 아직 직무가 없는 기업 모두에 넣는다
    ctrl.setLocal([
      for (final x in ctrl.current)
        x.companyId == p.companyId || (firstPick && !x.hasJob) ? x.copyWith(jobId: job.id, jobName: job.name) : x,
    ]);
  }

  Future<void> _next() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingPrepsProvider.notifier).save();
      if (mounted) await context.push(Routes.onboardingDates);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLoadGate(builder: (preps) {
      final ready = preps.isNotEmpty && preps.every((p) => p.hasJob);
      return OnboardingStepScaffold(
        step: 2,
        title: '기업별 지원 직무를\n알려주세요.',
        description: '같은 직무면 한 번에, 다르면 기업별로 바꿔요.',
        bottom: [AppButton(label: '다음', loading: _saving, onPressed: ready ? _next : null)],
        children: [
          for (final p in preps) ...[
            CompanyTile(
              name: p.companyName,
              subtitle: p.hasJob ? p.jobName : '직무를 골라 주세요',
              onTap: () => _change(p),
              trailing: Text(p.hasJob ? '변경 ›' : '선택 ›', style: AppTypography.body2Medium),
            ),
            const SizedBox(height: AppSpacing.gap),
          ],
        ],
      );
    });
  }
}
