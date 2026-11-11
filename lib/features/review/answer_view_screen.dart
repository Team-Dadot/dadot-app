import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/app_exception.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../data/models/records.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../interview/interview_widgets.dart';

/// 5-2 면접 복습 → 답변 피드백 (지난 시도 다시 보기 · 다시 답하기)
class AnswerViewScreen extends ConsumerStatefulWidget {
  const AnswerViewScreen({super.key, required this.questionId});

  final String questionId;

  @override
  ConsumerState<AnswerViewScreen> createState() => _AnswerViewScreenState();
}

class _AnswerViewScreenState extends ConsumerState<AnswerViewScreen> {
  /// 고른 시도 (null 이면 마지막 시도)
  String? _answerId;

  Future<void> _deleteAttempt(AnswerFeedback a) async {
    final ok = await showConfirmDialog(
      context,
      title: '시도 ${a.attempt} 답변을 지울까요?',
      message: '이 시도의 답변과 피드백이 지워지고 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(recordsRepositoryProvider).deleteAttempt(a.answerId);
      invalidateProgress(ref);
      ref.invalidate(interviewRecordProvider(widget.questionId));
      setState(() => _answerId = null);
      if (mounted) showToast(context, '삭제했어요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(interviewRecordProvider(widget.questionId));
    final d = detail.asData?.value;
    final last = d?.attempts.lastOrNull;
    final remaining = d?.question.retryRemaining ?? last?.retryRemaining ?? 0;
    final selected =
        d?.attempts.where((a) => a.answerId == _answerId).firstOrNull ?? last;
    // 서버 usage(canSubmit · questionRemaining · blockedReason) 기준으로 버튼을 정한다 (질문·피드백 화면과 같은 규칙).
    // QA: 더 답할 수 없는 질문은 복습 목록처럼 버튼 없이 평가만 본다 (0회 버튼을 눌러 안내를 띄우지 않는다)
    final blocked = d != null && (d.question.blocked || (last != null && remaining <= 0));
    final cta = d == null || blocked
        ? null
        : BottomCta(
            children: [
              if (last == null)
                AppButton(
                  label: '이어서 답변하기',
                  onPressed: () =>
                      context.push(Routes.interviewAnswer(widget.questionId)),
                )
              else
                RetryAnswerButton(
                  prefix: '다시 답변하기',
                  remaining: remaining,
                  onRetry: () =>
                      context.push(Routes.interviewAnswer(widget.questionId)),
                ),
            ],
          );
    // 평가가 끝나지 않은(평가 중 · 실패 · 조회 실패) 시도는 점수 화면 대신 상태 안내 (0점으로 보이지 않게)
    if (d != null && selected != null && selected.evaluation != EvaluationState.done) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppNavBar(title: '면접 피드백'),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(interviewRecordProvider(widget.questionId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
            children: [
              _PendingEvaluation(
                question: d.question.text,
                attempt: selected,
                blockReason: blocked ? (d.question.blockReason ?? 'QUESTION_LIMIT_EXCEEDED') : null,
                picker: _picker(d, selected),
                busy: _retrying,
                onAction: () => _evaluationAction(selected),
              ),
            ],
          ),
        ),
        bottomNavigationBar: cta,
      );
    }
    // 피그마 1337: 지난 답변이 있으면 면접 피드백과 같은 진한 히어로 + 카드
    if (d != null && selected != null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () =>
                ref.refresh(interviewRecordProvider(widget.questionId).future),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                FeedbackHero(
                  feedback: selected,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                _body(d),
              ],
            ),
          ),
          bottomNavigationBar: cta,
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '면접 피드백'),
      body: detail.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () =>
              ref.invalidate(interviewRecordProvider(widget.questionId)),
        ),
        data: (d) => ListView(children: [_body(d)]),
      ),
      bottomNavigationBar: cta,
    );
  }

  Widget _body(InterviewRecordDetail d) {
    final attempts = d.attempts;
    final selected =
        attempts.where((a) => a.answerId == _answerId).firstOrNull ??
        attempts.lastOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(d.question.text, style: AppTypography.title4),
                ),
                const SizedBox(height: AppSpacing.gap),
                const EmptyView(
                  compact: true,
                  title: '아직 제출한 답변이 없어요',
                  description: '임시저장한 답변을 이어서 써 보세요.',
                ),
              ],
            ),
          )
        else
          FeedbackContent(
            feedback: selected,
            questionText: d.question.text,
            onDeleteAttempt: () => _deleteAttempt(selected),
            attemptPicker: _picker(d, selected),
          ),
      ],
    );
  }

  /// 시도가 2개 이상이면 "시도 1 · 시도 2" 칩
  Widget? _picker(InterviewRecordDetail d, AnswerFeedback selected) => d.attempts.length < 2
      ? null
      : Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final a in d.attempts)
              SelectChip(
                label: '시도 ${a.attempt}',
                selected: a.answerId == selected.answerId,
                onTap: () => setState(() => _answerId = a.answerId),
              ),
          ],
        );

  bool _retrying = false;

  /// 평가 실패 → 다시 평가 요청 / 평가 중 · 조회 실패 → 결과만 다시 불러오기 (새 답변은 내지 않는다)
  Future<void> _evaluationAction(AnswerFeedback a) async {
    if (a.evaluation == EvaluationState.failed) {
      setState(() => _retrying = true);
      try {
        await ref.read(interviewRepositoryProvider).retryEvaluation(a.answerId);
      } catch (e) {
        if (mounted) showErrorToast(context, e);
      } finally {
        if (mounted) setState(() => _retrying = false);
      }
    }
    ref.invalidate(interviewRecordProvider(widget.questionId));
    ref.invalidate(feedbackProvider(a.answerId));
  }
}

/// 평가가 끝나지 않은 시도: 질문 · (시도 칩) · 상태 안내 + 버튼 · 내 답변
class _PendingEvaluation extends StatelessWidget {
  const _PendingEvaluation({
    required this.question,
    required this.attempt,
    required this.blockReason,
    required this.picker,
    required this.busy,
    required this.onAction,
  });

  final String question;
  final AnswerFeedback attempt;
  final String? blockReason;
  final Widget? picker;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final (String title, String description, String action) = switch (attempt.evaluation) {
      EvaluationState.failed => ('평가에 실패했어요', '답변은 저장돼 있어요. 다시 평가를 요청할 수 있어요.', '다시 평가하기'),
      EvaluationState.unavailable => ('평가 결과를 불러오지 못했어요', '연결 상태를 확인하고 다시 불러와 주세요.', '다시 불러오기'),
      _ => ('답변을 평가하고 있어요', '잠시 후 결과를 확인해 주세요.', '결과 다시 확인'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(question, style: AppTypography.title4)),
        if (picker != null) ...[const SizedBox(height: AppSpacing.md), picker!],
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(
            children: [
              StatusMessage(
                title: title,
                description: description,
                icon: attempt.evaluation == EvaluationState.processing ? null : StatusIcon.warning,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: action, small: true, expand: false, loading: busy, onPressed: busy ? null : onAction),
            ],
          ),
        ),
        if (blockReason != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppException.submitBlockText(blockReason).title,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.textGuide),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('시도 ${attempt.attempt} 내 답변', style: AppTypography.body2Strong.copyWith(color: AppColors.textStrong)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Text(attempt.content, style: AppTypography.body1.copyWith(color: AppColors.textSub, height: 1.6)),
        ),
      ],
    );
  }
}
