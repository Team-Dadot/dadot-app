import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'interview_widgets.dart';

/// 4-1 답변 피드백: 점수 · 이번에 제출한 답변 · 4개 항목 평가 · 답변을 돌아보면 · 연결해볼 만한 내 경험
/// → 다시 답변하기 (2/3) / 마무리하기
class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key, required this.answerId});

  final String answerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(feedbackProvider(answerId));
    final fb = f.asData?.value;
    final question = fb == null ? null : ref.watch(interviewQuestionProvider(fb.questionId)).asData?.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '답변 피드백'),
      body: f.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(feedbackProvider(answerId))),
        data: (f) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
          children: [FeedbackContent(feedback: f, questionText: question?.text)],
        ),
      ),
      bottomNavigationBar: fb == null
          ? null
          : BottomCta(children: [
              AppButton(
                label: retryLabel(fb, prefix: '다시 답변하기'),
                onPressed: fb.retryRemaining > 0 ? () => context.pushReplacement(Routes.interviewAnswer(fb.questionId)) : null,
              ),
              AppButton(label: '마무리하기', variant: AppButtonVariant.secondary, onPressed: () => context.go(Routes.home)),
            ]),
    );
  }
}

/// "다시 답변하기 (2/3)" — 다음 시도 번호 / 하루 최대 시도. 더 못 하면 안내 문구.
String retryLabel(AnswerFeedback f, {required String prefix}) {
  if (f.retryRemaining <= 0) return '오늘은 이 질문에 모두 답했어요';
  final max = f.attempt + f.retryRemaining;
  return '$prefix (${f.attempt + 1}/${max < AppPolicy.retryPerQuestionDaily ? AppPolicy.retryPerQuestionDaily : max})';
}
