import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import 'data_providers.dart';

// ---------------------------------------------------------------- 직무 선택 시트 (1-4)

/// "LG전자 지원 직무" 시트. 고르면 Job 을 돌려준다 (직접 입력은 id 가 빈 문자열).
Future<Job?> showJobPicker(BuildContext context, {required String companyName, String? selectedName}) {
  return showAppSheet<Job>(
    context,
    title: '$companyName 지원 직무',
    expand: true,
    builder: (_) => _JobPickerBody(selectedName: selectedName),
  );
}

class _JobPickerBody extends ConsumerStatefulWidget {
  const _JobPickerBody({this.selectedName});

  final String? selectedName;

  @override
  ConsumerState<_JobPickerBody> createState() => _JobPickerBodyState();
}

class _JobPickerBodyState extends ConsumerState<_JobPickerBody> {
  final _search = TextEditingController();
  final _custom = TextEditingController();
  String? _openCategory;
  bool _customOpen = false;

  @override
  void dispose() {
    _search.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _pick(Job job) => Navigator.of(context).pop(job);

  Widget _chips(List<Job> jobs) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final j in jobs) SelectChip(label: j.name, selected: j.name == widget.selectedName, onTap: () => _pick(j)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(jobCatalogProvider);
    return catalog.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(jobCatalogProvider)),
      data: (c) {
        final q = _search.text.trim();
        final matches = q.isEmpty ? const <Job>[] : {for (final j in c.all.where((j) => j.name.contains(q))) j.name: j}.values.toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xl),
          children: [
            AppTextField(
              controller: _search,
              hint: '직무 검색 (예: 해외영업)',
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            if (q.isNotEmpty) ...[
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      Text('“$q” 직무를 찾지 못했어요', style: AppTypography.cardTitle),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('다시 검색하거나 직접 입력해 주세요.', style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: '“$q”(으)로 직접 입력',
                        variant: AppButtonVariant.outline,
                        onPressed: () => _pick(Job(id: '', name: q)),
                      ),
                    ],
                  ),
                )
              else
                _chips(matches),
            ] else ...[
              Text('자주 찾는 직무', style: AppTypography.captionMedium.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              _chips(c.popular),
              const SizedBox(height: AppSpacing.lg),
              Text('전체 직무', style: AppTypography.captionMedium.copyWith(color: AppColors.textPrimary)),
              for (final cat in c.categories) ...[
                _AccordionRow(
                  title: cat.name,
                  open: _openCategory == cat.id,
                  onTap: () => setState(() => _openCategory = _openCategory == cat.id ? null : cat.id),
                ),
                if (_openCategory == cat.id) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _chips(cat.jobs)),
                const LineDivider(),
              ],
              _AccordionRow(
                title: '찾는 직무가 없어요 · 직접 입력',
                titleStyle: AppTypography.body1Medium,
                open: _customOpen,
                onTap: () => setState(() => _customOpen = !_customOpen),
              ),
              if (_customOpen) ...[
                AppTextField(controller: _custom, hint: '직무 이름', autofocus: true, onChanged: (_) => setState(() {})),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: '이 직무로 정하기',
                  onPressed: _custom.text.trim().isEmpty ? null : () => _pick(Job(id: '', name: _custom.text.trim())),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _AccordionRow extends StatelessWidget {
  const _AccordionRow({required this.title, required this.open, required this.onTap, this.titleStyle});

  final String title;
  final bool open;
  final VoidCallback onTap;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(child: Text(title, style: titleStyle ?? AppTypography.cardTitle)),
              Text(open ? '−' : '+', style: AppTypography.subheading.copyWith(fontWeight: AppTypography.regular)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 면접일 (오늘 이전 날짜는 비활성)

Future<DateTime?> pickInterviewDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final init = initial != null && !initial.isBefore(today) ? initial : today;
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: today,
    lastDate: DateTime(today.year + 2, 12, 31),
    helpText: '면접일 선택',
    cancelText: '취소',
    confirmText: '확인',
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary, onPrimary: AppColors.white),
      ),
      child: child!,
    ),
  );
}

// ---------------------------------------------------------------- 공시 근거

/// 근거 카드 (기아 2025 사업보고서 / 공시일 … / 발췌)
class EvidenceCard extends StatelessWidget {
  const EvidenceCard({super.key, required this.evidence, this.compactTitle = false, this.quoted = false});

  final Evidence evidence;

  /// 공시 근거 시트는 원문 인용이라 “ ” 로 감싼다
  final bool quoted;

  /// 답변 보기 화면은 제목 14
  final bool compactTitle;

  @override
  Widget build(BuildContext context) {
    // 피그마 4-2: 흰 카드 · 제목 16 · "공시일 | 2026.03.12" / "대상 기간 | …" 12 회색 · 본문 15
    final meta = [
      if (evidence.publishedAt != null) '공시일  |  ${evidence.publishedAt}',
      if (evidence.period != null) '대상 기간  |  ${evidence.period}',
    ];
    return OutlinedBox(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(evidence.title, style: compactTitle ? AppTypography.body1Strong : AppTypography.cardTitle),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final m in meta) Text(m, style: AppTypography.caption.copyWith(color: AppColors.textPlaceholder)),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            quoted ? '“${evidence.excerpt}”' : evidence.excerpt,
            style: AppTypography.body1.copyWith(color: AppColors.textStrong, height: 1.6),
          ),
          if (evidence.interpretation != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('해석 · ${evidence.interpretation}', style: AppTypography.caption.copyWith(color: AppColors.textSub)),
          ],
        ],
      ),
    );
  }
}

/// 공시 근거 시트 (3-4). [questionId] 가 있으면 "오류 제보하기" 를 보낸다.
Future<void> showEvidenceSheet(BuildContext context, {required Evidence evidence, String? questionId}) {
  return showAppSheet<void>(
    context,
    title: '공시 근거',
    builder: (_) => _EvidenceSheetBody(evidence: evidence, questionId: questionId),
  );
}

class _EvidenceSheetBody extends ConsumerStatefulWidget {
  const _EvidenceSheetBody({required this.evidence, this.questionId});

  final Evidence evidence;
  final String? questionId;

  @override
  ConsumerState<_EvidenceSheetBody> createState() => _EvidenceSheetBodyState();
}

class _EvidenceSheetBodyState extends ConsumerState<_EvidenceSheetBody> {
  bool _reporting = false;

  Future<void> _report() async {
    final id = widget.questionId;
    if (id == null) return;
    setState(() => _reporting = true);
    try {
      await ref.read(quizRepositoryProvider).reportQuestion(questionId: id, reason: '공시 근거 시트에서 오류 제보');
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, '제보해 주셔서 고마워요. 확인 후 고칠게요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.evidence.url;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvidenceCard(evidence: widget.evidence, quoted: true),
          const SizedBox(height: AppSpacing.sm),
          if (url != null)
            AppButton(
              label: 'DART 원문 보기 ↗',
              variant: AppButtonVariant.outline,
              onPressed: () => unawaited(ref.read(linkServiceProvider).open(url)),
            ),
          if (widget.questionId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppButton(label: '오류 제보하기', variant: AppButtonVariant.secondary, loading: _reporting, onPressed: _report),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 기업 검색 목록 (1-2, 6-2)

/// 검색창 + 결과 목록. 목록은 Column 이라 바깥 ListView 안에 넣어 쓴다.
class CompanySearch extends ConsumerStatefulWidget {
  const CompanySearch({super.key, required this.itemBuilder, this.exclude = const {}, this.header});

  final Widget Function(Company company) itemBuilder;

  /// 검색창과 목록 사이 (1-2 "최대 5개까지  2 / 5")
  final Widget? header;

  /// 결과에서 뺄 기업 (이미 준비 중)
  final Set<String> exclude;

  @override
  ConsumerState<CompanySearch> createState() => _CompanySearchState();
}

class _CompanySearchState extends ConsumerState<CompanySearch> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider(_query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: _search, hint: '기업명 또는 업종으로 검색', onChanged: _onQuery, textInputAction: TextInputAction.search),
        const SizedBox(height: AppSpacing.gap),
        if (widget.header != null) ...[widget.header!, const SizedBox(height: AppSpacing.gap)],
        companies.when(
          skipLoadingOnReload: true,
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
          error: (e, _) => ErrorView(error: e, compact: true, onRetry: () => ref.invalidate(companiesProvider(_query))),
          data: (list) {
            final shown = list.where((c) => !widget.exclude.contains(c.id)).toList();
            if (shown.isEmpty) {
              return EmptyView(
                compact: true,
                title: _query.isEmpty ? '더 추가할 기업이 없어요' : '“$_query” 기업을 찾지 못했어요',
                description: _query.isEmpty ? null : '다시 검색해 주세요. 아직 준비하지 않은 기업일 수 있어요.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.gap),
                  widget.itemBuilder(shown[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
