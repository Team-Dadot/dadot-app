import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../quiz/quiz_widgets.dart';

/// 퀴즈 복습 "이 문제 다시 풀기"
class QuizRetryScreen extends ConsumerStatefulWidget {
  const QuizRetryScreen({super.key, required this.itemId, required this.companyId});

  final String itemId;
  final String companyId;

  @override
  ConsumerState<QuizRetryScreen> createState() => _QuizRetryScreenState();
}

class _QuizRetryScreenState extends ConsumerState<QuizRetryScreen> {
  String? _selected;
  final _short = TextEditingController();
  QuizAnswerResult? _result;
  bool _submitting = false;

  @override
  void dispose() {
    _short.dispose();
    super.dispose();
  }

  String? _answer(QuizQuestion q) => q.kind == QuizKind.choice ? _selected : (_short.text.trim().isEmpty ? null : _short.text.trim());

  Future<void> _submit(QuizQuestion q) async {
    final answer = _answer(q);
    if (answer == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final r = await ref.read(recordsRepositoryProvider).retryQuiz(itemId: widget.itemId, answer: answer);
      invalidateProgress(ref);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(quizReviewProvider(widget.companyId));
    final item = items.asData?.value.where((i) => i.id == widget.itemId).firstOrNull;
    final q = item?.question;

    Widget body;
    if (items.hasError) {
      body = ErrorView(error: items.error!, onRetry: () => ref.invalidate(quizReviewProvider(widget.companyId)));
    } else if (items.isLoading && q == null) {
      body = const LoadingView();
    } else if (q == null) {
      body = const EmptyView(title: '문제를 찾지 못했어요', description: '복습 목록에서 다시 골라 주세요.');
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 28, AppSpacing.screenH, AppSpacing.xl),
        children: [
          QuizPrompt(question: q),
          const SizedBox(height: 39),
          QuizAnswerArea(
            question: q,
            selectedChoiceId: _selected,
            onSelect: (id) => setState(() => _selected = id),
            shortController: _short,
            onShortChanged: (_) => setState(() {}),
            result: _result,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '다시 풀기', divider: true),
      body: body,
      bottomNavigationBar: q == null
          ? null
          : BottomCta(children: [
              if (_result == null)
                AppButton(label: '답 제출하기', loading: _submitting, onPressed: _answer(q) == null ? null : () => _submit(q))
              else
                AppButton(label: '복습으로 돌아가기', onPressed: () => context.pop()),
            ]),
    );
  }
}
