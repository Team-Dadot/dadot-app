import 'package:flutter/material.dart';

import '../../core/config/app_policy.dart';
import '../../data/models/interview.dart';
import '../../data/models/quiz.dart' show Evidence;
import '../../design_system/design_system.dart';
import '../common/format.dart';

/// 화면 위 질문 (피그마 4-2 · 4-3: 카드 없이 20 SemiBold)
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.question});

  final InterviewQuestion question;

  @override
  Widget build(BuildContext context) => QuestionTitle(question.text);
}

/// 질문 글자 (피그마 최종 24 Bold, 줄 높이 1.45)
class QuestionTitle extends StatelessWidget {
  const QuestionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text, style: AppTypography.title1.copyWith(color: const Color(0xFF212121), height: 1.45)),
      );
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TagChip(feedback.status.label, tone: feedback.metCount >= AppPolicy.completeMetCount ? TagTone.info : TagTone.accent),
          ),
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
          QuestionTitle(questionText!),
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
        OutlinedBox(padding: const EdgeInsets.all(AppSpacing.lg), child: CriteriaBars(criteria: f.criteria)),
        const SizedBox(height: AppSpacing.gap),
        const SectionTitle('답변을 돌아보면'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedBox(padding: const EdgeInsets.all(AppSpacing.lg), child: ReviewPoints(good: f.goodPoint, improve: f.improvement)),
        if (related != null) ...[
          const SizedBox(height: AppSpacing.gap),
          const SectionTitle('연결해볼 만한 내 경험'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedBox(
            padding: const EdgeInsets.all(AppSpacing.lg),
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


/// 피그마 최종 4-2 "답변에 활용할 정보" 카드: 라임 폴더 탭 + 라임 제목 칸 + 진한 몸통(공시일 · 대상 기간 · 내용)
class EvidenceFolderCard extends StatelessWidget {
  const EvidenceFolderCard({super.key, required this.evidence, this.showTab = true});

  final Evidence evidence;

  /// 근거가 여러 개면 첫 카드만 탭을 단다
  final bool showTab;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (evidence.publishedAt != null) '공시일 ㅣ ${evidence.publishedAt}',
      if (evidence.period != null) '대상 기간 ㅣ ${evidence.period}',
    ];
    final title = Text(evidence.title, style: AppTypography.title4.copyWith(color: const Color(0xFF212121)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTab)
          FolderCard(
            color: AppColors.point,
            tabWidth: 148,
            tabHeight: 39,
            curveWidth: 51,
            radius: AppRadius.lg,
            bottomRadius: 0,
            bodyPadding: const EdgeInsets.all(AppSpacing.lg),
            tab: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '답변에 활용할 정보',
                style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: const Color(0xFF6E7D14)),
              ),
            ),
            child: title,
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.point,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            child: title,
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          decoration: const BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta.isNotEmpty) ...[
                for (final m in meta) Text(m, style: AppTypography.body2.copyWith(color: const Color(0xFFF9F9F9), height: 1.4)),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                evidence.excerpt,
                style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.white, height: 1.8),
              ),
              if (evidence.interpretation != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('해석 · ${evidence.interpretation}', style: AppTypography.body2.copyWith(color: const Color(0xFFB9B9BC))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
