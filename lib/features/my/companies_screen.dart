import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import '../common/pickers.dart';

/// 피그마 최종 6-2 준비 기업 관리 (763:16543 · 763:16602) · 6-2 준비 기업 수정 (960:5340) · 6-3 기업 추가 시트 (960:4635)
/// "새로운 기업 추가하기" 검색창 → 기업 추가하기 화면 → 직무·면접일 시트
/// 준비 기업 카드: 빼기 · 정보 수정하기 / 준비했던 기업: 추가
class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  static void _refresh(WidgetRef ref) {
    ref.invalidate(preparationsProvider);
    ref.invalidate(homeProvider);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Preparation p) async {
    final ok = await showConfirmDialog(
      context,
      warning: true,
      title: '${withObjectParticle(p.companyName)} 뺄까요?',
      message: '오늘의 학습에서 빠지고,\n지난 기록은 준비했던 기업에 남아요',
      cancelLabel: '취소',
      confirmLabel: '빼기',
    );
    if (!ok) return;
    try {
      await ref.read(profileRepositoryProvider).removePreparation(p.companyId);
      _refresh(ref);
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  bool _full(BuildContext context, int count) {
    if (count < AppPolicy.maxCompanies) return false;
    showNoticeDialog(context, title: '준비 기업 ${AppPolicy.maxCompanies}개를 모두 채웠어요', message: '하나를 빼면 새 기업을 추가할 수 있어요');
    return true;
  }

  Future<void> _search(BuildContext context, WidgetRef ref, List<Preparation> list) async {
    if (_full(context, list.length)) return;
    final company = await CompanySearchScreen.open(context, exclude: {for (final p in list) p.companyId});
    if (company == null || !context.mounted) return;
    await _add(context, ref, company, list.length);
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Company c, int count, {PastPreparation? previous}) async {
    if (_full(context, count)) return;
    final past = previous ?? ref.read(pastPreparationsProvider).asData?.value
        .where((p) => p.companyId == c.id).firstOrNull;
    final initial = Preparation.fromCompany(c).copyWith(jobId: past?.jobId, jobName: past?.jobName);
    final added = await showAppSheet<bool>(
      context,
      title: c.name,
      builder: (_) => PrepSheet(initial: initial, isNew: true),
    );
    if (added == true && context.mounted) showToast(context, '${withObjectParticle(c.name)} 준비 기업에 추가했어요.');
  }

  Future<void> _edit(BuildContext context, Preparation p) async {
    final saved = await showAppSheet<bool>(context, title: p.companyName, builder: (_) => PrepSheet(initial: p, isNew: false));
    if (saved == true && context.mounted) showToast(context, '지원 정보를 바꿨어요.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preps = ref.watch(preparationsProvider);
    final past = ref.watch(pastPreparationsProvider).asData?.value ?? const <PastPreparation>[];
    final label = AppTypography.body2Medium.copyWith(color: AppColors.textCaption);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '준비 기업 관리'),
      body: preps.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(preparationsProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(child: Text('나의 준비 기업', style: label)),
                  Text('${list.length}/${AppPolicy.maxCompanies}', style: label),
                ],
              ),
            ),
            SearchField(hint: '새로운 기업 추가하기', onTap: () => _search(context, ref, list)),
            const SizedBox(height: AppSpacing.lg),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: StatusMessage(icon: null, title: '아직 준비 중인 기업이 없어요', description: '준비할 기업을 추가하면 오늘의 학습이 시작돼요.'),
              ),
            for (final p in list) ...[
              _PrepCard(prep: p, onRemove: () => _remove(context, ref, p), onEdit: () => _edit(context, p)),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.sm),
                child: Text('준비했던 기업  ${past.length}', style: label),
              ),
              for (final p in past) ...[
                CompanyTile(
                  name: p.companyName,
                  subtitle: '퀴즈 ${p.quizCount}문제 · 면접 답변 ${p.answerCount}개',
                  trailing: TextLink(
                    label: '추가',
                    // QA 1529:9898: "빼기"(12)와 글자 크기를 맞춘다 (추가가 14 로 더 컸다)
                    style: AppTypography.caption.copyWith(color: AppColors.ink, fontWeight: AppTypography.semibold),
                    onTap: () => _add(context, ref, p.company, list.length, previous: p),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 준비 기업 카드: 로고 · 이름 · "마케팅 · 2026.10.24" · 빼기, 아래 회색 "정보 수정하기"
class _PrepCard extends StatelessWidget {
  const _PrepCard({required this.prep, required this.onRemove, required this.onEdit});

  final Preparation prep;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = prep;
    final sub = [p.jobName ?? '직무 미정', p.interviewDate == null ? '면접일 미정' : formatDot(p.interviewDate!)].join(' · ');
    return OutlinedBox(
      radius: AppRadius.button,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CompanyLogo(name: p.companyName, bordered: true),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.companyName, style: AppTypography.cardTitle.copyWith(color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(sub, style: AppTypography.caption.copyWith(color: AppColors.textCaption)),
                  ],
                ),
              ),
              TextLink(label: '빼기', style: AppTypography.caption.copyWith(color: AppColors.textCaption), onTap: onRemove),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.fillSecondary,
                foregroundColor: AppColors.textStrong,
                textStyle: AppTypography.body2Strong,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialogButton)),
                splashFactory: NoSplash.splashFactory,
              ),
              child: const Text('정보 수정하기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 6-3 기업 추가 시트 · 6-2 준비 기업 수정 시트: 지원 직무 › · 면접일 (선택) → 추가하기 / 수정 완료
class PrepSheet extends ConsumerStatefulWidget {
  const PrepSheet({super.key, required this.initial, required this.isNew});

  final Preparation initial;
  final bool isNew;

  @override
  ConsumerState<PrepSheet> createState() => _PrepSheetState();
}

class _PrepSheetState extends ConsumerState<PrepSheet> {
  late Job? _job = widget.initial.hasJob ? Job(id: widget.initial.jobId ?? '', name: widget.initial.jobName!) : null;
  late DateTime? _date = widget.initial.interviewDate;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final item = Preparation(
        companyId: widget.initial.companyId,
        companyName: widget.initial.companyName,
        industry: widget.initial.industry,
        jobId: _job!.id.isEmpty ? null : _job!.id,
        jobName: _job!.name,
        interviewDate: _date,
      );
      final repo = ref.read(profileRepositoryProvider);
      if (widget.isNew) {
        await repo.addPreparation(item);
      } else {
        await repo.updatePreparation(item);
      }
      CompaniesScreen._refresh(ref);
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.md),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('지원 직무'),
            const SizedBox(height: AppSpacing.xs),
            SelectField(
              value: _job?.name,
              placeholder: '직무를 선택해주세요',
              onTap: () async {
                final job = await showJobPicker(context, companyName: widget.initial.companyName, selectedName: _job?.name);
                if (job != null) setState(() => _job = job);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldLabel('면접일 (선택)'),
            const SizedBox(height: AppSpacing.xs),
            SelectField(
              value: _date == null ? null : formatDot(_date!),
              placeholder: '연도. 월. 일',
              trailing: '',
              onTap: () async {
                final d = await pickInterviewDate(context, initial: _date);
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: widget.isNew ? '추가하기' : '수정 완료',
              loading: _saving,
              onPressed: _job == null || _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
