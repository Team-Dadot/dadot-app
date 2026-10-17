import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/format.dart';
import '../common/pickers.dart';
import 'onboarding_common.dart';

/// 1-5 면접일 입력 (STEP 3/4). 오늘 이전 날짜는 고를 수 없다.
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
        description: '정해진 곳만 넣어 주세요. 비워두면 ‘일정 미정’으로 시작해요.',
        bottom: [AppButton(label: '다음', loading: _saving, onPressed: _next)],
        children: [
          for (final p in preps) ...[
            CompanyTile(
              name: p.companyName,
              subtitle: p.jobName,
              onTap: () => _pick(p),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.interviewDate == null ? '날짜 입력' : formatDot(p.interviewDate!), style: AppTypography.body2Medium),
                  const DropdownMark(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
          ],
          InfoBox.text('면접일이 있는 기업은 D-day가 붙고, 면접 3일 전부터 복습·다듬기 위주로 바뀌어요.'),
        ],
      );
    });
  }
}
