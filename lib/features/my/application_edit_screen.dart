import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import '../common/pickers.dart';

/// 6-8 지원 정보 수정
class ApplicationEditScreen extends ConsumerStatefulWidget {
  const ApplicationEditScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<ApplicationEditScreen> createState() => _ApplicationEditScreenState();
}

class _ApplicationEditScreenState extends ConsumerState<ApplicationEditScreen> {
  Preparation? _draft;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updatePreparation(_draft!);
      ref.invalidate(preparationsProvider);
      ref.invalidate(homeProvider);
      if (!mounted) return;
      showToast(context, '지원 정보를 저장했어요.');
      context.pop();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preps = ref.watch(preparationsProvider);
    final original = preps.asData?.value.where((p) => p.companyId == widget.companyId).firstOrNull;
    _draft ??= original;
    final d = _draft;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '지원 정보'),
      body: preps.hasError
          ? ErrorView(error: preps.error!, onRetry: () => ref.invalidate(preparationsProvider))
          : d == null
              ? (preps.isLoading ? const LoadingView() : const EmptyView(title: '준비 기업에서 빠진 기업이에요'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
                  children: [
                    PageTitle('${d.companyName}\n지원 정보를 정리해요.'),
                    const SizedBox(height: AppSpacing.gap),
                    const FieldLabel('지원 직무'),
                    const SizedBox(height: AppSpacing.xs),
                    SelectField(
                      value: d.jobName,
                      placeholder: '직무를 선택해 주세요',
                      onTap: () async {
                        final job = await showJobPicker(context, companyName: d.companyName, selectedName: d.jobName);
                        if (job != null) setState(() => _draft = d.copyWith(jobId: job.id, jobName: job.name));
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('면접일 (선택)'),
                    const SizedBox(height: AppSpacing.xs),
                    SelectField(
                      value: d.interviewDate == null ? null : formatDotSpaced(d.interviewDate!),
                      placeholder: '연도. 월. 일.',
                      trailing: '달력',
                      onTap: () async {
                        final date = await pickInterviewDate(context, initial: d.interviewDate);
                        if (date != null) setState(() => _draft = d.copyWith(interviewDate: date));
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('날짜를 비우면 ‘일정 미정’으로 표시해요.', style: AppTypography.caption),
                  ],
                ),
      bottomNavigationBar: d == null
          ? null
          : BottomCta(children: [
              AppButton(label: '지원 정보 저장', loading: _saving, onPressed: d.hasJob ? _save : null),
              AppButton(
                label: '날짜 비우기',
                variant: AppButtonVariant.secondary,
                onPressed: d.interviewDate == null ? null : () => setState(() => _draft = d.copyWith(clearDate: true)),
              ),
            ]),
    );
  }
}
