import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../data/models/records.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import '../common/pickers.dart';
import '../home/company_switch_sheet.dart';

/// 5-1 퀴즈 복습 · 5-2 면접 복습
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.initialTab});

  /// 'quiz' | 'interview'
  final String? initialTab;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late int _tab = widget.initialTab == 'interview' ? 1 : 0;

  @override
  void didUpdateWidget(covariant ReviewScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != null && widget.initialTab != old.initialTab) {
      _tab = widget.initialTab == 'interview' ? 1 : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final selectedId = ref.watch(selectedCompanyIdProvider);
    final summary = home.asData?.value;
    final current = summary == null ? null : resolveSelected(summary, selectedId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        trailing: current == null
            ? null
            : CompanyChip(
                label: current.companyName,
                onTap: () => showCompanySwitchSheet(context, home: summary!, selectedId: current.companyId),
              ),
      ),
      body: home.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(homeProvider)),
        data: (_) {
          if (current == null) {
            return const EmptyView(title: '준비 중인 기업이 없어요', description: '마이 > 준비 기업 관리에서 기업을 추가해 주세요.');
          }
          final companyId = current.companyId;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(quizReviewProvider(companyId));
              ref.invalidate(interviewRecordsProvider(companyId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
              children: [
                const PageTitle('기록을 다시 보면,\n답변이 더 단단해져요.', large: false),
                const SizedBox(height: AppSpacing.md),
                SegmentedTabs(labels: const ['퀴즈 복습', '면접 복습'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
                const SizedBox(height: AppSpacing.md),
                if (_tab == 0) _QuizReview(companyId: companyId) else _InterviewReview(companyId: companyId),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- 퀴즈 복습

class _QuizReview extends ConsumerStatefulWidget {
  const _QuizReview({required this.companyId});

  final String companyId;

  @override
  ConsumerState<_QuizReview> createState() => _QuizReviewState();
}

class _QuizReviewState extends ConsumerState<_QuizReview> {
  bool _wrongOnly = true;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(quizReviewProvider(widget.companyId));
    return items.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: LoadingView()),
      error: (e, _) => ErrorView(error: e, compact: true, onRetry: () => ref.invalidate(quizReviewProvider(widget.companyId))),
      data: (all) {
        if (all.isEmpty) {
          return EmptyView(
            compact: true,
            title: '아직 푼 퀴즈가 없어요',
            description: '오늘의 퀴즈를 풀면 여기에서 다시 볼 수 있어요.',
            actionLabel: '오늘의 퀴즈 풀기',
            onAction: () => context.push(Routes.quiz(widget.companyId)),
          );
        }
        final wrong = all.where((i) => i.wrong).toList();
        final shown = _wrongOnly ? wrong : all;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SelectChip(label: '오답 ${wrong.length}', selected: _wrongOnly, onTap: () => setState(() => _wrongOnly = true)),
                const SizedBox(width: AppSpacing.xs),
                SelectChip(label: '풀었던 문제 ${all.length}', selected: !_wrongOnly, onTap: () => setState(() => _wrongOnly = false)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (shown.isEmpty)
              const EmptyView(compact: true, title: '다시 풀 오답이 없어요', description: '틀린 문제가 생기면 여기에 모아 둘게요.')
            else
              for (final item in shown) ...[
                _QuizReviewCard(item: item),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        );
      },
    );
  }
}

class _QuizReviewCard extends StatelessWidget {
  const _QuizReviewCard({required this.item});

  final QuizReviewItem item;

  @override
  Widget build(BuildContext context) {
    final ev = item.evidence ?? item.question.evidence;
    return OutlinedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TagRow([item.wrong ? '오답' : '정답', item.question.kind.label]),
          const SizedBox(height: AppSpacing.sm),
          Text(item.question.prompt, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(item.explanation, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (ev != null)
                TextLink(
                  label: '공시 근거  ›',
                  style: AppTypography.body2Medium,
                  onTap: () => showEvidenceSheet(context, evidence: ev, questionId: item.question.id),
                ),
              const Spacer(),
              TextLink(
                label: '이 문제 다시 풀기  ›',
                style: AppTypography.body2Strong,
                onTap: () => context.push(Routes.quizRetry(item.id, item.companyId)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 면접 복습

enum _InterviewFilter { all, needsWork, complete }

class _InterviewReview extends ConsumerStatefulWidget {
  const _InterviewReview({required this.companyId});

  final String companyId;

  @override
  ConsumerState<_InterviewReview> createState() => _InterviewReviewState();
}

class _InterviewReviewState extends ConsumerState<_InterviewReview> {
  _InterviewFilter _filter = _InterviewFilter.all;

  Future<void> _delete(InterviewRecord r) async {
    final ok = await showConfirmDialog(
      context,
      title: '이 질문과 답변을 지울까요?',
      message: '모든 시도와 피드백이 함께 지워지고 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(recordsRepositoryProvider).deleteInterviewRecord(r.questionId);
      invalidateProgress(ref);
      if (mounted) showToast(context, '삭제했어요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(interviewRecordsProvider(widget.companyId));
    return records.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: LoadingView()),
      error: (e, _) => ErrorView(error: e, compact: true, onRetry: () => ref.invalidate(interviewRecordsProvider(widget.companyId))),
      data: (all) {
        if (all.isEmpty) {
          return EmptyView(
            compact: true,
            title: '아직 답한 면접 질문이 없어요',
            description: '오늘의 면접 질문에 답하면 피드백과 함께 모아 둘게요.',
            actionLabel: '오늘의 면접 질문 보기',
            onAction: () => context.push(Routes.todayInterview(widget.companyId)),
          );
        }
        final shown = switch (_filter) {
          _InterviewFilter.all => all,
          _InterviewFilter.needsWork => all.where((r) => r.status == AnswerStatus.needsWork).toList(),
          _InterviewFilter.complete => all.where((r) => r.status == AnswerStatus.complete).toList(),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final (f, label) in const [
                  (_InterviewFilter.all, '전체'),
                  (_InterviewFilter.needsWork, '보완 필요'),
                  (_InterviewFilter.complete, '완성 답변'),
                ]) ...[
                  SelectChip(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (shown.isEmpty)
              const EmptyView(compact: true, title: '해당하는 답변이 없어요')
            else
              for (final r in shown) ...[
                _InterviewRecordCard(record: r, onDelete: () => _delete(r)),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        );
      },
    );
  }
}

class _InterviewRecordCard extends StatelessWidget {
  const _InterviewRecordCard({required this.record, required this.onDelete});

  final InterviewRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final draft = r.status == AnswerStatus.draft;
    return OutlinedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TagChip(r.status.label),
              if (r.score != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${r.score}점 · 기준 ${r.metCount ?? 0}/${AppPolicy.criteriaCount}',
                  style: AppTypography.captionMedium.copyWith(color: AppColors.textPrimary),
                ),
              ],
              const Spacer(),
              InkWell(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: Text('삭제', style: AppTypography.caption.copyWith(color: AppColors.textSub)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(r.questionText, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  draft || r.lastAt == null ? '아직 답변 없음' : '시도 ${r.attempts}회 · ${formatShort(r.lastAt!)}',
                  style: AppTypography.caption,
                ),
              ),
              TextLink(
                label: '이어서 답변하기  ›',
                style: AppTypography.body2Strong,
                onTap: () => context.push(draft ? Routes.interviewAnswer(r.questionId) : Routes.answerView(r.questionId)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
