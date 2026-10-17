import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/pickers.dart';

/// 3-1 오늘의 퀴즈 결과: 맞힌 수 · 누적 정답률 변화 · 문제별 해설(펼치기) · 공시 근거 시트
class QuizResultScreen extends ConsumerStatefulWidget {
  const QuizResultScreen({super.key, required this.setId});

  final String setId;

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  /// 펼친 문항 (처음엔 첫 문항만 펼친다)
  String? _open;
  bool _initialized = false;

  void _retryWrong(QuizResult r) {
    ref.read(selectedCompanyIdProvider.notifier).select(r.companyId);
    context.go(Routes.reviewTab('quiz'));
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(quizResultProvider(widget.setId));
    final r = result.asData?.value;
    if (r != null && !_initialized) {
      _initialized = true;
      _open = r.items.firstOrNull?.questionId;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppNavBar(title: '퀴즈 결과', onBack: () => context.go(Routes.home)),
      body: result.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(quizResultProvider(widget.setId))),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.xl),
          children: [
            const Center(child: LogoBox(size: AppSizes.logo, label: '결과')),
            const SizedBox(height: AppSpacing.gap),
            Text('${r.total}문제 중 ${r.correctCount}개 맞혔어요', textAlign: TextAlign.center, style: AppTypography.title2),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              r.accuracyBefore == null
                  ? '${r.companyName} 누적 정답률 ${r.accuracyAfter ?? 0}%'
                  : '${r.companyName} 누적 정답률 ${r.accuracyBefore}% → ${r.accuracyAfter}%',
              textAlign: TextAlign.center,
              style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('문제별 해설'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedBox(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < r.items.length; i++) ...[
                    if (i > 0) const LineDivider(),
                    _ResultItem(
                      number: i + 1,
                      item: r.items[i],
                      open: _open == r.items[i].questionId,
                      onToggle: () => setState(() => _open = _open == r.items[i].questionId ? null : r.items[i].questionId),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: r == null
          ? null
          : BottomCta(children: [
              AppButton(label: '오늘의 면접 이어서 하기  →', onPressed: () => context.pushReplacement(Routes.todayInterview(r.companyId))),
              if (r.wrongCount > 0)
                AppButton(label: '오답 ${r.wrongCount}개 다시 풀기', variant: AppButtonVariant.secondary, onPressed: () => _retryWrong(r)),
            ]),
    );
  }
}

/// Q1 · 문제 제목 · 정답/오답 · ⌃⌄ — 펼치면 정답이에요! / 내 답 / 정답 / 정답 해설 / 근거 ›
class _ResultItem extends StatelessWidget {
  const _ResultItem({required this.number, required this.item, required this.open, required this.onToggle});

  final int number;
  final QuizResultItem item;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ev = item.evidence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: 'Q$number ${item.title}, ${item.correct ? '정답' : '오답'}, 해설 ${open ? '접기' : '펼치기'}',
          excludeSemantics: true,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.card),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('Q$number', style: AppTypography.body2Strong)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(item.title, style: AppTypography.body1)),
                  const SizedBox(width: AppSpacing.xs),
                  TagChip(item.correct ? '정답' : '오답', dark: !item.correct),
                  const SizedBox(width: AppSpacing.xs),
                  Text(open ? '⌃' : '⌄', style: AppTypography.body1Strong),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: InfoBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.correct ? '정답이에요!' : '아쉬워요, 다시 확인해 봐요.', style: AppTypography.subheading),
                  if (item.myAnswer != null) ...[
                    const SizedBox(height: 6),
                    _AnswerLine(label: '내 답', value: item.myAnswer!),
                  ],
                  if (item.correctAnswer != null) ...[
                    const SizedBox(height: 2),
                    _AnswerLine(label: '정답', value: item.correctAnswer!, strong: true),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text('정답 해설', style: AppTypography.body2Strong),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.explanation, style: AppTypography.body2),
                  if (ev != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: () => showEvidenceSheet(context, evidence: ev, questionId: item.questionId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                        child: Text(
                          '근거: ${ev.title}${ev.publishedAt == null ? '' : ' · 공시일 ${ev.publishedAt}'}  ›',
                          style: AppTypography.captionMedium,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 40, child: Text(label, style: AppTypography.caption)),
        Expanded(child: Text(value, style: strong ? AppTypography.body2Strong : AppTypography.body2)),
      ],
    );
  }
}
