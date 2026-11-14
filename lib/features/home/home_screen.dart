import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/home.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import 'company_switch_sheet.dart';

/// 피그마 최종: 홈3(기본) · 집중 모드(D-3) · 2-E1 첫 방문(면접 일정 미정) · 2-E2 하루치 학습 완료 · 2-3 기업 선택 시트
/// 진한 폴더 카드(오늘의 학습 · 기업 변경 ⇄) 위에 기업·면접일·D-day, 아래 회색 칸에 기업 퀴즈 · 면접 연습 → 라임 오늘의 학습하기.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final selectedId = ref.watch(selectedCompanyIdProvider);
    final summary = home.asData?.value;
    final current = summary == null ? null : resolveSelected(summary, selectedId);

    return Scaffold(
      backgroundColor: AppColors.background,
      // 피그마 홈(1313:8755 등): 헤더엔 로고만 (알림 설정은 마이 > 알림 설정)
      appBar: const AppHeader(),
      body: home.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(homeProvider)),
        data: (h) {
          if (current == null) {
            return EmptyView(
              title: '준비 중인 기업이 없어요',
              description: '준비 기업을 추가하면 오늘의 퀴즈와 면접 질문이 열려요.',
              actionLabel: '준비 기업 추가하기',
              onAction: () => context.push(Routes.myCompanies),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(homeProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
              children: [
                _TodayCard(
                  current: current,
                  onSwitch: () => showCompanySwitchSheet(context, home: h, selectedId: current.companyId),
                ),
                const SizedBox(height: 28),
                _Stats(c: current),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 오늘의 학습 카드 (피그마 1313:8755 기본 · 1313:8839 집중 · 1313:8927 학습 완료)
/// 회색 뒤판(기업 변경 ⇄) 위에 진한 앞판(#15171B) 폴더: 탭 "오늘의 학습"(집중이면 ⚡집중) ·
/// 로고 · 기업 · "직무 | 면접일" · 라임 D-day → 회색 칸(🔥 기업 퀴즈 5/5 · 면접 연습 2/3) → 라임 "오늘의 학습하기"
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.current, required this.onSwitch});

  final CompanyHome current;
  final VoidCallback onSwitch;

  void _start(BuildContext context) {
    if (!current.quiz.isDone) {
      context.push(Routes.quiz(current.companyId));
    } else {
      context.push(Routes.todayInterview(current.companyId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = current;
    final p = c.preparation;
    final focus = c.focusMode;
    final date = p.interviewDate == null ? null : formatMonthDayWeek(p.interviewDate!);
    // 피그마: "UX·UI디자인 | 12월 25일 (금) 면접" · 당일 "UX·UI디자인 | 면접 당일"
    final when = c.dday == 0 ? '면접 당일' : (date == null ? '면접 일정 미정' : '$date 면접');
    final sub = AppTypography.caption.copyWith(fontSize: 13, color: AppColors.white, letterSpacing: -0.39, height: 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FolderCard(
          color: AppColors.ink,
          backColor: const Color(0xFFE4E4E4),
          // 앞판 탭: 기본 142 + 곡선 57 / 집중(⚡집중 배지만큼 넓게) 162 + 곡선 47, 탭 높이 45
          tabWidth: focus ? 162 : 142,
          tabHeight: 45,
          curveWidth: focus ? 47 : 57,
          radius: 20,
          bottomRadius: 0,
          bodyPadding: const EdgeInsets.fromLTRB(20, 26, 20, 11),
          tab: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (focus) ...[const _FocusBadge(), const SizedBox(width: 8)],
              Text(
                '오늘의 학습',
                style: AppTypography.caption.copyWith(fontSize: 13, color: AppColors.tabActive, letterSpacing: -0.39),
              ),
            ],
          ),
          trailing: Semantics(
            button: true,
            label: '준비 기업 바꾸기',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '기업 변경',
                  style: AppTypography.caption.copyWith(fontSize: 13, color: const Color(0xFF4C4C4C), letterSpacing: -0.39),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF727272)),
              ],
            ),
          ),
          onTrailingTap: onSwitch,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(name: c.companyName, size: 48, bordered: true),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subheading.copyWith(fontSize: 18, color: AppColors.white, height: 1.4, letterSpacing: -0.54),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (p.hasJob) ...[
                            Flexible(child: Text(p.jobName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sub)),
                            Container(
                              width: 1,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              color: const Color(0xFF55565A),
                            ),
                          ],
                          Text(when, maxLines: 1, style: sub),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (c.dday != null)
                Text(
                  formatDday(c.dday!),
                  style: AppTypography.number(28, color: AppColors.point, height: 1).copyWith(letterSpacing: -1.4),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 128,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: AppColors.tabBar, borderRadius: BorderRadius.circular(16)),
                child: c.allDone
                    ? const _DoneBody()
                    : Column(
                        children: [
                          _TaskRow(title: '기업 퀴즈', task: c.quiz, onTap: () => context.push(Routes.quiz(c.companyId))),
                          const SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: Color(0xFF4F5464))),
                          Expanded(
                            child: _TaskRow(
                              title: '면접 연습',
                              task: c.interview,
                              onTap: () => context.push(Routes.todayInterview(c.companyId)),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              c.allDone
                  ? AppButton(label: '복습하러 가기', variant: AppButtonVariant.point, onPressed: () => context.go(Routes.review))
                  : AppButton(label: '오늘의 학습하기', variant: AppButtonVariant.point, onPressed: () => _start(context)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 집중 모드 배지 (라임 알약 "⚡ 집중")
class _FocusBadge extends StatelessWidget {
  const _FocusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      // 피그마: 진한 바탕 + 라임 1px 테두리(모서리 10) + 라임 ⚡ · "집중" 12 SemiBold
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.point),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 12, color: AppColors.point),
          const SizedBox(width: 2),
          Text('집중', style: AppTypography.captionStrong.copyWith(color: AppColors.point)),
        ],
      ),
    );
  }
}

/// "🔥 기업 퀴즈        5/5" (피그마: 14 SemiBold 흰 글자 · 숫자 14 Medium, 다 하면 라임 · 아니면 #BCBFC5)
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.title, required this.task, required this.onTap});

  final String title;
  final TodayTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, ${task.total}개 중 ${task.done}개 완료',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 63,
          child: Row(
            children: [
              Image.asset('assets/images/icons/fire.png', width: 20, height: 20, excludeFromSemantics: true),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body2Strong.copyWith(color: AppColors.white, height: 1.4, letterSpacing: -0.42),
                ),
              ),
              Text(
                '${task.done}/${task.total}',
                style: AppTypography.body2Medium.copyWith(
                  color: task.isDone ? AppColors.point : AppColors.tabActive,
                  letterSpacing: -0.42,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2-E2 하루치 학습 완료 (피그마 1313:8927): 회색 칸 안 깃발(36) + "오늘의 학습을 완료했어요!" (버튼은 "복습하러 가기")
class _DoneBody extends StatelessWidget {
  const _DoneBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.flag_rounded, size: 36, color: Color(0xFF898D9A)),
        const SizedBox(height: AppSpacing.sm),
        Text('오늘의 학습을 완료했어요!', style: AppTypography.body2Medium.copyWith(color: AppColors.textGuide)),
      ],
    );
  }
}

/// 학습 현황: 퀴즈 정답률(주황 막대) · 면접 완성률(라임 막대)
class _Stats extends ConsumerWidget {
  const _Stats({required this.c});

  final CompanyHome c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('학습 현황', style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.textGuide, letterSpacing: -0.48)),
        const SizedBox(height: AppSpacing.md),
        if (c.statsError != null)
          ErrorView(error: c.statsError!, compact: true, onRetry: () => ref.invalidate(homeProvider))
        else
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '퀴즈 정답률',
                  value: c.accuracy ?? 0,
                  detail: c.quizSolved == 0 ? '아직 푼 퀴즈가 없어요' : '${c.quizSolved}문제 중 ${c.quizCorrect}개 정답',
                  barColor: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: '면접 완성률',
                  value: c.completionRate ?? 0,
                  detail: c.interviewAnswered == 0
                      ? '아직 답변한 질문이 없어요'
                      : c.interviewScorePercent != null
                          ? '${c.interviewAnswered}질문 평균 점수'
                          : '${c.interviewAnswered}질문 중 ${c.interviewCompleted}개 완성',
                  barColor: AppColors.point,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.detail, required this.barColor});

  final String label;
  final int value;
  final String detail;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value퍼센트, $detail',
      excludeSemantics: true,
      child: Container(
        height: 175,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.body2Strong.copyWith(color: AppColors.textStrong, letterSpacing: -0.42)),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$value', style: AppTypography.number(30, color: AppColors.textStrong).copyWith(letterSpacing: -1.5)),
                  TextSpan(text: '%', style: AppTypography.number(18, color: AppColors.textStrong)),
                ],
              ),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(fontWeight: AppTypography.regular, color: AppColors.textGuide),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                height: 6,
                color: AppColors.statTrack,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (value / 100).clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
