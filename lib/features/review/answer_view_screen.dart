import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../data/models/records.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../interview/feedback_screen.dart';
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppNavBar(title: '결과 확인', color: AppColors.surface),
      body: detail.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(interviewRecordProvider(widget.questionId))),
        data: _body,
      ),
      bottomNavigationBar: d == null
          ? null
          : BottomCta(children: [
              AppButton(
                label: last == null ? '이어서 답변하기  →' : retryLabel(last.copyWith(retryRemaining: remaining), prefix: '다시 답하기'),
                onPressed: last == null || remaining > 0 ? () => context.push(Routes.interviewAnswer(widget.questionId)) : null,
              ),
            ]),
    );
  }

  Widget _body(InterviewRecordDetail d) {
    final attempts = d.attempts;
    final selected = attempts.where((a) => a.answerId == _answerId).firstOrNull ?? attempts.lastOrNull;
    return ListView(
      children: [
        if (selected == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(d.question.text, style: AppTypography.title4)),
                const SizedBox(height: AppSpacing.gap),
                const EmptyView(compact: true, title: '아직 제출한 답변이 없어요', description: '임시저장한 답변을 이어서 써 보세요.'),
              ],
            ),
          )
        else
          FeedbackContent(
            feedback: selected,
            questionText: d.question.text,
            onDeleteAttempt: () => _deleteAttempt(selected),
            attemptPicker: attempts.length < 2
                ? null
                : Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final a in attempts)
                        SelectChip(
                          label: '시도 ${a.attempt}',
                          selected: a.answerId == selected.answerId,
                          onTap: () => setState(() => _answerId = a.answerId),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}
