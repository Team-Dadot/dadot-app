import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/error/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'interview_widgets.dart';

/// 피그마 최종 "면접 피드백" (1335:8520 완성답변 · 1335:8635 보완필요)
/// 진한 히어로(폴더: 배지 · 점수 % · ! 한 줄 요약 · 진행 바 · 불꽃/느낌표) + 회색 카드 목록
/// → 재답변 (남은/3) · 다음 질문 (오늘 질문을 다 했으면 마무리하기)
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, required this.answerId, this.fromReview = false});

  final String answerId;

  /// 피그마 1653:10895: 복습 탭에서 다시 답변한 뒤에는 "다시 답변하기" 버튼 하나만
  final bool fromReview;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  bool _retrying = false;
  bool _resultRefreshed = false;

  /// 채점 실패 → 서버에 다시 채점을 맡기고 결과를 다시 불러온다
  Future<void> _retryEvaluation() async {
    setState(() { _retrying = true; _resultRefreshed = false; });
    try {
      await ref
          .read(interviewRepositoryProvider)
          .retryEvaluation(widget.answerId);
      ref.invalidate(feedbackProvider(widget.answerId));
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _close() => context.go(Routes.home);

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(feedbackProvider(widget.answerId));
    final fb = async.asData?.value;
    if (fb == null) {
      final error = unwrapAppError(async.error ?? '');
      final cancelled = error is EvaluationFailed && error.status == EvaluationStatus.cancelled;
      final failed = error is EvaluationFailed && !cancelled;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppNavBar(title: '면접 피드백', onBack: _back),
        body: async.isLoading || _retrying
            ? const LoadingView()
            : ErrorView(
                error: error,
                // 피그마 1335: 채점 실패 화면
                title: cancelled ? '평가가 취소됐어요' : failed ? '일시적인 오류가 발생했어요' : null,
                description: cancelled ? '현재 질문의 자료와 답변 상태를 확인해 주세요.' : failed ? '다시 시도해 주세요' : null,
                retryLabel: failed ? '다시 시도하기' : '다시 시도',
                onRetry: failed
                    ? _retryEvaluation
                    : () => ref.invalidate(feedbackProvider(widget.answerId)),
              ),
      );
    }
    if (!_resultRefreshed) {
      _resultRefreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        invalidateProgress(ref);
        ref.invalidate(interviewQuestionProvider(fb.questionId));
      });
    }
    final questionAsync = ref.watch(interviewQuestionProvider(fb.questionId));
    final question = questionAsync.asData?.value;
    final company = question == null
        ? null
        : ref.watch(homeProvider).asData?.value.byId(question.companyId);
    final finished =
        company != null && company.interview.done >= company.interview.total;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // 복습: 버튼 뒤 흰 페이드 아래로 내용이 지나간다 (피그마 1653:10983)
        extendBody: widget.fromReview,
        body: ListView(
          padding: EdgeInsets.only(bottom: widget.fromReview ? FadedBottomCta.listPadding : 0),
          children: [
            // 피그마 1313:7930 · 1313:7717: 내비는 ‹ 뒤로 만, 복습 리포트(1653:10895)는 오른쪽 ✕ 도 있다
            FeedbackHero(feedback: fb, onBack: _back, onClose: widget.fromReview ? () => context.go(Routes.review) : null),
            FeedbackContent(feedback: fb, questionText: question?.text),
          ],
        ),
        bottomNavigationBar: widget.fromReview
            ? FadedBottomCta(
                children: [
                  RetryAnswerButton(
                    prefix: '다시 답변하기',
                    primary: true,
                    remaining: question?.retryRemaining ?? fb.retryRemaining,
                    canSubmit: question != null && !question.blocked,
                    blockedMessage: question?.blockedMessage ?? (questionAsync.hasError
                        ? '제출 가능 상태를 확인하지 못했어요. 다시 확인해 주세요.' : '제출 가능 상태를 불러오고 있어요.'),
                    blockedHelp: question?.blockedHelp ?? '잠시 후 화면을 다시 확인해 주세요.',
                    onRetry: () => context.pushReplacement(
                      Routes.interviewAnswer(fb.questionId, fromReview: true),
                    ),
                  ),
                ],
              )
            : BottomCta(
          children: [
            Row(
              children: [
                Expanded(
                  child: RetryAnswerButton(
                    prefix: '재답변',
                    remaining: question?.retryRemaining ?? fb.retryRemaining,
                    canSubmit: question != null && !question.blocked,
                    blockedMessage: question?.blockedMessage ?? (questionAsync.hasError
                        ? '제출 가능 상태를 확인하지 못했어요. 다시 확인해 주세요.' : '제출 가능 상태를 불러오고 있어요.'),
                    blockedHelp: question?.blockedHelp ?? '잠시 후 화면을 다시 확인해 주세요.',
                    onRetry: () => context.pushReplacement(
                      Routes.interviewAnswer(fb.questionId),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: AppButton(
                    label: finished || question == null ? '마무리하기' : '다음 질문',
                    onPressed: finished || question == null
                        ? _close
                        // 지난 질문 화면을 스택에서 걷어 내고 다음 질문으로 (뒤로가기로 소진 질문에 못 돌아가게)
                        : () => goNextInterviewQuestion(context, question.companyId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
