import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'interview_widgets.dart';

/// 피그마 최종 "결과 확인" (1015:13833): 점수 게이지 · 요약 · 질문 · 면접 피드백 카드
/// → 다음 질문으로 / 다시 답변하기 (2/3)
class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key, required this.answerId});

  final String answerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(feedbackProvider(answerId));
    final fb = f.asData?.value;
    final question = fb == null ? null : ref.watch(interviewQuestionProvider(fb.questionId)).asData?.value;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppNavBar(title: '결과 확인', color: AppColors.surface),
      body: f.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(feedbackProvider(answerId))),
        data: (f) => ListView(children: [FeedbackContent(feedback: f, questionText: question?.text)]),
      ),
      bottomNavigationBar: fb == null
          ? null
          : BottomCta(children: [
              // 다음 질문: 오늘 아직 답하지 않은 질문으로 (다 답했으면 "모두 답했어요" 안내)
              AppButton(
                label: '다음 질문으로',
                onPressed: question == null
                    ? () => context.go(Routes.home)
                    : () => context.pushReplacement(Routes.todayInterview(question.companyId)),
              ),
              AppButton(
                label: retryLabel(fb, prefix: '다시 답변하기'),
                variant: AppButtonVariant.secondary,
                onPressed: fb.retryRemaining > 0 ? () => context.pushReplacement(Routes.interviewAnswer(fb.questionId)) : null,
              ),
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
