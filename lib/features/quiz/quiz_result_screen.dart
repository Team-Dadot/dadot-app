import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/pickers.dart';
import '../common/result_hero.dart';

/// 피그마 최종 "정답 확인" (1332:7808 절반 이상 맞힘 · 1332:7867 절반 못 맞힘)
/// 진한 히어로: 라임/주황 폴더(퀴즈 결과 · "총 4문제 맞혔어요" · "누적 정답률 60%ㅣ▲16%" · 진행 바)
/// 회색 아랫부분: "틀린 문제" · "맞힌 문제" 카드(눌러서 정답·해설·공시 근거 펼치기) → 이어서 면접보기
class QuizResultScreen extends ConsumerStatefulWidget {
  const QuizResultScreen({super.key, required this.setId});

  final String setId;

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  /// 펼친 문항 (피그마: 처음엔 모두 접혀 있다)
  final Set<String> _open = {};

  void _toggle(String id) =>
      setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(quizResultProvider(widget.setId));
    final r = result.asData?.value;
    void home() => context.go(Routes.home);
    if (r == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppNavBar(title: '정답 확인', onBack: home),
        body: result.isLoading
            ? const LoadingView()
            : ErrorView(
                error: result.error ?? '',
                onRetry: () => ref.invalidate(quizResultProvider(widget.setId)),
              ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: result.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(quizResultProvider(widget.setId)),
          ),
          data: (r) {
            final numbered = [
              for (var i = 0; i < r.items.length; i++) (i + 1, r.items[i]),
            ];
            final wrong = numbered.where((e) => !e.$2.correct).toList();
            final right = numbered.where((e) => e.$2.correct).toList();
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // 피그마 1313:7620 · 1313:7832: 내비는 ‹ 뒤로 만 (✕ 없음)
                _Summary(result: r, onBack: home),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    28,
                    AppSpacing.screenH,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wrong.isNotEmpty)
                        _ResultGroup(
                          wrong: true,
                          items: wrong,
                          open: _open,
                          onToggle: _toggle,
                        ),
                      if (wrong.isNotEmpty && right.isNotEmpty)
                        const SizedBox(height: 20),
                      if (right.isNotEmpty)
                        _ResultGroup(
                          wrong: false,
                          items: right,
                          open: _open,
                          onToggle: _toggle,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: BottomCta(
          children: [
            AppButton(
              label: '이어서 면접보기',
              onPressed: () =>
                  context.pushReplacement(Routes.todayInterview(r.companyId)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 히어로: 절반 이상 맞히면 라임(불꽃), 아니면 주황(느낌표). 진행 바 = 이번 세트 정답 비율.
class _Summary extends StatelessWidget {
  const _Summary({required this.result, required this.onBack});

  final QuizResult result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final tone = r.total > 0 && r.correctCount * 2 >= r.total
        ? ResultTone.pass
        : ResultTone.fail;
    final pass = tone == ResultTone.pass;
    final after = r.accuracyAfter ?? 0;
    final before = r.accuracyBefore;
    final delta = before == null ? 0 : after - before;
    final ink = ResultHero.textColor(tone);
    final sub = pass ? const Color(0xFF1E1E1E) : AppColors.white;
    final base = AppTypography.body2.copyWith(color: sub, height: 1.45);
    final trend = AppTypography.body2Strong.copyWith(
      color: pass ? AppColors.accent : AppColors.white,
      height: 1.45,
    );
    return ResultHero(
      tone: tone,
      navTitle: '정답 확인',
      quiz: true,
      badge: '퀴즈 결과',
      onBack: onBack,
      progress: r.total == 0 ? 0 : r.correctCount / r.total,
      title: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            style: AppTypography.title1.copyWith(
              fontSize: 24,
              fontWeight: AppTypography.semibold,
              color: ink,
              height: 1.4,
              letterSpacing: -1.2,
            ),
            children: [
              const TextSpan(text: '총 '),
              // 피그마 1313:7832: 숫자만 Zalando SemiBold 24
              TextSpan(
                text: '${r.correctCount}',
                style: AppTypography.number(24, color: ink).copyWith(letterSpacing: -1.2),
              ),
              const TextSpan(text: '문제 맞혔어요'),
            ],
          ),
        ),
      ),
      description: Semantics(
        label:
            '누적 정답률 $after%${delta == 0 ? '' : ', ${delta.abs()}% ${delta > 0 ? '상승' : '하락'}'}',
        excludeSemantics: true,
        child: Text.rich(
          TextSpan(
            style: base,
            children: [
              TextSpan(text: '누적 정답률 '),
              TextSpan(
                text: '$after%',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (delta != 0) ...[
                const TextSpan(text: 'ㅣ'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: CustomPaint(
                      size: const Size(14, 14),
                      painter: _TrianglePainter(
                        up: delta > 0,
                        color: trend.color!,
                      ),
                    ),
                  ),
                ),
                TextSpan(text: '${delta.abs()}%', style: trend),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ▲ / ▼ (14×14 안 꼭짓점이 둥근 삼각형)
class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.up, required this.color});

  final bool up;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = up
        ? (Path()
            ..moveTo(w / 2, h * 0.18)
            ..lineTo(w * 0.92, h * 0.82)
            ..lineTo(w * 0.08, h * 0.82))
        : (Path()
            ..moveTo(w * 0.08, h * 0.18)
            ..lineTo(w * 0.92, h * 0.18)
            ..lineTo(w / 2, h * 0.82));
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.5
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.up != up || old.color != color;
}

/// "틀린 문제" / "맞힌 문제" 흰 카드
class _ResultGroup extends StatelessWidget {
  const _ResultGroup({
    required this.wrong,
    required this.items,
    required this.open,
    required this.onToggle,
  });

  final bool wrong;
  final List<(int, QuizResultItem)> items;
  final Set<String> open;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      radius: AppRadius.button,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _GroupIcon(wrong: wrong),
              const SizedBox(width: AppSpacing.xs),
              Semantics(
                header: true,
                child: Text(
                  wrong ? '틀린 문제' : '맞힌 문제',
                  style: AppTypography.heading.copyWith(
                    fontSize: 18,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < items.length; i++)
            _ResultItem(
              number: items[i].$1,
              item: items[i].$2,
              open: open.contains(items[i].$2.questionId),
              divider: i < items.length - 1,
              onToggle: () => onToggle(items[i].$2.questionId),
            ),
        ],
      ),
    );
  }
}

/// 틀린 문제 = 연주황 원 안 ✕, 맞힌 문제 = 라임 겹원
class _GroupIcon extends StatelessWidget {
  const _GroupIcon({required this.wrong});

  final bool wrong;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: wrong ? AppColors.accentSoft : AppColors.pointPaler,
          border: Border.all(
            color: wrong ? AppColors.accent : AppColors.point,
            width: 1.05,
          ),
        ),
        child: wrong
            ? const Icon(Icons.close_rounded, size: 12, color: AppColors.accent)
            : Container(
                width: 10.3,
                height: 10.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.point, width: 1.25),
                ),
              ),
      ),
    );
  }
}

/// 번호(Zalando) · 문제 · ⌄ — 펼치면 정답 · 해설 · 공시 근거(눌러서 시트)
class _ResultItem extends StatelessWidget {
  const _ResultItem({
    required this.number,
    required this.item,
    required this.open,
    required this.divider,
    required this.onToggle,
  });

  final int number;
  final QuizResultItem item;
  final bool open;
  final bool divider;
  final VoidCallback onToggle;

  /// "C. 늘었다" → "늘었다"
  static String _plain(String answer) =>
      answer.replaceFirst(RegExp(r'^[A-Z]\.\s*'), '');

  @override
  Widget build(BuildContext context) {
    final ev = item.evidence;
    final label = AppTypography.body2Strong.copyWith(color: AppColors.textSub);
    final body = AppTypography.body2.copyWith(color: AppColors.textMuted);
    return Container(
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AppColors.rowLine))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label:
                '$number번 ${item.title}, ${item.correct ? '정답' : '오답'}, 해설 ${open ? '접기' : '펼치기'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 70),
                // 피그마 1313:7832: 번호(16 SemiBold) 다음 10 띄우고 문제 한 줄(16 Medium) — 길면 … 로 줄이고, 펼치면 전체.
                // 번호 칸 최소 너비를 고정해 번호마다 문제 글자의 시작선이 맞도록 한다.
                child: Row(
                  crossAxisAlignment: open ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: open ? 23 : 0),
                      // 피그마: 번호는 숫자 폰트(Zalando SemiBold 16) — 12 폭 칸에 가운데로 두어 번호마다 문제 시작선을 맞춘다
                      child: SizedBox(
                        width: 12,
                        child: Text(
                          '$number',
                          textAlign: TextAlign.center,
                          style: AppTypography.number(16, color: AppColors.textStrong, height: 1.45).copyWith(letterSpacing: -0.32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: open ? 23 : 0),
                        child: Text(
                          item.title,
                          maxLines: open ? null : 1,
                          overflow: open ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: AppTypography.subheading.copyWith(
                            fontWeight: AppTypography.medium,
                            color: AppColors.textStrong,
                            height: 1.45,
                            letterSpacing: -0.48,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: EdgeInsets.only(top: open ? 23 : 0),
                      child: Icon(
                        open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFFD2D7DC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.correctAnswer != null) ...[
                    Text('정답 : ${_plain(item.correctAnswer!)}', style: label),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(item.explanation, style: body),
                  if (ev != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InkWell(
                      onTap: () => showEvidenceSheet(
                        context,
                        evidence: ev,
                        questionId: item.questionId,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('공시 근거', style: label),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            ev.excerpt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: body,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              if (ev.publishedAt != null) ...[
                                Text(
                                  ev.publishedAt!,
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: AppTypography.regular,
                                    color: AppColors.statusIcon,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 10,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                  ),
                                  color: AppColors.statusIcon,
                                ),
                              ],
                              Flexible(
                                child: Text(
                                  ev.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: AppTypography.regular,
                                    color: AppColors.statusIcon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
