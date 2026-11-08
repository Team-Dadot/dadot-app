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
/// 라임 폴더 카드(오늘의 학습 · 기업 변경 ⇄) 위에 기업·면접일·D-day, 아래 진한 몸통에 기업 퀴즈 · 면접 연습 · 오늘의 학습하기.
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
                const SizedBox(height: AppSpacing.xxl),
                _Stats(c: current),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 오늘의 학습 카드: 라임(집중 모드면 진한) 폴더 + 진한 몸통
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
    // 첫 줄은 기업 이름, 둘째 줄은 직무 ㅣ 면접일
    final title = c.companyName;
    final date = p.interviewDate == null ? null : formatMonthDayWeek(p.interviewDate!);
    // 피그마 1259:9198 "UX·UI디자인 ㅣ 12월 25일 (금) 면접" · 1259:9317 당일 "UX·UI디자인 ㅣ면접 당일"
    final when = c.dday == 0 ? '면접 당일' : (date == null ? '면접 일정 미정' : '$date 면접');
    final subtitle = p.hasJob ? '${p.jobName} ㅣ $when' : when;
    // 피그마 763:15840 집중 모드: 앞판 가장 진한 색(#15171B), 뒤 탭은 평소처럼 연라임, 탭 글자 회색
    final front = focus ? AppColors.ink : AppColors.point;
    final onFront = focus ? AppColors.white : AppColors.ink;
    final tabText = focus ? AppColors.tabActive : AppColors.pointText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FolderCard(
          color: front,
          backColor: AppColors.folderBack,
          tabWidth: 150,
          tabHeight: 44,
          curveWidth: 50,
          radius: AppRadius.lg,
          bottomRadius: 0,
          bodyPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          tab: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (focus) ...[const _FocusBadge(), const SizedBox(width: 6)],
              Text('오늘의 학습', style: AppTypography.body2Strong.copyWith(color: tabText)),
            ],
          ),
          trailing: Semantics(
            button: true,
            label: '준비 기업 바꾸기',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('기업 변경', style: AppTypography.body2Medium.copyWith(color: AppColors.pointText)),
                const SizedBox(width: 6),
                const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.pointText),
              ],
            ),
          ),
          onTrailingTap: onSwitch,
          child: Row(
            children: [
              CompanyLogo(name: c.companyName, size: 48, bordered: true),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheading.copyWith(fontSize: 18, color: onFront, height: 1.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body2Medium.copyWith(
                        color: focus ? AppColors.white : AppColors.pointText,
                      ),
                    ),
                  ],
                ),
              ),
              if (c.dday != null)
                Text(formatDday(c.dday!), style: AppTypography.number(26, color: focus ? AppColors.point : AppColors.ink)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxs, AppSpacing.lg, AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
          ),
          child: c.allDone
              ? _DoneBody(focus: focus)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TaskRow(title: '기업 퀴즈', task: c.quiz, onTap: () => context.push(Routes.quiz(c.companyId))),
                    const SizedBox(height: 0.5, child: ColoredBox(color: AppColors.cardDarkLine)),
                    _TaskRow(title: '면접 연습', task: c.interview, onTap: () => context.push(Routes.todayInterview(c.companyId))),
                    const SizedBox(height: AppSpacing.xs),
                    AppButton(
                      label: '오늘의 학습하기',
                      variant: focus ? AppButtonVariant.point : AppButtonVariant.ink,
                      onPressed: () => _start(context),
                    ),
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

/// "🔥 기업 퀴즈 · 5/5" (다 하면 라임 숫자)
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
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Row(
              children: [
                Image.asset('assets/images/icons/fire.png', width: 20, height: 20, excludeFromSemantics: true),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(child: Text(title, style: AppTypography.subheading.copyWith(color: AppColors.white, height: 1.4))),
                Text(
                  '${task.done}/${task.total}',
                  style: AppTypography.subheading.copyWith(
                    fontWeight: AppTypography.regular,
                    color: task.isDone ? AppColors.point : const Color(0xFFB9B9BC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2-E2 하루치 학습 완료 (피그마 1313:8927): 회색 칸(깃발 + "오늘의 학습을 완료했어요!") + 라임 "복습하러 가기"
class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.focus});

  final bool focus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 128,
          decoration: BoxDecoration(
            color: focus ? AppColors.tabBar : AppColors.cardDarkLine,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag_rounded, size: 36, color: Color(0xFF898D9A)),
              const SizedBox(height: AppSpacing.sm),
              Text('오늘의 학습을 완료했어요!', style: AppTypography.body2Medium.copyWith(color: AppColors.textGuide)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(label: '복습하러 가기', variant: AppButtonVariant.point, onPressed: () => context.go(Routes.review)),
      ],
    );
  }
}

/// 학습 현황: 퀴즈 정답률(주황 막대) · 면접 완성률(라임 막대)
class _Stats extends StatelessWidget {
  const _Stats({required this.c});

  final CompanyHome c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('학습 현황', style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: const Color(0xFF9A9A9A))),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '퀴즈 정답률',
                value: c.accuracy ?? 0,
                detail: c.quizSolved == 0 ? '아직 푼 퀴즈가 없어요' : '${c.quizSolved}문제 중 ${c.quizCorrect}개 정답',
                barColor: AppColors.statQuiz,
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
            Text(label, style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: const Color(0xFF22282F))),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$value', style: AppTypography.number(32, color: const Color(0xFF2B2B2C))),
                  TextSpan(text: '%', style: AppTypography.number(20, color: const Color(0xFF2B2B2C))),
                ],
              ),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(fontWeight: AppTypography.regular, color: const Color(0xFF979BA3)),
            ),
            const SizedBox(height: AppSpacing.xs),
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
