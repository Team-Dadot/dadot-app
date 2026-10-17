import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/home.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import 'company_switch_sheet.dart';

/// 2-1 홈 (기본) · 2-2 면접 D-3 집중 모드 · 2-4 오늘의 학습 완료
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
      // 기본: 기업 칩은 인사말 안에 ("지민님, 기아 ▾ 에 대해") · 집중 모드: 헤더 오른쪽 "기아 · D-3 ▾"
      appBar: AppHeader(
        trailing: current == null || !current.focusMode
            ? null
            : CompanyChip(
                label: current.dday == null ? current.companyName : '${current.companyName} · ${formatDday(current.dday!)}',
                emphasized: true,
                onTap: () => showCompanySwitchSheet(context, home: summary!, selectedId: current.companyId),
              ),
      ),
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
            child: _HomeBody(home: h, current: current),
          );
        },
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.home, required this.current});

  final HomeSummary home;
  final CompanyHome current;

  void _start(BuildContext context) {
    if (!current.quiz.isDone) {
      context.push(Routes.quiz(current.companyId));
    } else {
      context.push(Routes.todayInterview(current.companyId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = current;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
      children: [
        if (c.focusMode)
          const PageTitle('면접이 거의 다 왔어요.\n오늘은 답변을 다듬어 볼까요?', large: false)
        else
          _Greeting(
            nickname: home.nickname,
            companyName: c.companyName,
            onCompanyTap: () => showCompanySwitchSheet(context, home: home, selectedId: c.companyId),
          ),
        const SizedBox(height: AppSpacing.md),
        if (c.focusMode)
          Container(
            color: AppColors.surfaceMuted,
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xs),
                  child: TagChip('면접 집중 모드 · ${formatDday(c.dday ?? 0)}', dark: true),
                ),
                _PrepCard(c: c, focus: true),
              ],
            ),
          )
        else
          _PrepCard(c: c, focus: false),
        const SizedBox(height: AppSpacing.md),
        const SectionTitle('오늘의 학습', large: true),
        const SizedBox(height: AppSpacing.md),
        OutlinedBox(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TaskRow(
                index: 1,
                title: '기업 퀴즈',
                subtitle: c.focusMode ? '오답들을 집중적으로 점검해요' : '객관식 ${c.quizChoiceCount} + 주관식 ${c.quizShortCount}',
                task: c.quiz,
                onTap: () => context.push(Routes.quiz(c.companyId)),
              ),
              const LineDivider(),
              _TaskRow(
                index: 2,
                title: '면접 질문',
                subtitle: c.focusMode ? '보완 필요 질문 다시 말하기' : '기업·직무 맞춤 질문',
                task: c.interview,
                onTap: () => context.push(Routes.todayInterview(c.companyId)),
              ),
              if (c.allDone)
                _DonePanel(home: home, current: c)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(label: '오늘의 학습 시작하기  →', onPressed: () => _start(context)),
                      const SizedBox(height: AppSpacing.xs),
                      if (!c.focusMode)
                        Text(
                          '단계를 눌러 퀴즈나 면접부터 바로 시작할 수도 있어요.',
                          textAlign: TextAlign.center,
                          style: AppTypography.micro.copyWith(color: AppColors.textHint),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 면접 일정 + 누적 정답률·완성률 카드
class _PrepCard extends StatelessWidget {
  const _PrepCard({required this.c, required this.focus});

  final CompanyHome c;
  final bool focus;

  @override
  Widget build(BuildContext context) {
    final p = c.preparation;
    final job = p.hasJob ? ' · ${p.jobName} 면접' : ' 면접';
    final accuracy = c.accuracy;
    final completion = c.completionRate;
    return Container(
      decoration: BoxDecoration(
        color: focus ? AppColors.surfaceMuted : AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                LogoBox(label: focus ? '달력' : '로고'),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.companyName}$job', style: AppTypography.cardTitle),
                      const SizedBox(height: 2),
                      Text(p.interviewDate == null ? '면접일 미정' : formatMonthDayWeek(p.interviewDate!), style: AppTypography.caption),
                    ],
                  ),
                ),
                if (c.dday != null) Text(formatDday(c.dday!), style: AppTypography.title2),
              ],
            ),
          ),
          const LineDivider(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Stat(
                    label: '누적 퀴즈 정답률',
                    value: accuracy == null ? '-' : '$accuracy%',
                    detail: c.quizSolved == 0
                        ? '학습 기록 없음'
                        : focus
                            ? '지금까지 푼 ${c.quizSolved}문제 중 ${c.quizCorrect}개 정답'
                            : '${c.quizSolved}문제 중 ${c.quizCorrect}개 정답',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: '누적 면접 완성률',
                    value: completion == null ? '-' : '$completion%',
                    detail: c.interviewAnswered == 0
                        ? '학습 기록 없음'
                        : focus
                            ? '답한 ${c.interviewAnswered}개 질문 중 ${c.interviewCompleted}개 완성'
                            : '완성 질문 ${c.interviewCompleted}개',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.title1),
          const SizedBox(height: 2),
          Text(detail, style: AppTypography.micro),
        ],
      ),
    );
  }
}

/// 오늘의 학습 한 줄 (1 기업 퀴즈 · 0 / 5 ›)
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.index, required this.title, required this.subtitle, required this.task, required this.onTap});

  final int index;
  final String title;
  final String subtitle;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              IndexBox(label: '$index', done: task.isDone),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.cardTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('${task.done} / ${task.total}', style: AppTypography.body1Strong),
              const SizedBox(width: AppSpacing.sm),
              const Chevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// "지민님, [기아 ▾] 에 대해 / 오늘도 한 걸음 준비해요." (기업 칩을 누르면 전환 시트)
class _Greeting extends StatelessWidget {
  const _Greeting({required this.nickname, required this.companyName, required this.onCompanyTap});

  final String nickname;
  final String companyName;
  final VoidCallback onCompanyTap;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.title2;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              if (nickname.isNotEmpty) Text('$nickname님,', style: style),
              CompanyChip(label: companyName, onTap: onCompanyTap),
              Text('에 대해', style: style),
            ],
          ),
          const SizedBox(height: 2),
          Text('오늘도 한 걸음 준비해요.', style: style),
        ],
      ),
    );
  }
}

/// 2-1 오늘의 학습 완료: "기아 오늘의 학습 완료!" · 복습 탭 안내 · 다른 기업 학습하기
class _DonePanel extends ConsumerWidget {
  const _DonePanel({required this.home, required this.current});

  final HomeSummary home;
  final CompanyHome current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = current;
    final others = home.companies.where((x) => x.companyId != c.companyId).toList();
    final next = others.where((x) => x.remainingToday > 0).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: LogoBox(label: '완료')),
          const SizedBox(height: AppSpacing.sm),
          Text('${c.companyName} 오늘의 학습 완료!', textAlign: TextAlign.center, style: AppTypography.subheading),
          const SizedBox(height: AppSpacing.xxs),
          Text('복습 탭에서 오늘 기록을 다시 볼 수 있어요.', textAlign: TextAlign.center, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          if (others.isNotEmpty) ...[
            AppButton(
              label: next == null ? '다른 기업 학습하기' : '다른 기업 학습하기 · ${next.companyName} 오늘 ${next.remainingToday}개 남음',
              onPressed: () {
                if (next == null) {
                  showCompanySwitchSheet(context, home: home, selectedId: c.companyId);
                } else {
                  ref.read(selectedCompanyIdProvider.notifier).select(next.companyId);
                }
              },
            ),
            const SizedBox(height: AppSpacing.ctaGap),
          ],
          AppButton(
            label: '복습하러 가기',
            variant: others.isEmpty ? AppButtonVariant.primary : AppButtonVariant.secondary,
            onPressed: () => context.go(Routes.review),
          ),
        ],
      ),
    );
  }
}
