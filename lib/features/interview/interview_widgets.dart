import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/app_policy.dart';
import '../../data/models/interview.dart';
import '../../data/models/quiz.dart' show Evidence;
import '../../design_system/design_system.dart';

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

/// 피드백 화면 한 줄 요약 (가장 낮은 항목 기준). 서버가 요약을 주면 그걸 쓴다.
String feedbackHeadline(AnswerFeedback f) {
  if (f.metCount >= AppPolicy.completeMetCount) return '완성된 답변이에요!';
  if (f.criteria.isEmpty) return '답변을 조금 더 다듬어 보세요.';
  final weakest = f.criteria.reduce((a, b) => (a.max == 0 ? 0 : a.score / a.max) <= (b.max == 0 ? 0 : b.score / b.max) ? a : b);
  return switch (weakest.key) {
    CriterionKey.responsiveness => '질문에 더 직접적으로 답해 주세요.',
    CriterionKey.companyInfo => '기업 정보를 더 활용해 말해주세요.',
    CriterionKey.specificity => '경험을 더 구체적으로 말해주세요.',
    CriterionKey.logic => '답변 구조를 더 짜임새 있게 다듬어 주세요.',
    CriterionKey.clarity => '핵심을 더 분명하게 전달해 주세요.',
  };
}

/// 답변 피드백 본문 (피그마 최종 "결과 확인" 1015:13833). 4-1 답변 피드백 · 5-2 면접 복습이 같이 쓴다.
/// 흰 윗부분: 점수 반원 게이지(상태 배지 · 76% · 폴더) · 한 줄 요약 · 라임 질문 칸
/// 회색 아랫부분 "면접 피드백": 나의 답변 · 평가 항목 · 답변 돌아보기 · 연결할 경험
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
        Padding(
          // 피그마: 게이지는 내비 바 아래 22, 질문 칸 아래 회색 영역까지 31
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 22, AppSpacing.screenH, 31),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: ScoreGauge(feedback: f)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                    child: Text('!', style: AppTypography.caption.copyWith(fontWeight: AppTypography.semibold, color: AppColors.point, height: 1)),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(child: Text(feedbackHeadline(f), style: AppTypography.body2Medium.copyWith(color: AppColors.ink, height: 1.45))),
                ],
              ),
              if (questionText != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.pointPale, borderRadius: BorderRadius.circular(AppRadius.button)),
                  child: Semantics(
                    header: true,
                    child: Text(questionText!, textAlign: TextAlign.center, style: AppTypography.heading.copyWith(fontSize: 18, color: AppColors.textPrimary, height: 1.4)),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 51, AppSpacing.screenH, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text('면접 피드백', style: AppTypography.title4.copyWith(color: AppColors.textCaption))),
              const SizedBox(height: AppSpacing.md),
              if (attemptPicker != null) ...[attemptPicker!, const SizedBox(height: AppSpacing.md)],
              _FeedbackCard(
                icon: 'fb_answer.png',
                iconSize: const Size(20, 20),
                title: '나의 답변',
                child: _MyAnswer(feedback: f, onDelete: onDeleteAttempt),
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
                    const SizedBox(height: AppSpacing.lg),
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
                      _Point(title: related.title, body: related.content, gap: AppSpacing.xxs),
                      const SizedBox(height: AppSpacing.lg),
                      _Point(title: '어떻게 활용할 수 있을까?', body: related.tip),
                    ],
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

/// 점수 게이지 (피그마 1015:13838): 224 원 위 240° 호 — 회색 바탕 호 + 라임 점수 호(굵기 16, 끝 둥글게) + 끝 라임 점(흰 테두리)
/// 안에 상태 배지(위 40) · "76%"(위 72, Zalando 38) · 폴더 그림(위 99, 92×95)
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.feedback});

  final AnswerFeedback feedback;

  static const double size = 224;

  /// 피그마 프레임이 아래를 잘라서 보여주는 높이
  static const double height = 194;

  @override
  Widget build(BuildContext context) {
    final f = feedback;
    final complete = f.metCount >= AppPolicy.completeMetCount;
    return Semantics(
      label: '${f.status.label}, 100점 중 ${f.score}점',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: height,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              width: size,
              height: size,
              child: CustomPaint(painter: _GaugePainter(value: (f.score / 100).clamp(0.0, 1.0))),
            ),
            Positioned(
              top: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: complete ? AppColors.infoSoft : AppColors.pointSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  complete ? f.status.label : f.status.label.replaceAll(' ', ''),
                  style: AppTypography.body2Strong.copyWith(color: complete ? AppColors.info : AppColors.pointDeep, height: 1.2),
                ),
              ),
            ),
            Positioned(
              top: 72,
              child: Text('${f.score}%', style: AppTypography.number(38, color: AppColors.ink).copyWith(letterSpacing: -1.9)),
            ),
            Positioned(
              top: 99,
              child: Image.asset('assets/images/folder_result.png', width: 92, height: 95, excludeFromSemantics: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value});

  final double value;

  static const _deg = 3.141592653589793 / 180;
  static const _start = 150 * _deg; // 왼쪽 아래에서 시작
  static const _sweep = 240 * _deg; // 오른쪽 아래까지

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    // 선이 원 안쪽에 그려진다 (피그마 stroke INSIDE)
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    Paint line(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, _start, _sweep, false, line(AppColors.barTrack));
    if (value <= 0) return;
    final end = _start + _sweep * value;
    canvas.drawArc(arcRect, _start, _sweep * value, false, line(AppColors.point));
    // 끝 점: 라임 원(16) + 흰 테두리 2
    final r = arcRect.width / 2;
    final c = arcRect.center + Offset(r * math.cos(end), r * math.sin(end));
    canvas.drawCircle(c, 8, Paint()..color = AppColors.point);
    canvas.drawCircle(
      c,
      8,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

/// 흰 카드: 아이콘 + 제목 18 + 밑줄, 그 아래 내용
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.icon, required this.iconSize, required this.title, required this.child});

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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fillMuted))),
            child: Row(
              children: [
                Image.asset('assets/images/icons/$icon', width: iconSize.width, height: iconSize.height, excludeFromSemantics: true),
                const SizedBox(width: AppSpacing.xs),
                Semantics(header: true, child: Text(title, style: AppTypography.heading.copyWith(fontSize: 18, color: AppColors.ink))),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// 소제목 16 SemiBold + 본문 16 (줄 높이 1.6)
class _Point extends StatelessWidget {
  const _Point({required this.title, required this.body, this.gap = AppSpacing.xs});

  final String title;
  final String body;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.subheading.copyWith(color: AppColors.textStrong)),
        SizedBox(height: gap),
        Text(body, style: AppTypography.subheading.copyWith(fontWeight: AppTypography.regular, color: AppColors.textSub, height: 1.6)),
      ],
    );
  }
}

/// 나의 답변: 2줄까지 보이고 "더보기 ⌄" 로 펼친다. 복습에서는 시도 시간 · 삭제도.
class _MyAnswer extends StatefulWidget {
  const _MyAnswer({required this.feedback, this.onDelete});

  final AnswerFeedback feedback;
  final VoidCallback? onDelete;

  @override
  State<_MyAnswer> createState() => _MyAnswerState();
}

class _MyAnswerState extends State<_MyAnswer> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final guide = AppTypography.caption.copyWith(fontSize: 13, fontWeight: AppTypography.regular, color: AppColors.textGuide);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          f.content,
          maxLines: _open ? null : 2,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTypography.subheading.copyWith(fontWeight: AppTypography.regular, color: AppColors.textSub, height: 1.6),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            // 피그마는 "더보기 ⌄" 만. 복습에서 지난 시도를 볼 때만 왼쪽에 삭제
            if (widget.onDelete != null) TextLink(label: '이 답변 삭제', style: guide, onTap: widget.onDelete!),
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
                    Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textGuide),
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
    double ratio(CriterionScore c) => c.max == 0 ? 0 : (c.score / c.max).clamp(0.0, 1.0);
    final lowest = criteria.isEmpty ? null : criteria.reduce((a, b) => ratio(a) <= ratio(b) ? a : b);
    final allSame = criteria.every((c) => ratio(c) == ratio(criteria.first));
    final text = AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.textSub, height: 1.6);
    return Column(
      children: [
        for (var i = 0; i < criteria.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: '${criteria[i].key.label} ${criteria[i].max}점 중 ${criteria[i].score}점',
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
                          color: !allSame && identical(criteria[i], lowest) ? AppColors.ink : AppColors.point,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 44,
                  child: Text('${criteria[i].score}/${criteria[i].max}', textAlign: TextAlign.right, style: text.copyWith(fontWeight: AppTypography.regular)),
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
