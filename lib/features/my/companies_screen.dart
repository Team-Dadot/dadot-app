import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import '../common/pickers.dart';

/// 피그마 6-2 준비 기업 관리 · 6-3 기업 추가 시트 ("현대자동차를 추가할까요?" · 지원 직무 · 면접일)
class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, Preparation p) async {
    final ok = await showConfirmDialog(
      context,
      title: '${withObjectParticle(p.companyName)} 준비 기업에서 뺄까요?',
      message: '오늘의 퀴즈·면접 질문이 더 이상 열리지 않아요. 지난 기록은 남아 있어요.',
      confirmLabel: '빼기',
    );
    if (!ok) return;
    try {
      await ref.read(profileRepositoryProvider).removePreparation(p.companyId);
      ref.invalidate(preparationsProvider);
      ref.invalidate(homeProvider);
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Company c, int count) async {
    if (count >= AppPolicy.maxCompanies) {
      showToast(context, '준비 기업은 최대 ${AppPolicy.maxCompanies}개까지예요. 다른 기업을 빼고 추가해 주세요.');
      return;
    }
    final added = await showAppSheet<bool>(context, title: '${withObjectParticle(c.name)} 추가할까요?', builder: (_) => _AddCompanySheet(company: c));
    if (added == true && context.mounted) showToast(context, '${withObjectParticle(c.name)} 준비 기업에 추가했어요.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preps = ref.watch(preparationsProvider);
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '준비 기업 관리'),
      body: preps.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(preparationsProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
          children: [
            SectionTitle(
              '나의 준비 기업',
              trailing: Text(
                '${list.length}/${AppPolicy.maxCompanies}',
                style: AppTypography.body2Medium.copyWith(color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // 검색창 (피그마 "새로운 기업 추가하기") — 검색 결과는 아래에 "추가" 카드로
            CompanySearch(
              exclude: {for (final p in list) p.companyId},
              itemBuilder: (c) => CompanyTile(
                name: c.name,
                subtitle: c.industry,
                onTap: () => _add(context, ref, c, list.length),
                trailing: Text('추가', style: AppTypography.body2Medium.copyWith(color: AppColors.textPlaceholder)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (list.isEmpty) const EmptyView(compact: true, title: '준비 중인 기업이 없어요', description: '위에서 기업을 검색해 추가해 주세요.'),
            for (final p in list) ...[
              CompanyTile(
                name: p.companyName,
                subtitle: prepSubtitle(jobName: p.jobName, dday: p.ddayFrom(now), date: p.interviewDate),
                onTap: () => context.push(Routes.myApplication(p.companyId)),
                trailing: InkWell(
                  onTap: () => _remove(context, ref, p),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Text('빼기', style: AppTypography.caption.copyWith(color: AppColors.textPlaceholder)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddCompanySheet extends ConsumerStatefulWidget {
  const _AddCompanySheet({required this.company});

  final Company company;

  @override
  ConsumerState<_AddCompanySheet> createState() => _AddCompanySheetState();
}

class _AddCompanySheetState extends ConsumerState<_AddCompanySheet> {
  Job? _job;
  DateTime? _date;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).addPreparation(
            Preparation.fromCompany(widget.company).copyWith(jobId: _job!.id, jobName: _job!.name, interviewDate: _date),
          );
      ref.invalidate(preparationsProvider);
      ref.invalidate(homeProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('지원 직무'),
          const SizedBox(height: AppSpacing.xs),
          SelectField(
            value: _job?.name,
            placeholder: '직무를 선택해주세요',
            onTap: () async {
              final job = await showJobPicker(context, companyName: widget.company.name, selectedName: _job?.name);
              if (job != null) setState(() => _job = job);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const FieldLabel('면접일 (선택)'),
          const SizedBox(height: AppSpacing.xs),
          SelectField(
            value: _date == null ? null : formatDotSpaced(_date!),
            placeholder: '연도. 월. 일.',
            trailing: '',
            onTap: () async {
              final d = await pickInterviewDate(context, initial: _date);
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: '추가하기', loading: _saving, onPressed: _job == null ? null : _save),
        ],
      ),
    );
  }
}
