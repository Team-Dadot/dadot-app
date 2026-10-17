import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/pickers.dart';
import 'onboarding_common.dart';

/// 1-2 준비 기업 선택 (STEP 1/4)
class OnboardingCompaniesScreen extends ConsumerStatefulWidget {
  const OnboardingCompaniesScreen({super.key});

  @override
  ConsumerState<OnboardingCompaniesScreen> createState() => _OnboardingCompaniesScreenState();
}

class _OnboardingCompaniesScreenState extends ConsumerState<OnboardingCompaniesScreen> {
  bool _saving = false;

  void _toggle(Company c) {
    final ctrl = ref.read(onboardingPrepsProvider.notifier);
    final list = List.of(ctrl.current);
    final i = list.indexWhere((p) => p.companyId == c.id);
    if (i >= 0) {
      list.removeAt(i);
    } else {
      if (list.length >= AppPolicy.maxCompanies) {
        showToast(context, '준비 기업은 최대 ${AppPolicy.maxCompanies}개까지 고를 수 있어요.');
        return;
      }
      list.add(Preparation.fromCompany(c));
    }
    ctrl.setLocal(list);
  }

  Future<void> _next() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingPrepsProvider.notifier).save();
      if (mounted) await context.push(Routes.onboardingJobs);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    // 첫 단계에서 뒤로 = 로그아웃하고 시작 화면으로
    final ok = await showConfirmDialog(context, title: '첫 설정을 그만둘까요?', message: '시작 화면으로 돌아가요. 고른 기업은 저장돼 있어요.', confirmLabel: '그만두기');
    if (ok && mounted) await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLoadGate(builder: (preps) {
      final selected = {for (final p in preps) p.companyId};
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: OnboardingStepScaffold(
          step: 1,
          title: '어떤 기업을\n준비하고 있나요?',
          description: '여러 기업을 한 번에 골라 주세요.',
          onBack: _back,
          bottom: [
            AppButton(label: '다음', loading: _saving, onPressed: preps.isEmpty ? null : _next),
          ],
          children: [
            CompanySearch(
              header: _CountRow(count: preps.length),
              itemBuilder: (c) => CompanyTile(
                name: c.name,
                subtitle: c.industry,
                selected: selected.contains(c.id),
                trailing: CheckMark(checked: selected.contains(c.id)),
                onTap: () => _toggle(c),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// "최대 5개까지  2 / 5"
class _CountRow extends StatelessWidget {
  const _CountRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('최대 ${AppPolicy.maxCompanies}개까지', style: AppTypography.caption)),
        Text('$count / ${AppPolicy.maxCompanies}', style: AppTypography.captionStrong),
      ],
    );
  }
}
