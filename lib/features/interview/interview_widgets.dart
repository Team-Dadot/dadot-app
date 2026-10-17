import 'package:flutter/material.dart';

import '../../core/config/app_policy.dart';
import '../../data/models/interview.dart';
import '../../design_system/design_system.dart';
import '../common/format.dart';

/// 질문 카드: [기아] [마케팅] + 질문 (18 Bold)
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.question});

  final InterviewQuestion question;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.tags.isNotEmpty) ...[TagRow(question.tags), const SizedBox(height: AppSpacing.sm)],
          Semantics(header: true, child: Text(question.text, style: AppTypography.title4)),
        ],
      ),
    );
  }
}

/// "기준 2/5 충족 · 3개 이상이면 완성"
String criteriaLine(int metCount, int total) => '기준 $metCount/$total 충족 · ${AppPolicy.completeMetCount}개 이상이면 완성';

/// 점수 카드 (4-6): 상태 태그 + 76 / 100 + 기준 충족
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.feedback});

  final AnswerFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      borderColor: AppColors.borderLight,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: TagChip(feedback.status.label)),
          const SizedBox(height: AppSpacing.xs),
          Text('${feedback.score} / 100', textAlign: TextAlign.center, style: AppTypography.score),
          const SizedBox(height: AppSpacing.xs),
          Text(
            criteriaLine(feedback.metCount, feedback.criteria.length),
            textAlign: TextAlign.center,
            style: AppTypography.body2Medium.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}

/// 5개 항목 막대
class CriteriaBars extends StatelessWidget {
  const CriteriaBars({super.key, required this.criteria, this.compact = false});

  final List<CriterionScore> criteria;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < criteria.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ScoreBar(label: criteria[i].key.label, score: criteria[i].score, max: criteria[i].max, compact: compact),
        ],
      ],
    );
  }
}

/// 잘한 점 / 보완점
class ReviewPoints extends StatelessWidget {
  const ReviewPoints({super.key, required this.good, required this.improve});

  final String good;
  final String improve;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('잘한 점', style: AppTypography.body2Strong),
        const SizedBox(height: AppSpacing.xs),
        Text(good, style: AppTypography.body2),
        const SizedBox(height: AppSpacing.xs),
        const LineDivider(),
        const SizedBox(height: AppSpacing.xs),
        Text('보완점', style: AppTypography.body2Strong),
        const SizedBox(height: AppSpacing.xs),
        Text(improve, style: AppTypography.body2),
      ],
    );
  }
}

/// 답변 피드백 본문 (4-1 답변 피드백 · 5-2 면접 복습의 답변 피드백이 같이 쓴다)
/// 질문 → 점수 카드 → 이번에 제출한 답변 → 4개 항목 평가 → 답변을 돌아보면 → 연결해볼 만한 내 경험
class FeedbackContent extends StatelessWidget {
  const FeedbackContent({super.key, required this.feedback, this.questionText, this.attemptPicker, this.onDeleteAttempt});

  final AnswerFeedback feedback;
  final String? questionText;

  /// 시도가 여러 번이면 "시도 1 · 시도 2" 고르기 (복습에서만)
  final Widget? attemptPicker;

  /// 이 시도 지우기 (복습에서만)
  final VoidCallback? onDeleteAttempt;

  @override
  Widget build(BuildContext context) {
    final f = feedback;
    final related = f.relatedExperience;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (questionText != null) ...[
          Semantics(header: true, child: Text(questionText!, style: AppTypography.title4)),
          const SizedBox(height: AppSpacing.gap),
        ],
        if (attemptPicker != null) ...[attemptPicker!, const SizedBox(height: AppSpacing.sm)],
        ScoreCard(feedback: f),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('이번에 제출한 답변'),
        const SizedBox(height: AppSpacing.sm),
        SubmittedAnswerBox(feedback: f, onDelete: onDeleteAttempt),
        const SizedBox(height: AppSpacing.gap),
        SectionTitle('${f.criteria.length}개 항목 평가'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedBox(borderColor: AppColors.borderLight, child: CriteriaBars(criteria: f.criteria)),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('답변을 돌아보면'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedBox(borderColor: AppColors.borderLight, child: ReviewPoints(good: f.goodPoint, improve: f.improvement)),
        if (related != null) ...[
          const SizedBox(height: AppSpacing.gap),
          const SectionTitle('연결해볼 만한 내 경험'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedBox(
            borderColor: AppColors.borderLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('‘${related.title}’', style: AppTypography.body1Strong),
                const SizedBox(height: 6),
                Text(related.content, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(related.tip, style: AppTypography.captionMedium.copyWith(color: AppColors.textBody)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "이번에 제출한 답변" 상자: 3줄까지 보이고 "답변 보기" 로 펼친다
class SubmittedAnswerBox extends StatefulWidget {
  const SubmittedAnswerBox({super.key, required this.feedback, this.onDelete});

  final AnswerFeedback feedback;
  final VoidCallback? onDelete;

  @override
  State<SubmittedAnswerBox> createState() => _SubmittedAnswerBoxState();
}

class _SubmittedAnswerBoxState extends State<SubmittedAnswerBox> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    return InfoBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            f.content,
            maxLines: _open ? null : 3,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTypography.body2,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text('${formatShortTime(f.submittedAt)} · 시도 ${f.attempt}', style: AppTypography.micro.copyWith(color: AppColors.textHint)),
              ),
              if (widget.onDelete != null) ...[
                TextLink(label: '삭제', style: AppTypography.captionMedium, onTap: widget.onDelete!),
                const SizedBox(width: AppSpacing.sm),
              ],
              TextLink(
                label: _open ? '접기' : '답변 보기',
                style: AppTypography.captionMedium.copyWith(color: AppColors.textPrimary),
                onTap: () => setState(() => _open = !_open),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
