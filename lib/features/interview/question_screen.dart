import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/pickers.dart';
import 'interview_widgets.dart';

/// 4-1 면접 질문 · 답변에 활용할 정보 → 음성으로 답변하기 / 답변하기
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
          children: [
            QuestionCard(question: q),
            if (q.evidence.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const SectionTitle('답변에 활용할 정보'),
              const SizedBox(height: AppSpacing.sm),
              for (final e in q.evidence) ...[EvidenceCard(evidence: e), const SizedBox(height: AppSpacing.sm)],
            ],
          ],
        ),
      ),
      bottomNavigationBar: q.hasValue
          ? BottomCta(children: [
              AppButton(
                label: '음성으로 답변하기',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(Routes.interviewAnswer(questionId, voice: true)),
              ),
              AppButton(label: '답변하기  →', onPressed: () => context.push(Routes.interviewAnswer(questionId))),
            ])
          : null,
    );
  }
}
