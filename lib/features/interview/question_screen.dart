import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'interview_widgets.dart';

/// 피그마 최종 4-2 면접 질문 · 공시 근거: 질문 24 + 라임/진한 "답변에 활용할 정보" 카드 → 답변하기
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key, required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(interviewQuestionProvider(questionId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '면접 질문'),
      body: q.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(interviewQuestionProvider(questionId))),
        data: (q) => ListView(
          // 피그마 1520:9632: 내비 아래 24 에 질문, 36 아래 근거 카드
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.xl),
          children: [
            QuestionHeadline(q.text),
            if (q.evidence.isNotEmpty) ...[
              const SizedBox(height: 36),
              for (var i = 0; i < q.evidence.length; i++) ...[
                EvidenceFolderCard(evidence: q.evidence[i], showTab: i == 0),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: switch (q.asData?.value) {
        null => null,
        // 기회를 다 쓴 질문: "답변하기" 대신 안내 + 평가 보기 (QA: 소진 질문에 다시 들어와 제출되던 문제)
        final v when v.blocked => BottomCta(children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                v.blockedMessage,
                textAlign: TextAlign.center,
                style: AppTypography.body2Medium.copyWith(color: AppColors.textGuide),
              ),
            ),
            // QA(1435:12791): 기회를 다 쓴 질문은 "평가 보기" 만 (지난 답변이 없으면 다음 질문으로)
            if (v.latestAnswerId != null)
              AppButton(label: '평가 보기', onPressed: () => context.push(Routes.feedback(v.latestAnswerId!)))
            else
              AppButton(label: '다음 질문', onPressed: () => goNextInterviewQuestion(context, v.companyId)),
          ]),
        _ => BottomCta(children: [
            AppButton(label: '답변하기', onPressed: () => context.push(Routes.interviewAnswer(questionId))),
          ]),
      },
    );
  }
}
