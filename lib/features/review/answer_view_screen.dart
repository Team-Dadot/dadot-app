import 'dart:async';

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

/// 완료된 평가는 기존 화면으로, 미완료 평가는 기존 로딩·오류 화면으로 표시한다.
class AnswerViewScreen extends ConsumerStatefulWidget {
  const AnswerViewScreen({super.key, required this.questionId});
  final String questionId;

  @override
  ConsumerState<AnswerViewScreen> createState() => _AnswerViewScreenState();
}

class _AnswerViewScreenState extends ConsumerState<AnswerViewScreen> {
  String? _answerId;
  Timer? _pollTimer;
  int _polls = 0;
  bool _retrying = false;
  bool _polling = false;
  final Map<String, EvaluationStatus> _observedStatuses = {};

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  InterviewAttemptEvaluation? _selected(InterviewRecordDetail detail) {
    final entries = detail.evaluationEntries;
    return entries.where((entry) => entry.answerId == _answerId).firstOrNull ?? entries.lastOrNull;
  }

  void _schedulePoll(InterviewAttemptEvaluation? entry) {
    if (entry?.status != EvaluationStatus.processing) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer != null || _polling || _polls >= 40) return;
    _pollTimer = Timer(const Duration(seconds: 2), () async {
      _pollTimer = null;
      if (!mounted) return;
      _polls++;
      _polling = true;
      try {
        await ref.refresh(interviewRecordProvider(widget.questionId).future);
      } catch (_) {
        // 조회 오류는 provider의 오류 화면으로 표시한다.
      } finally {
        _polling = false;
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _refresh() async {
    _polls = 0;
    try {
      await ref.refresh(interviewRecordProvider(widget.questionId).future);
    } catch (_) {
      // provider가 오류 상태를 보관한다.
    }
  }

  Future<void> _retryEvaluation(String answerId) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref.read(interviewRepositoryProvider).retryEvaluation(answerId);
      if (!mounted) return;
      _polls = 0;
      invalidateProgress(ref);
      ref.invalidate(interviewQuestionProvider(widget.questionId));
      ref.invalidate(interviewRecordProvider(widget.questionId));
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _deleteAttempt(AnswerFeedback answer) async {
    final ok = await showConfirmDialog(context,
      title: '시도 ${answer.attempt} 답변을 지울까요?',
      message: '이 시도의 답변과 피드백이 지워지고 되돌릴 수 없어요.', confirmLabel: '삭제');
    if (!ok || !mounted) return;
    try {
      await ref.read(recordsRepositoryProvider).deleteAttempt(answer.answerId);
      if (!mounted) return;
      invalidateProgress(ref);
      ref.invalidate(interviewQuestionProvider(widget.questionId));
      ref.invalidate(interviewRecordProvider(widget.questionId));
      setState(() { _answerId = null; _polls = 0; });
      showToast(context, '삭제했어요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(interviewRecordProvider(widget.questionId));
    final detail = async.asData?.value;
    final selected = detail == null ? null : _selected(detail);
    final feedback = selected?.feedback;
    _schedulePoll(selected);
    final entries = detail?.evaluationEntries ?? const <InterviewAttemptEvaluation>[];
    var changed = false;
    for (final entry in entries) {
      final previous = _observedStatuses[entry.answerId];
      _observedStatuses[entry.answerId] = entry.status;
      if (previous != null && previous != entry.status) changed = true;
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        invalidateProgress(ref);
        ref.invalidate(interviewQuestionProvider(widget.questionId));
      });
    }
    final remaining = detail?.question.retryRemaining ?? feedback?.retryRemaining ?? 0;
    final cta = detail == null || (entries.isEmpty && detail.question.blocked)
        ? null
        : BottomCta(children: [
            if (entries.isEmpty)
              AppButton(label: '이어서 답변하기',
                onPressed: () => context.push(Routes.interviewAnswer(widget.questionId)))
            else
              RetryAnswerButton(prefix: '다시 답변하기', remaining: remaining,
                canSubmit: !detail.question.blocked,
                blockedMessage: detail.question.blockedMessage,
                blockedHelp: detail.question.blockedHelp,
                onRetry: () => context.push(Routes.interviewAnswer(widget.questionId))),
          ]);
    if (detail != null && feedback != null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(onRefresh: _refresh,
            child: ListView(padding: EdgeInsets.zero, physics: const AlwaysScrollableScrollPhysics(), children: [
              FeedbackHero(feedback: feedback, onBack: () => Navigator.of(context).maybePop()),
              _body(detail),
            ])),
          bottomNavigationBar: cta,
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '면접 피드백'),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e,
          onRetry: () => ref.invalidate(interviewRecordProvider(widget.questionId))),
        data: (data) => RefreshIndicator(onRefresh: _refresh,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [_body(data)])),
      ),
      bottomNavigationBar: cta,
    );
  }

  Widget? _attemptPicker(InterviewRecordDetail detail, InterviewAttemptEvaluation selected) {
    final entries = detail.evaluationEntries;
    if (entries.length < 2) return null;
    return Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
      for (final entry in entries)
        SelectChip(label: '시도 ${entry.attempt}', selected: entry.answerId == selected.answerId,
          onTap: () => setState(() { _answerId = entry.answerId; _polls = 0; })),
    ]);
  }

  Widget _evaluationState(InterviewAttemptEvaluation entry) {
    if (_retrying || (entry.status == EvaluationStatus.processing && _polls < 40)) {
      return const LoadingView(message: '답변을 평가하고 있어요.');
    }
    final failed = entry.status == EvaluationStatus.failed;
    final cancelled = entry.status == EvaluationStatus.cancelled;
    final processing = entry.status == EvaluationStatus.processing;
    return ErrorView(
      error: entry.error ?? const AppException(AppErrorKind.server),
      compact: true,
      title: processing ? '평가가 진행 중이에요' : cancelled ? '평가가 취소됐어요' : failed ? '평가를 완료하지 못했어요' : null,
      description: processing ? '시간이 더 걸리고 있어요. 잠시 후 다시 확인해 주세요.'
          : cancelled ? '현재 질문의 자료와 답변 상태를 확인해 주세요.'
          : failed ? '답변은 유지돼요. 평가를 다시 시도해 주세요.' : null,
      onRetry: failed ? () => _retryEvaluation(entry.answerId) : _refresh,
    );
  }

  Widget _body(InterviewRecordDetail detail) {
    final selected = _selected(detail);
    final feedback = selected?.feedback;
    if (selected != null && feedback != null) {
      return FeedbackContent(feedback: feedback, questionText: detail.question.text,
        onDeleteAttempt: () => _deleteAttempt(feedback), attemptPicker: _attemptPicker(detail, selected));
    }
    final picker = selected == null ? null : _attemptPicker(detail, selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(header: true, child: Text(detail.question.text, style: AppTypography.title4)),
        const SizedBox(height: AppSpacing.gap),
        if (picker != null) ...[picker, const SizedBox(height: AppSpacing.gap)],
        if (selected == null)
          EmptyView(compact: true, title: '저장된 답변이 없어요',
            description: detail.question.blocked ? detail.question.blockedMessage : '임시저장한 답변을 이어서 써 보세요.')
        else
          _evaluationState(selected),
      ]),
    );
  }
}
