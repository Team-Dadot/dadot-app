import 'package:flutter/material.dart';

import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/pickers.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

enum ChoiceState { idle, selected, correct, myWrong }

/// 객관식 보기 한 줄 — 피그마 최종 3-1: 높이 64, 모서리 16.
/// 고른 보기는 차콜 2px 테두리 + 라임 체크, 나머지는 #C5C5C5 1px 테두리 + 빈 원.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.index, required this.text, required this.state, this.onTap});

  final int index;
  final String text;
  final ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final filled = state == ChoiceState.selected || state == ChoiceState.correct;
    final letter = index < _letters.length ? _letters[index] : '${index + 1}';
    final trailing = switch (state) {
      ChoiceState.correct => '정답',
      ChoiceState.myWrong => '내 답',
      _ => null,
    };
    final radius = BorderRadius.circular(AppRadius.button);
    return Semantics(
      button: onTap != null,
      selected: state == ChoiceState.selected,
      label: '$letter. $text${trailing == null ? '' : ', $trailing'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: filled
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide(color: state == ChoiceState.myWrong ? AppColors.accent : AppColors.borderLight),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.choiceHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: AppTypography.subheading.copyWith(color: filled ? AppColors.primary : AppColors.textSub, height: 1.45),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (trailing != null) ...[
                    Text(
                      trailing,
                      style: AppTypography.captionStrong.copyWith(
                        color: state == ChoiceState.correct ? AppColors.textPrimary : AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  CheckMark(checked: filled),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 문제 머리: 첫 줄 "Q1." (Zalando Sans) + 문제 26 Bold. 주관식이면 위에 작은 태그.
class QuizPrompt extends StatelessWidget {
  const QuizPrompt({super.key, required this.question, this.number});

  final QuizQuestion question;

  /// 문제 번호 (1부터). 주면 "Q1." 을 붙인다.
  final int? number;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.kind != QuizKind.choice) ...[
          TagChip(question.kind.label),
          const SizedBox(height: AppSpacing.sm),
        ],
        Semantics(
          header: true,
          label: number == null ? question.prompt : '$number번. ${question.prompt}',
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              style: AppTypography.title3,
              children: [
                if (number != null) ...[
                  TextSpan(text: 'Q$number', style: AppTypography.number(26, weight: FontWeight.w700, height: 1.45)),
                  TextSpan(text: '.\n', style: AppTypography.title3.copyWith(color: AppColors.ink)),
                ],
                TextSpan(text: question.prompt),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 보기 목록 또는 주관식 입력 + 채점 후 해설
class QuizAnswerArea extends StatelessWidget {
  const QuizAnswerArea({
    super.key,
    required this.question,
    required this.selectedChoiceId,
    required this.onSelect,
    required this.shortController,
    required this.result,
    this.onShortChanged,
  });

  final QuizQuestion question;
  final String? selectedChoiceId;
  final ValueChanged<String> onSelect;
  final TextEditingController shortController;
  final QuizAnswerResult? result;
  final ValueChanged<String>? onShortChanged;

  ChoiceState _state(QuizChoice c) {
    final r = result;
    if (r == null) return c.id == selectedChoiceId ? ChoiceState.selected : ChoiceState.idle;
    if (c.id == r.correctChoiceId) return ChoiceState.correct;
    if (c.id == r.answer) return ChoiceState.myWrong;
    return ChoiceState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question.kind == QuizKind.choice)
          for (var i = 0; i < question.choices.length; i++) ...[
            ChoiceTile(
              index: i,
              text: question.choices[i].text,
              state: _state(question.choices[i]),
              onTap: r == null ? () => onSelect(question.choices[i].id) : null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ]
        else ...[
          AppTextField(
            controller: shortController,
            hint: question.placeholder ?? '답을 적어 주세요.',
            minLines: 5,
            maxLines: 8,
            readOnly: r != null,
            onChanged: onShortChanged,
            textStyle: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (r == null) Text('핵심 키워드가 들어가면 정답으로 인정돼요.', style: AppTypography.caption),
        ],
        if (r != null) QuizExplanation(question: question, result: r),
      ],
    );
  }
}

/// 해설 박스 (정답이에요! / 근거 ›)
class QuizExplanation extends StatelessWidget {
  const QuizExplanation({super.key, required this.question, required this.result});

  final QuizQuestion question;
  final QuizAnswerResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final correctIndex = question.choices.indexWhere((c) => c.id == r.correctChoiceId);
    final headline = r.correct
        ? '정답이에요!'
        : question.kind == QuizKind.choice && correctIndex >= 0
            ? '아쉬워요. 정답은 ${_letters[correctIndex]}예요.'
            : '아쉬워요. 이렇게 답할 수 있어요.';
    final ev = r.evidence ?? question.evidence;
    return Semantics(
      liveRegion: true,
      child: InfoBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: AppTypography.subheading),
            if (!r.correct && question.kind == QuizKind.short && r.modelAnswer != null) ...[
              const SizedBox(height: 6),
              Text('예시 답: ${r.modelAnswer}', style: AppTypography.body2Strong),
            ],
            const SizedBox(height: 6),
            Text(r.explanation, style: AppTypography.body2),
            if (ev != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => showEvidenceSheet(context, evidence: ev, questionId: question.id),
                child: Text(
                  '근거: ${ev.title}${ev.publishedAt == null ? '' : ' · 공시일 ${ev.publishedAt}'}  ›',
                  style: AppTypography.captionMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
