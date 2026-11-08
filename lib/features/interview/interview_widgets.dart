import 'package:flutter/material.dart';

import '../../core/config/app_policy.dart';
import '../../data/models/interview.dart';
import '../../data/models/quiz.dart' show Evidence;
import '../../design_system/design_system.dart';
import '../common/result_hero.dart';

export '../common/result_hero.dart' show ResultTone;

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
    child: Text(
      text,
      style: AppTypography.title1.copyWith(
        color: const Color(0xFF212121),
        height: 1.45,
      ),
    ),
  );
}

/// 피드백 화면 한 줄 요약 (가장 낮은 항목 기준). 서버가 요약을 주면 그걸 쓴다.
String feedbackHeadline(AnswerFeedback f) {
  final summary = f.summary?.trim();
  if (summary != null && summary.isNotEmpty) return summary;
  if (f.metCount >= AppPolicy.completeMetCount) return '조건을 모두 만족한 좋은 답변이에요';
  if (f.criteria.isEmpty) return '답변을 조금 더 다듬어 보세요.';
  final weakest = f.criteria.reduce(
    (a, b) =>
        (a.max == 0 ? 0 : a.score / a.max) <= (b.max == 0 ? 0 : b.score / b.max)
        ? a
        : b,
  );
  return switch (weakest.key) {
    CriterionKey.responsiveness => '질문에 더 직접적으로 답해 주세요.',
    CriterionKey.companyInfo => '기업 정보를 더 활용해 말해주세요.',
    CriterionKey.specificity => '경험을 더 구체적으로 말해주세요.',
    CriterionKey.logic => '답변 구조를 더 짜임새 있게 다듬어 주세요.',
    CriterionKey.clarity => '핵심을 더 분명하게 전달해 주세요.',
  };
}

/// 피드백 히어로 (피그마 1335:8520 · 1335:8635): 완성이면 라임 "완성답변", 아니면 주황 "보완필요"
ResultTone feedbackTone(AnswerFeedback f) =>
    f.metCount >= AppPolicy.completeMetCount
    ? ResultTone.pass
    : ResultTone.fail;

class FeedbackHero extends StatelessWidget {
  const FeedbackHero({
    super.key,
    required this.feedback,
    this.onBack,
    this.onClose,
  });

  final AnswerFeedback feedback;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final f = feedback;
    final tone = feedbackTone(f);
    return ResultHero(
      tone: tone,
      navTitle: '면접 피드백',
      badge: tone == ResultTone.pass ? '완성답변' : '보완필요',
      semanticLabel: '${f.status.label}, 100점 중 ${f.score}점',
      title: Text(
        '${f.score}%',
        style: AppTypography.number(
          38,
          color: ResultHero.textColor(tone),
        ).copyWith(letterSpacing: -1.9),
      ),
      description: ResultAlertLine(tone: tone, text: feedbackHeadline(f)),
      progress: f.score / 100,
      onBack: onBack,
      onClose: onClose,
    );
  }
}

/// 답변 피드백 카드 목록 (회색 바탕, 좌우 20 · 위 28). 4-1 면접 피드백 · 5-2 면접 복습이 같이 쓴다.
/// 나의 답변(Q. 질문 칸 + 답변 + 더보기) · 평가 항목 · 답변 돌아보기 · 연결할 경험
class FeedbackContent extends StatelessWidget {
  const FeedbackContent({
    super.key,
    required this.feedback,
    this.questionText,
    this.attemptPicker,
    this.onDeleteAttempt,
  });

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        28,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attemptPicker != null) ...[
            attemptPicker!,
            const SizedBox(height: AppSpacing.md),
          ],
          _FeedbackCard(
            icon: 'fb_answer.png',
            iconSize: const Size(20, 20),
            title: '나의 답변',
            child: _MyAnswer(
              feedback: f,
              questionText: questionText,
              onDelete: onDeleteAttempt,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FeedbackCard(
            icon: 'fb_criteria.png',
            iconSize: const Size(24, 24),
            title: '평가 항목',
            child: CriteriaList(criteria: f.criteria),
          ),
          const SizedBox(height: AppSpacing.md),
          _FeedbackCard(
            icon: 'fb_review.png',
            iconSize: const Size(17.5, 18),
            title: '답변 돌아보기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Point(title: '잘한 점', body: f.goodPoint),
                const SizedBox(height: 20),
                _Point(title: '보완할 점', body: f.improvement),
              ],
            ),
          ),
          if (related != null) ...[
            const SizedBox(height: AppSpacing.md),
            _FeedbackCard(
              icon: 'fb_experience.png',
              iconSize: const Size(18.5, 16.5),
              title: '연결할 경험',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Point(title: related.title, body: related.content, gap: 4),
                  const SizedBox(height: 20),
                  _Point(title: '어떻게 활용할 수 있을까?', body: related.tip),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 흰 카드 (테두리 #E3E5EE, r16, 안쪽 24): 아이콘 + 제목 18 SemiBold, 아래 24 에 내용
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.child,
  });

  /// assets/images/icons/ 안 피그마 투톤 아이콘 (라임 + 남색)
  final String icon;
  final Size iconSize;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      radius: AppRadius.button,
      borderColor: AppColors.cardLine,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: Image.asset(
                    'assets/images/icons/$icon',
                    width: iconSize.width,
                    height: iconSize.height,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTypography.heading.copyWith(
                    fontSize: 18,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

/// ● 소제목 16 SemiBold + 본문 16 (줄 높이 1.6)
class _Point extends StatelessWidget {
  const _Point({
    required this.title,
    required this.body,
    this.gap = AppSpacing.xs,
  });

  final String title;
  final String body;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 10, right: AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.textStrong,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.textStrong,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Text(
          body,
          style: AppTypography.subheading.copyWith(
            fontWeight: AppTypography.regular,
            color: AppColors.textSub,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// 나의 답변: 회색 "Q. 질문" 칸 · 답변 2줄 · "더보기 ⌄" 로 펼친다. 복습에서는 지난 시도 삭제도.
class _MyAnswer extends StatefulWidget {
  const _MyAnswer({required this.feedback, this.questionText, this.onDelete});

  final AnswerFeedback feedback;
  final String? questionText;
  final VoidCallback? onDelete;

  @override
  State<_MyAnswer> createState() => _MyAnswerState();
}

class _MyAnswerState extends State<_MyAnswer> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final q = widget.questionText;
    final guide = AppTypography.caption.copyWith(
      fontSize: 13,
      fontWeight: AppTypography.regular,
      color: AppColors.textGuide,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (q != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Semantics(
              header: true,
              child: Text(
                'Q. $q',
                textAlign: TextAlign.center,
                style: AppTypography.body2Strong.copyWith(
                  color: AppColors.textSub,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          f.content,
          maxLines: _open ? null : 2,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTypography.subheading.copyWith(
            fontWeight: AppTypography.regular,
            color: AppColors.textSub,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (widget.onDelete != null)
              TextLink(label: '이 답변 삭제', style: guide, onTap: widget.onDelete!),
            const Spacer(),
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_open ? '접기' : '더보기', style: guide),
                    Icon(
                      _open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textGuide,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 평가 항목: 이름 · 막대(120) · 16/25. 가장 낮은 항목 막대는 검정, 나머지는 라임.
class CriteriaList extends StatelessWidget {
  const CriteriaList({super.key, required this.criteria});

  final List<CriterionScore> criteria;

  @override
  Widget build(BuildContext context) {
    double ratio(CriterionScore c) =>
        c.max == 0 ? 0 : (c.score / c.max).clamp(0.0, 1.0);
    final lowest = criteria.isEmpty
        ? null
        : criteria.reduce((a, b) => ratio(a) <= ratio(b) ? a : b);
    final allSame = criteria.every((c) => ratio(c) == ratio(criteria.first));
    final text = AppTypography.subheading.copyWith(
      fontWeight: AppTypography.medium,
      color: AppColors.textSub,
      height: 1.6,
    );
    return Column(
      children: [
        for (var i = 0; i < criteria.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          Semantics(
            label:
                '${criteria[i].key.label} ${criteria[i].max}점 중 ${criteria[i].score}점',
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(child: Text(criteria[i].key.label, style: text)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    width: 120,
                    height: AppSizes.scoreBarHeight,
                    color: AppColors.barTrack,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio(criteria[i]),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: !allSame && identical(criteria[i], lowest)
                              ? Colors.black
                              : AppColors.point,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${criteria[i].score}/${criteria[i].max}',
                    textAlign: TextAlign.right,
                    style: text.copyWith(fontWeight: AppTypography.regular),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 피그마 최종 4-2 "답변에 활용할 정보" 카드: 라임 폴더 탭 + 라임 제목 칸 + 진한 몸통(공시일 · 대상 기간 · 내용)
class EvidenceFolderCard extends StatelessWidget {
  const EvidenceFolderCard({
    super.key,
    required this.evidence,
    this.showTab = true,
  });

  final Evidence evidence;

  /// 근거가 여러 개면 첫 카드만 탭을 단다
  final bool showTab;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (evidence.publishedAt != null) '공시일 ㅣ ${evidence.publishedAt}',
      if (evidence.period != null) '대상 기간 ㅣ ${evidence.period}',
    ];
    final title = Text(
      evidence.title,
      style: AppTypography.title4.copyWith(color: const Color(0xFF212121)),
    );
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
                style: AppTypography.subheading.copyWith(
                  fontWeight: AppTypography.medium,
                  color: const Color(0xFF6E7D14),
                ),
              ),
            ),
            child: title,
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.point,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: title,
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          decoration: const BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta.isNotEmpty) ...[
                for (final m in meta)
                  Text(
                    m,
                    style: AppTypography.body2.copyWith(
                      color: const Color(0xFFF9F9F9),
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                evidence.excerpt,
                style: AppTypography.subheading.copyWith(
                  fontWeight: AppTypography.medium,
                  color: AppColors.white,
                  height: 1.8,
                ),
              ),
              if (evidence.interpretation != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '해석 · ${evidence.interpretation}',
                  style: AppTypography.body2.copyWith(
                    color: const Color(0xFFB9B9BC),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "재답변 (2/3)" 회색 버튼 (남은 기회 / 하루 최대). 기회가 0 이면 더 흐리게 보이고,
/// 눌러도 다시 답하지 않고 "답변 기회가 모두 소진되었어요" 안내만 띄운다 (피그마 1335:8520).
class RetryAnswerButton extends StatelessWidget {
  const RetryAnswerButton({
    super.key,
    required this.prefix,
    required this.remaining,
    required this.onRetry,
  });

  final String prefix;
  final int remaining;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final left = remaining.clamp(0, AppPolicy.retryPerQuestionDaily);
    final out = left <= 0;
    final label = '$prefix ($left/${AppPolicy.retryPerQuestionDaily})';
    return Semantics(
      button: true,
      label: out ? '$label, 오늘 답변 기회를 모두 썼어요' : label,
      excludeSemantics: true,
      child: Material(
        color: out ? const Color(0xFFE9EBED) : AppColors.fillMuted,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          splashFactory: NoSplash.splashFactory,
          onTap: out
              ? () => showNoticeDialog(
                  context,
                  title: '답변 기회가 모두 소진되었어요',
                  message: '내일 다시 도전해보세요!',
                  buttonLabel: '확인',
                )
              : onRetry,
          child: SizedBox(
            height: AppSizes.buttonHeight,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.button.copyWith(
                    color: out ? AppColors.textGuide : AppColors.textSub,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
