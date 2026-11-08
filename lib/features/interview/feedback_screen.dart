import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'interview_widgets.dart';

/// 피그마 최종 "면접 피드백" (1335:8520 완성답변 · 1335:8635 보완필요)
/// 진한 히어로(폴더: 배지 · 점수 % · ! 한 줄 요약 · 진행 바 · 불꽃/느낌표) + 회색 카드 목록
/// → 재답변 (남은/3) · 다음 질문 (오늘 질문을 다 했으면 마무리하기)
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, required this.answerId});

  final String answerId;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  bool _retrying = false;

  /// 채점 실패 → 서버에 다시 채점을 맡기고 결과를 다시 불러온다
  Future<void> _retryEvaluation() async {
    setState(() => _retrying = true);
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
      final failed = async.error is EvaluationFailed;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppNavBar(title: '면접 피드백', onBack: _back),
        body: async.isLoading || _retrying
            ? const LoadingView()
            : ErrorView(
                error: async.error ?? '',
                // 피그마 1335: 채점 실패 화면
                title: failed ? '일시적인 오류가 발생했어요' : null,
                description: failed ? '다시 시도해 주세요' : null,
                retryLabel: failed ? '다시 시도하기' : '다시 시도',
                onRetry: failed
                    ? _retryEvaluation
                    : () => ref.invalidate(feedbackProvider(widget.answerId)),
              ),
      );
    }
    final question = ref
        .watch(interviewQuestionProvider(fb.questionId))
        .asData
        ?.value;
    final company = question == null
        ? null
        : ref.watch(homeProvider).asData?.value.byId(question.companyId);
    final finished =
        company != null && company.interview.done >= company.interview.total;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            FeedbackHero(feedback: fb, onBack: _back, onClose: _close),
            FeedbackContent(feedback: fb, questionText: question?.text),
          ],
        ),
        bottomNavigationBar: BottomCta(
          children: [
            Row(
              children: [
                Expanded(
                  child: RetryAnswerButton(
                    prefix: '재답변',
                    remaining: fb.retryRemaining,
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
                        : () => context.pushReplacement(
                            Routes.todayInterview(question.companyId),
                          ),
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
