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

/// 피그마 최종 1-2 STEP 1 "어떤 기업을 준비하고 있나요?": 검색창을 누르면 "기업 추가하기" 화면,
/// 고른 기업은 아래 카드로 (빼기). 5개를 넘기면 1-E3 안내 팝업.
class OnboardingCompaniesScreen extends ConsumerStatefulWidget {
  const OnboardingCompaniesScreen({super.key});

  @override
  ConsumerState<OnboardingCompaniesScreen> createState() => _OnboardingCompaniesScreenState();
}

class _OnboardingCompaniesScreenState extends ConsumerState<OnboardingCompaniesScreen> {
  bool _saving = false;

  static void _add(BuildContext context, WidgetRef ref, Company c) {
    final ctrl = ref.read(onboardingPrepsProvider.notifier);
    final list = ctrl.current;
    if (list.any((p) => p.companyId == c.id)) return;
    if (list.length >= AppPolicy.maxCompanies) {
      showNoticeDialog(
        context,
        title: '준비 기업 ${AppPolicy.maxCompanies}개를 모두 채웠어요',
        message: '하나를 빼면 새 기업을 추가할 수 있어요',
      );
      return;
    }
    ctrl.setLocal([...list, Preparation.fromCompany(c)]);
  }

  static void _remove(WidgetRef ref, String companyId) {
    final ctrl = ref.read(onboardingPrepsProvider.notifier);
    ctrl.setLocal(ctrl.current.where((p) => p.companyId != companyId).toList());
  }

  Future<void> _openSearch() async {
    final before = ref.read(onboardingPrepsProvider.notifier).current.length;
    await CompanySearchScreen.open(
      context,
      watchAdded: (ref) => [
        for (final p in ref.watch(onboardingPrepsProvider).asData?.value ?? const <Preparation>[]) (id: p.companyId, name: p.companyName),
      ],
      onAdd: _add,
      onRemove: _remove,
    );
    if (!mounted) return;
    // 피그마 1074:12476: 검색 화면에서 돌아오면 "준비 중인 기업이 2개 추가되었어요 · 확인"
    final added = ref.read(onboardingPrepsProvider.notifier).current.length - before;
    if (added > 0) showDoneToast(context, '준비 중인 기업이 $added개 추가되었어요');
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
    final ok = await showConfirmDialog(
      context,
      warning: true,
      title: '첫 설정을 그만둘까요?',
      message: '시작 화면으로 돌아가요',
      cancelLabel: '진행하기',
      confirmLabel: '나가기',
    );
    if (ok && mounted) await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingLoadGate(builder: (preps) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: OnboardingStepScaffold(
          step: 1,
          // 피그마 1-2 (763:17487): 첫 단계도 ‹ 뒤로가기. 앞 화면이 없으니 "첫 설정을 그만둘까요?" → 로그인 화면
          onBack: _back,
          title: '어떤 기업을\n준비하고 있나요?',
          bottom: [
            AppButton(label: '다음', loading: _saving, onPressed: preps.isEmpty ? null : _next),
          ],
          children: [
            SearchField(hint: '기업 이름을 검색해보세요', onTap: _openSearch),
            if (preps.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  const Expanded(child: OnboardingLabel('내가 추가한 기업')),
                  OnboardingLabel('${preps.length}/${AppPolicy.maxCompanies}'),
                ],
              ),
              for (final p in preps) ...[
                CompanyTile(
                  name: p.companyName,
                  trailing: TextLink(
                    label: '삭제',
                    style: AppTypography.body2Medium.copyWith(color: AppColors.textGuide),
                    onTap: () => _remove(ref, p.companyId),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ],
        ),
      );
    });
  }
}
