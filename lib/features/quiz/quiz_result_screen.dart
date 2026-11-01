import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/pickers.dart';

/// 피그마 최종 "정답 확인" (1015:13635 · 1015:13722)
/// 흰 윗부분: 폴더 그림 · "총 4문제 맞혔어요" · "누적 정답률 60% ▲16% 상승"
/// 회색 아랫부분: "틀린 문제" 카드(펼쳐서 정답·해설·공시 근거) · "맞힌 문제" 카드(눌러서 펼치기) → 이어서 면접보기
class QuizResultScreen extends ConsumerStatefulWidget {
  const QuizResultScreen({super.key, required this.setId});

  final String setId;

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  /// 펼친 문항 (처음엔 틀린 문제를 모두 펼친다)
  final Set<String> _open = {};
  bool _initialized = false;

  void _toggle(String id) => setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(quizResultProvider(widget.setId));
    final r = result.asData?.value;
    if (r != null && !_initialized) {
      _initialized = true;
      _open.addAll(r.items.where((i) => !i.correct).map((i) => i.questionId));
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppNavBar(title: '정답 확인', color: AppColors.surface, onBack: () => context.go(Routes.home)),
      body: result.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(quizResultProvider(widget.setId))),
        data: (r) {
          final numbered = [for (var i = 0; i < r.items.length; i++) (i + 1, r.items[i])];
          final wrong = numbered.where((e) => !e.$2.correct).toList();
          final right = numbered.where((e) => e.$2.correct).toList();
          return ListView(
            children: [
              _Summary(result: r),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 34, AppSpacing.screenH, AppSpacing.xxl),
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
                    if (wrong.isNotEmpty && right.isNotEmpty) const SizedBox(height: 28),
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
      bottomNavigationBar: r == null
          ? null
          : BottomCta(
              children: [AppButton(label: '이어서 면접보기', onPressed: () => context.pushReplacement(Routes.todayInterview(r.companyId)))],
            ),
    );
  }
}

/// 폴더 그림 + 맞힌 수 + 누적 정답률 변화
class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final after = r.accuracyAfter ?? 0;
    final before = r.accuracyBefore;
    final delta = before == null ? 0 : after - before;
    final base = AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.textCaption);
    final trend = AppTypography.subheading.copyWith(color: delta >= 0 ? AppColors.accent : AppColors.info);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xxl),
      child: Column(
        children: [
          Image.asset('assets/images/folder_result.png', width: 139, height: 143, excludeFromSemantics: true),
          Semantics(
            header: true,
            child: Text('총 ${r.correctCount}문제 맞혔어요', textAlign: TextAlign.center, style: AppTypography.title1.copyWith(fontWeight: AppTypography.semibold, color: AppColors.ink)),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text.rich(
            TextSpan(
              style: base,
              children: [
                TextSpan(text: '누적 정답률 $after%'),
                if (delta != 0) ...[
                  const TextSpan(text: '   '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(delta > 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 22, color: trend.color),
                  ),
                  TextSpan(text: '${delta.abs()}% ${delta > 0 ? '상승' : '하락'}', style: trend),
                ],
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// "틀린 문제" / "맞힌 문제" 흰 카드
class _ResultGroup extends StatelessWidget {
  const _ResultGroup({required this.wrong, required this.items, required this.open, required this.onToggle});

  final bool wrong;
  final List<(int, QuizResultItem)> items;
  final Set<String> open;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      radius: AppRadius.button,
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _GroupIcon(wrong: wrong),
              const SizedBox(width: AppSpacing.xs),
              Semantics(
                header: true,
                child: Text(wrong ? '틀린 문제' : '맞힌 문제', style: AppTypography.heading.copyWith(fontSize: 18, color: AppColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
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
          border: Border.all(color: wrong ? AppColors.accent : AppColors.point, width: 1.05),
        ),
        child: wrong
            ? const Icon(Icons.close_rounded, size: 12, color: AppColors.accent)
            : Container(
                width: 10.3,
                height: 10.3,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.point, width: 1.25)),
              ),
      ),
    );
  }
}

/// 번호(Zalando) · 문제 · ⌄ — 펼치면 정답 · 해설 · 공시 근거(눌러서 시트)
class _ResultItem extends StatelessWidget {
  const _ResultItem({required this.number, required this.item, required this.open, required this.divider, required this.onToggle});

  final int number;
  final QuizResultItem item;
  final bool open;
  final bool divider;
  final VoidCallback onToggle;

  /// "C. 늘었다" → "늘었다"
  static String _plain(String answer) => answer.replaceFirst(RegExp(r'^[A-Z]\.\s*'), '');

  @override
  Widget build(BuildContext context) {
    final ev = item.evidence;
    final label = AppTypography.body2Strong.copyWith(color: AppColors.textSub);
    final body = AppTypography.body2.copyWith(color: AppColors.textMuted);
    return Container(
      decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: AppColors.rowLine)) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: '$number번 ${item.title}, ${item.correct ? '정답' : '오답'}, 해설 ${open ? '접기' : '펼치기'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 70),
                child: Row(
                  children: [
                    Text('$number', style: AppTypography.number(16, color: AppColors.textStrong)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item.title, style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.textStrong)),
                    ),
                    Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.statusIcon),
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
                      onTap: () => showEvidenceSheet(context, evidence: ev, questionId: item.questionId),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('공시 근거', style: label),
                          const SizedBox(height: AppSpacing.xs),
                          Text(ev.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis, style: body),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              if (ev.publishedAt != null) ...[
                                Text(ev.publishedAt!, style: AppTypography.caption.copyWith(fontWeight: AppTypography.regular, color: AppColors.statusIcon)),
                                Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs), color: AppColors.statusIcon),
                              ],
                              Flexible(
                                child: Text(ev.title, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(fontWeight: AppTypography.regular, color: AppColors.statusIcon)),
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
