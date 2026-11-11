import 'package:flutter/material.dart';

import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/pickers.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

/// 보기 상태. 채점 전: [idle] · [selected]. 채점 후(다시 풀기 결과): [correct] 정답 · [myWrong] 내가 고른 오답 · [dimmed] 나머지.
enum ChoiceState { idle, selected, correct, myWrong, dimmed }

/// 객관식 보기 한 줄 — 피그마 최종 3-1: 높이 64, 모서리 16.
/// 고른 보기는 차콜 2px 테두리 + 라임 체크, 나머지는 #C5C5C5 1px 테두리 + 빈 원.
/// 채점 후 (피그마 1529:11067 · 1529:11026): 정답은 라임 2px 테두리 + "정답" 알약, 내가 고른 오답은 회색 2px 테두리 + "오답" 알약,
/// 나머지는 #BCBFC5 1px 테두리 (체크 원 없음).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.index, required this.text, required this.state, this.onTap});

  final int index;
  final String text;
  final ChoiceState state;
  final VoidCallback? onTap;

  bool get _graded => state == ChoiceState.correct || state == ChoiceState.myWrong || state == ChoiceState.dimmed;

  @override
  Widget build(BuildContext context) {
    final filled = state == ChoiceState.selected;
    final letter = index < _letters.length ? _letters[index] : '${index + 1}';
    final trailing = switch (state) {
      ChoiceState.correct => '정답',
      ChoiceState.myWrong => '오답',
      _ => null,
    };
    final radius = BorderRadius.circular(AppRadius.button);
    final side = switch (state) {
      ChoiceState.selected => const BorderSide(color: AppColors.primary, width: 2),
      ChoiceState.correct => const BorderSide(color: AppColors.point, width: 2),
      ChoiceState.myWrong => const BorderSide(color: Color(0xFFC7C7C7), width: 2),
      ChoiceState.dimmed => const BorderSide(color: Color(0xFFBCBFC5)),
      ChoiceState.idle => const BorderSide(color: AppColors.borderLight),
    };
    final strong = filled || state == ChoiceState.correct || state == ChoiceState.myWrong;
    return Semantics(
      button: onTap != null,
      selected: state == ChoiceState.selected,
      label: '$letter. $text${trailing == null ? '' : ', $trailing'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.choiceHeight),
            child: Padding(
              // 채점 후: 좌우 20 · 위아래 21 + 테두리 (높이 66 · 정답/오답 68)
              padding: _graded
                  ? EdgeInsets.symmetric(horizontal: AppSpacing.lg + side.width, vertical: 21 + side.width)
                  : const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: AppTypography.subheading.copyWith(
                        color: _graded ? (strong ? const Color(0xFF303137) : AppColors.textSub) : (filled ? AppColors.primary : AppColors.textSub),
                        height: _graded ? 1.4 : 1.45,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    // 알약 (피그마 1529:11055 정답 #F4FFB2/#5E6B0B · 1529:11061 오답 #DDD/#6C6C6C, 12 SemiBold)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: state == ChoiceState.correct ? const Color(0xFFF4FFB2) : const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        trailing,
                        style: AppTypography.captionStrong.copyWith(
                          color: state == ChoiceState.correct ? AppColors.pointText : const Color(0xFF6C6C6C),
                          height: 1.2,
                          letterSpacing: 0.07,
                        ),
                      ),
                    ),
                  ] else if (!_graded) ...[
                    const SizedBox(width: AppSpacing.sm),
                    CheckMark(checked: filled),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 문제 머리: 첫 줄 "Q1." (Zalando Sans) + 문제 26 Bold
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

/// 객관식 보기 목록 + 채점 후 해설 (퀴즈는 모두 객관식)
class QuizAnswerArea extends StatelessWidget {
  const QuizAnswerArea({
    super.key,
    required this.question,
    required this.selectedChoiceId,
    required this.onSelect,
    required this.result,
  });

  final QuizQuestion question;
  final String? selectedChoiceId;
  final ValueChanged<String> onSelect;
  final QuizAnswerResult? result;

  ChoiceState _state(QuizChoice c) {
    final r = result;
    if (r == null) return c.id == selectedChoiceId ? ChoiceState.selected : ChoiceState.idle;
    if (c.id == r.correctChoiceId) return ChoiceState.correct;
    if (c.id == r.answer) return ChoiceState.myWrong;
    return ChoiceState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < question.choices.length; i++) ...[
          ChoiceTile(
            index: i,
            text: question.choices[i].text,
            state: _state(question.choices[i]),
            onTap: r == null ? () => onSelect(question.choices[i].id) : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // 보기 목록 아래 29 에 해설 카드 (보기 사이 12 + 17)
        if (r != null) ...[
          const SizedBox(height: 17),
          QuizExplanation(question: question, result: r),
        ],
      ],
    );
  }
}

/// 해설 카드 (피그마 1529:11068 정답 · 1529:11027 오답): 바탕 #F9FBFD · 모서리 16 · 안쪽 20.
/// 👍 정답이에요! (#A5C200) / 👎 아쉽지만 틀렸어요 (검정) → "정답 : ○○" + 해설 → 선 → 공시 근거 본문 → 공시일 | 보고서 ↗
class QuizExplanation extends StatelessWidget {
  const QuizExplanation({super.key, required this.question, required this.result});

  final QuizQuestion question;
  final QuizAnswerResult result;

  static const Color _strong = Color(0xFF303137);
  static const Color _body = Color(0xFF727479);

  /// 피그마 Paragraph: 16 Regular · 줄 160% · 자간 -3%
  static TextStyle _paragraph(Color color) => AppTypography.body1.copyWith(fontSize: 16, height: 1.6, letterSpacing: -0.48, color: color);

  @override
  Widget build(BuildContext context) {
    final r = result;
    final correctText = question.choices.where((c) => c.id == r.correctChoiceId).firstOrNull?.text;
    final ev = r.evidence ?? question.evidence;
    final caption = AppTypography.caption.copyWith(fontSize: 13, height: 1.4, letterSpacing: -0.39, fontWeight: AppTypography.regular, color: AppColors.textGuide);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(color: const Color(0xFFF9FBFD), borderRadius: BorderRadius.circular(AppRadius.button)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  r.correct ? 'assets/images/icons/quiz_thumb_up.png' : 'assets/images/icons/quiz_thumb_down.png',
                  width: 22,
                  height: 22,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  r.correct ? '정답이에요!' : '아쉽지만 틀렸어요',
                  style: AppTypography.subheading.copyWith(
                    color: r.correct ? const Color(0xFFA5C200) : Colors.black,
                    height: 1.4,
                    letterSpacing: -0.48,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (correctText != null) ...[
              Text('정답 : $correctText', style: _paragraph(_strong)),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(r.explanation, style: _paragraph(_body)),
            if (ev != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: AppColors.fillMuted)),
              const SizedBox(height: AppSpacing.md),
              Text('공시 근거', style: _paragraph(_strong)),
              const SizedBox(height: AppSpacing.xs),
              if (ev.excerpt.isNotEmpty) ...[
                Text(ev.excerpt, style: _paragraph(_body)),
                const SizedBox(height: AppSpacing.xs),
              ],
              // 공시일 | 보고서 이름 ↗ (누르면 공시 근거 시트)
              Semantics(
                button: true,
                label: '공시 근거 자세히 보기, ${ev.title}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => showEvidenceSheet(context, evidence: ev, questionId: question.id),
                  child: Row(
                    children: [
                      if (ev.publishedAt != null) ...[
                        Text(ev.publishedAt!, style: caption),
                        const SizedBox(width: AppSpacing.xs),
                        const SizedBox(width: 1, height: 10, child: ColoredBox(color: AppColors.textGuide)),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Flexible(child: Text(ev.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption)),
                      const SizedBox(width: 2),
                      const Icon(Icons.north_east_rounded, size: 9, color: AppColors.textGuide),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
