import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../data/models/interview.dart';
import '../../data/models/quiz.dart' show Evidence;
import '../../core/router/app_router.dart';
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

/// 4-2 면접 질문 화면의 질문 (피그마 1520:9637): 26 Bold · 줄 140% · 자간 -3% · #15171B
class QuestionHeadline extends StatelessWidget {
  const QuestionHeadline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: AppTypography.title1.copyWith(fontSize: 26, height: 1.4, letterSpacing: -0.78, color: AppColors.ink),
    ),
  );
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
          // QA 1520:9956: 잘한 점(또는 보완할 점)이 비어 있으면 그 항목은 띄우지 않는다. 둘 다 없으면 카드도 없다.
          if (f.goodPoint.trim().isNotEmpty || f.improvement.trim().isNotEmpty)
            _FeedbackCard(
              icon: 'fb_review.png',
              iconSize: const Size(17.5, 18),
              title: '답변 돌아보기',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f.goodPoint.trim().isNotEmpty) _Point(title: '잘한 점', body: f.goodPoint),
                  if (f.goodPoint.trim().isNotEmpty && f.improvement.trim().isNotEmpty) const SizedBox(height: 20),
                  if (f.improvement.trim().isNotEmpty) _Point(title: '보완할 점', body: f.improvement),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            // 피그마는 한 줄 질문을 가운데 정렬. 실제 질문은 길 때가 많아 (QA: 6줄 가운데 정렬 문단)
            // 한 줄에 들어가면 가운데, 넘치면 왼쪽 정렬 + 2줄까지만 보이고 "더보기" 로 답변과 함께 펼친다
            child: Semantics(
              header: true,
              label: 'Q. $q',
              excludeSemantics: true,
              child: LayoutBuilder(
                builder: (context, box) {
                  final style = AppTypography.body2Strong.copyWith(color: AppColors.textSub, height: 1.4);
                  final painter = TextPainter(
                    text: TextSpan(text: 'Q. $q', style: style),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: box.maxWidth);
                  final oneLine = !painter.didExceedMaxLines;
                  return Text(
                    'Q. $q',
                    textAlign: oneLine ? TextAlign.center : TextAlign.left,
                    maxLines: _open ? null : 2,
                    overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: style,
                  );
                },
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

/// 평가 항목: 이름 · 막대(120) · 16/25.
/// 규칙(QA): 항목 점수가 10점 이하면 막대를 검정으로, 그 위는 라임으로 그린다.
/// 점수가 너무 낮아 막대가 거의 안 보이지 않게, 막대 길이는 최소 10점 분량으로 그린다 (오른쪽 숫자는 실제 점수 그대로).
class CriteriaList extends StatelessWidget {
  const CriteriaList({super.key, required this.criteria});

  /// 이 점수 이하면 검정 막대 · 막대 최소 길이 기준 점수
  static const int lowScore = 10;

  final List<CriterionScore> criteria;

  /// 막대가 채워지는 비율 (1~10점은 [lowScore] 점 분량, 0점은 막대 없음)
  static double fillRatio(CriterionScore c) {
    if (c.max <= 0 || c.score <= 0) return 0;
    final shown = c.score < lowScore ? lowScore : c.score;
    return (shown / c.max).clamp(0.0, 1.0);
  }

  /// 검정 막대 여부 (1~10점. 0점은 막대 자체를 그리지 않는다)
  static bool isLow(CriterionScore c) => c.score > 0 && c.score <= lowScore;

  @override
  Widget build(BuildContext context) {
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
                      widthFactor: fillRatio(criteria[i]),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isLow(criteria[i])
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

/// 피그마 최종 4-2 "답변에 활용할 정보" 카드: 라임 폴더 탭 + 라임 제목 칸 + 진한 몸통(내용 · 공시일 · 대상 기간)
///
/// 근거가 여러 개여도 카드는 하나다 (피그마 1520:11296 "공시 근거 2개일 경우"):
/// 같은 진한 몸통 안에 내용을 16 간격 · #404147 1px 선으로 나눠 쌓고, 공시 정보 칸은 맨 아래 하나만 둔다.
class EvidenceFolderCard extends StatelessWidget {
  const EvidenceFolderCard({super.key, required this.evidence})
    : assert(evidence.length > 0, '근거가 없으면 카드를 그리지 않는다');

  final List<Evidence> evidence;

  @override
  Widget build(BuildContext context) {
    final first = evidence.first;
    // 피그마 1520:11296: 공시 정보 칸은 맨 아래 하나. 첫 근거에 날짜가 없으면 다음 근거에서 가져온다
    // (QA: 근거 2개일 때 첫 근거만 보다가 공시일 · 대상 기간이 통째로 사라졌다)
    String? firstOf(String? Function(Evidence e) pick) {
      for (final e in evidence) {
        final v = pick(e)?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final published = firstOf((e) => e.publishedAt);
    final period = firstOf((e) => e.period);
    final meta = [
      if (published != null) '공시일 ㅣ $published',
      if (period != null) '대상 기간 ㅣ $period',
    ];
    final title = Text(
      first.title,
      // 피그마 1520:9645: 20 SemiBold · 줄 140% · #15171B
      style: AppTypography.title4.copyWith(color: AppColors.ink, height: 1.4),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              // 피그마 1520:9641: 14 Medium #5E6B0B (탭 148×39, 위 10 아래 칸의 가운데)
              child: Text(
                '답변에 활용할 정보',
                style: AppTypography.body2Medium.copyWith(color: AppColors.pointText, height: 1.4),
              ),
            ),
          child: title,
        ),
        Container(
          // 피그마 1520:9646: 좌우 20 · 위아래 24 (QA: 좌우 24 · 아래 36 이라 디자인보다 넓었다), 바탕 #303137
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          decoration: const BoxDecoration(
            color: AppColors.tabBar,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 피그마 1520:11310: 내용 16 / #404147 1px 선 / 내용 … 사이를 모두 16 으로 띄운다
              for (var i = 0; i < evidence.length; i++) ...[
                if (i > 0) ...[
                  // 피그마 1540:11471: 선은 높이 0 칸 위에 1px 로 그려져 위 15 · 아래 16 (글 사이 합 32)
                  const SizedBox(height: AppSpacing.md - 1),
                  const Divider(height: 1, thickness: 1, color: Color(0xFF404147)),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  evidence[i].excerpt,
                  style: AppTypography.subheading.copyWith(
                    fontWeight: AppTypography.regular,
                    color: AppColors.white,
                    height: 1.6,
                  ),
                ),
                if (evidence[i].interpretation != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '해석 · ${evidence[i].interpretation}',
                    style: AppTypography.body2.copyWith(color: const Color(0xFFB9B9BC)),
                  ),
                ],
              ],
              // 피그마 1520:11312: 공시 정보 칸은 근거가 몇 개든 맨 아래 하나 (#404147, r12, 안쪽 12)
              if (meta.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF404147), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    meta.join('\n'),
                    style: AppTypography.caption.copyWith(fontWeight: AppTypography.regular, color: const Color(0xFFBCBFC5), height: 1.4, letterSpacing: 0),
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

/// "재답변 (2/3)" 회색 버튼 (남은 기회 / 질문별 누적 최대). 제출 불가면 더 흐리게 보이고,
/// 눌러도 다시 답하지 않고 "답변 기회가 모두 소진되었어요" 안내만 띄운다 (피그마 1335:8520).
class RetryAnswerButton extends StatelessWidget {
  const RetryAnswerButton({
    super.key,
    required this.prefix,
    required this.remaining,
    required this.onRetry,
    this.canSubmit = true,
    this.blockedMessage,
    this.blockedHelp,
    this.primary = false,
  });

  /// 피그마 1653:10895: 복습 화면의 단독 버튼은 진한 바탕 (횟수가 없으면 회색)
  final bool primary;
  final String prefix;
  final int remaining;
  final VoidCallback onRetry;
  final bool canSubmit;
  final String? blockedMessage;
  final String? blockedHelp;

  @override
  Widget build(BuildContext context) {
    final left = remaining.clamp(0, AppPolicy.retryPerQuestionDaily);
    final out = left <= 0 || !canSubmit;
    final label = '$prefix ($left/${AppPolicy.retryPerQuestionDaily})';
    return Semantics(
      button: true,
      label: out ? '$label, ${blockedMessage ?? '현재 답변할 수 없어요'}' : label,
      excludeSemantics: true,
      child: Material(
        color: out ? const Color(0xFFE9EBED) : (primary ? AppColors.ink : AppColors.fillMuted),
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          splashFactory: NoSplash.splashFactory,
          onTap: out
              ? () => showNoticeDialog(
                  context,
                  title: blockedMessage ?? '이 질문의 답변 기회를 모두 사용했어요',
                  message: blockedHelp ?? '같은 질문에는 누적 최대 3회 답변할 수 있고 다음 날 초기화되지 않아요.',
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
                    color: out ? AppColors.textGuide : (primary ? AppColors.white : AppColors.textSub),
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

/// 오늘의 다음 면접 질문으로. 지난 질문·답변 화면은 스택에서 모두 걷어 내서
/// 다음 질문에서 뒤로가기로 이미 답한(기회를 다 쓴) 질문에 다시 들어가지 않게 한다.
void goNextInterviewQuestion(BuildContext context, String companyId) {
  final router = GoRouter.of(context);
  router.go(Routes.home);
  WidgetsBinding.instance.addPostFrameCallback((_) => router.push(Routes.todayInterview(companyId)));
}

/// 피그마 1653:10983 "하단 페이드" (152 높이, 9.5% 지점에서 투명 → 36.8% 에서 흰색) 위의 하단 버튼.
/// Scaffold 의 extendBody 와 함께 써서 내용이 이 아래로 지나가게 한다.
class FadedBottomCta extends StatelessWidget {
  const FadedBottomCta({super.key, required this.children});

  final List<Widget> children;

  /// 목록 맨 아래 여백 (마지막 내용이 버튼에 가리지 않게)
  static const double listPadding = 100;

  @override
  Widget build(BuildContext context) {
    // 버튼 묶음(위 8 + 버튼 56 + 아래 안전 영역)이 152 보다 낮으면 위를 투명하게 채워 152 를 맞춘다.
    // (Container 에 alignment 를 주면 bottomNavigationBar 가 화면 전체로 늘어나 흰 막이 덮인다)
    final bottom = MediaQuery.paddingOf(context).bottom;
    final own = AppSpacing.xs + 56.0 * children.length + (children.length - 1) * AppSpacing.ctaGap + (bottom > AppSpacing.sm ? bottom : AppSpacing.sm);
    final top = own >= 152 ? 0.0 : 152 - own;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Colors.white],
          stops: [0.09539, 0.36842],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          BottomCta(color: Colors.transparent, children: children),
        ],
      ),
    );
  }
}
