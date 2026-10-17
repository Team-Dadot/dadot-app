import 'package:flutter/material.dart';

import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/pickers.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

enum ChoiceState { idle, selected, correct, myWrong }

/// 객관식 보기 한 줄 (A 크게 줄었다)
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.index, required this.text, required this.state, this.onTap});

  final int index;
  final String text;
  final ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strong = state == ChoiceState.selected || state == ChoiceState.correct;
    final letter = index < _letters.length ? _letters[index] : '${index + 1}';
    final trailing = switch (state) {
      ChoiceState.correct => '정답',
      ChoiceState.myWrong => '내 답',
      _ => null,
    };
    return Semantics(
      button: onTap != null,
      selected: state == ChoiceState.selected,
      label: '$letter. $text${trailing == null ? '' : ', $trailing'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(strong ? AppSpacing.card - 1 : AppSpacing.card),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: strong ? AppColors.primary : AppColors.borderLight, width: strong ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.indexBox,
                height: AppSizes.indexBox,
                alignment: Alignment.center,
                color: strong ? AppColors.primary : AppColors.fillChoice,
                child: Text(letter, style: AppTypography.body2Strong.copyWith(color: strong ? AppColors.white : AppColors.textBody)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: strong ? AppTypography.body1Strong : AppTypography.body1)),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  trailing,
                  style: AppTypography.captionStrong.copyWith(
                    color: state == ChoiceState.correct ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 문제 머리: 태그 + 문제 (20 Bold)
class QuizPrompt extends StatelessWidget {
  const QuizPrompt({super.key, required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TagRow([question.kind.label, ...question.tags]),
        const SizedBox(height: AppSpacing.sm),
        Semantics(header: true, child: Text(question.prompt, style: AppTypography.title3)),
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
            textStyle: AppTypography.body1,
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
