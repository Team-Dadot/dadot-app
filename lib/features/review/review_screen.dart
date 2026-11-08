import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/interview.dart';
import '../../data/models/records.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import '../common/pickers.dart';
import '../home/company_switch_sheet.dart';

/// 피그마 5-1 퀴즈 복습 · 5-2 면접 복습 (작업 프레임): 상단 "Review" + 기업 칩, 밑줄 탭, 알약 필터, 폴더 탭 카드
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.initialTab});

  /// 'quiz' | 'interview'
  final String? initialTab;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late int _tab = widget.initialTab == 'interview' ? 1 : 0;

  @override
  void didUpdateWidget(covariant ReviewScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != null && widget.initialTab != old.initialTab) {
      _tab = widget.initialTab == 'interview' ? 1 : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final selectedId = ref.watch(selectedCompanyIdProvider);
    final summary = home.asData?.value;
    final current = summary == null
        ? null
        : resolveSelected(summary, selectedId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Review',
        trailing: current == null
            ? null
            : CompanyChip(
                label: current.companyName,
                onTap: () => showCompanySwitchSheet(
                  context,
                  home: summary!,
                  selectedId: current.companyId,
                ),
              ),
      ),
      body: home.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(homeProvider)),
        data: (_) {
          if (current == null) {
            return const EmptyView(
              title: '준비 중인 기업이 없어요',
              description: '마이 > 준비 기업 관리에서 기업을 추가해 주세요.',
            );
          }
          final companyId = current.companyId;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(quizReviewProvider(companyId));
              ref.invalidate(interviewRecordsProvider(companyId));
            },
            child: ListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xl,
              ),
              children: [
                SegmentedTabs(
                  labels: const ['퀴즈', '면접'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: AppSpacing.screen,
                  child: _tab == 0
                      ? _QuizReview(companyId: companyId)
                      : _InterviewReview(companyId: companyId),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- 퀴즈 복습

class _QuizReview extends ConsumerStatefulWidget {
  const _QuizReview({required this.companyId});

  final String companyId;

  @override
  ConsumerState<_QuizReview> createState() => _QuizReviewState();
}

class _QuizReviewState extends ConsumerState<_QuizReview> {
  bool _wrongOnly = true;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(quizReviewProvider(widget.companyId));
    return items.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: LoadingView(),
      ),
      error: (e, _) => ErrorView(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(quizReviewProvider(widget.companyId)),
      ),
      data: (all) {
        if (all.isEmpty) {
          return const _ReviewEmpty(
            title: '아직 푼 퀴즈가 없어요.',
            description: '퀴즈를 풀고 기업 정보를 익혀보세요!',
          );
        }
        final wrong = all.where((i) => i.wrong).toList();
        final shown = _wrongOnly ? wrong : all;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SelectChip(
                  label: '전체',
                  selected: !_wrongOnly,
                  onTap: () => setState(() => _wrongOnly = false),
                ),
                const SizedBox(width: AppSpacing.xs),
                SelectChip(
                  label: '오답',
                  selected: _wrongOnly,
                  onTap: () => setState(() => _wrongOnly = true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (shown.isEmpty)
              const EmptyView(
                compact: true,
                title: '다시 풀 오답이 없어요',
                description: '틀린 문제가 생기면 여기에 모아 둘게요.',
              )
            else
              for (final item in shown) ...[
                _QuizReviewCard(item: item),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        );
      },
    );
  }
}

class _QuizReviewCard extends StatelessWidget {
  const _QuizReviewCard({required this.item});

  final QuizReviewItem item;

  /// 피그마 1337:10053 "문제 해설" 시트: 문제 · 흰 카드(정답 : ○○ / 해설 | 공시 근거 / 인용 / 공시일 | 보고서) · 공시 근거 보기
  void _showExplanation(BuildContext context) {
    final ev = item.evidence ?? item.question.evidence;
    final body = AppTypography.body1.copyWith(
      fontSize: 16,
      height: 1.6,
      color: const Color(0xFF727479),
    );
    final head = AppTypography.body1.copyWith(
      fontSize: 16,
      height: 1.6,
      color: AppColors.textStrong,
    );
    final meta = AppTypography.caption.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textGuide,
    );
    final correct = item.correctText;
    showAppSheet<void>(
      context,
      title: '문제 해설',
      expand: true,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xxs,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.question.prompt,
                    style: AppTypography.title4.copyWith(
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (correct != null) Text('정답 : $correct', style: head),
                        if (correct != null)
                          const SizedBox(height: AppSpacing.xs),
                        Text(item.explanation, style: body),
                        if (ev != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: LineDivider(),
                          ),
                          Text('공시 근거', style: head),
                          const SizedBox(height: AppSpacing.xs),
                          Text(ev.excerpt, style: body),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            [
                              if (ev.publishedAt != null) ev.publishedAt!,
                              ev.title,
                            ].join('  |  '),
                            style: meta,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ev != null)
            BottomCta(
              color: AppColors.sheet,
              children: [
                AppButton(
                  label: '공시 근거 보기',
                  onPressed: () => showEvidenceSheet(
                    context,
                    evidence: ev,
                    questionId: item.question.id,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReviewFolderCard(
      date: formatDotSpaced(item.solvedAt).replaceAll(RegExp(r'\.$'), ''),
      status: item.wrong ? '오답' : '정답',
      tone: item.wrong ? ReviewTone.warn : ReviewTone.done,
      title: item.question.prompt,
      secondaryLabel: '해설 보기',
      onSecondary: () => _showExplanation(context),
      primaryLabel: '다시 풀기',
      onPrimary: () => context.push(Routes.quizRetry(item.id, item.companyId)),
    );
  }
}

/// 상태 알약 색 (보완 필요·오답 = 주황, 작성 중 = 라임, 완성 답변·정답 = 파랑)
enum ReviewTone { warn, draft, done }

/// 복습 기록 카드 (피그마 최종 5-1 · 5-2): 흰 카드 · 날짜(12, 60%) + 오른쪽 상태 알약 · 질문 16 · 버튼(42, 모서리 10)
/// [secondaryLabel] 이 null 이면 라임 버튼 하나, [primaryLabel] 이 null 이면 회색 버튼 하나.
class ReviewFolderCard extends StatelessWidget {
  const ReviewFolderCard({
    super.key,
    required this.date,
    required this.status,
    required this.tone,
    required this.title,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryLabel,
    this.onPrimary,
    this.scoreTag,
    this.onLongPress,
  });

  final String date;
  final String status;
  final ReviewTone tone;
  final String title;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// 날짜 옆 점수 (76점)
  final String? scoreTag;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (tone) {
      ReviewTone.warn => (
        AppColors.accentSoft,
        AppColors.accent,
        Icons.warning_rounded,
      ),
      ReviewTone.draft => (
        AppColors.pointSoft,
        AppColors.pointText,
        Icons.edit_rounded,
      ),
      ReviewTone.done => (
        AppColors.infoSoft,
        AppColors.info,
        Icons.description_rounded,
      ),
    };
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  date,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textStrong,
                    fontWeight: AppTypography.medium,
                  ),
                ),
                if (scoreTag != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    scoreTag!,
                    style: AppTypography.captionStrong.copyWith(color: fg),
                  ),
                ],
                const Spacer(),
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: fg),
                      const SizedBox(width: 2),
                      Text(
                        status,
                        style: AppTypography.captionStrong.copyWith(
                          color: fg,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.subheading.copyWith(
                color: AppColors.textStrong,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                // 피그마 1337:10014: 회색 버튼 #E9EBED · 글자 #303137 (42, 모서리 10)
                if (secondaryLabel != null)
                  Expanded(
                    child: _CardGreyButton(
                      label: secondaryLabel!,
                      onPressed: onSecondary,
                    ),
                  ),
                if (secondaryLabel != null && primaryLabel != null)
                  const SizedBox(width: AppSpacing.sm),
                if (primaryLabel != null)
                  Expanded(
                    child: AppButton(
                      label: primaryLabel!,
                      small: true,
                      variant: AppButtonVariant.point,
                      onPressed: onPrimary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 5-E1 · 5-E2 빈 화면 (가운데 로켓 + 제목 + 설명)
class _ReviewEmpty extends StatelessWidget {
  const _ReviewEmpty({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 140),
      child: EmptyView(title: title, description: description),
    );
  }
}

// ---------------------------------------------------------------- 면접 복습

enum _InterviewFilter { all, needsWork, draft, complete }

class _InterviewReview extends ConsumerStatefulWidget {
  const _InterviewReview({required this.companyId});

  final String companyId;

  @override
  ConsumerState<_InterviewReview> createState() => _InterviewReviewState();
}

class _InterviewReviewState extends ConsumerState<_InterviewReview> {
  _InterviewFilter _filter = _InterviewFilter.all;

  Future<void> _delete(InterviewRecord r) async {
    final ok = await showConfirmDialog(
      context,
      title: '이 질문과 답변을 지울까요?',
      message: '모든 시도와 피드백이 함께 지워지고 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(recordsRepositoryProvider)
          .deleteInterviewRecord(r.questionId);
      invalidateProgress(ref);
      if (mounted) showToast(context, '삭제했어요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(interviewRecordsProvider(widget.companyId));
    return records.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: LoadingView(),
      ),
      error: (e, _) => ErrorView(
        error: e,
        compact: true,
        onRetry: () =>
            ref.invalidate(interviewRecordsProvider(widget.companyId)),
      ),
      data: (all) {
        if (all.isEmpty) {
          return const _ReviewEmpty(
            title: '아직 답변한 질문이 없어요',
            description: '면접 질문에 답변하고 복습해보세요!',
          );
        }
        final shown = switch (_filter) {
          _InterviewFilter.all => all,
          _InterviewFilter.needsWork =>
            all.where((r) => r.status == AnswerStatus.needsWork).toList(),
          _InterviewFilter.draft =>
            all.where((r) => r.status == AnswerStatus.draft).toList(),
          _InterviewFilter.complete =>
            all.where((r) => r.status == AnswerStatus.complete).toList(),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final (f, label) in const [
                  (_InterviewFilter.all, '전체'),
                  (_InterviewFilter.needsWork, '보완 필요'),
                  (_InterviewFilter.draft, '작성중'),
                  (_InterviewFilter.complete, '완성 답변'),
                ]) ...[
                  SelectChip(
                    label: label,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (shown.isEmpty)
              const EmptyView(
                compact: true,
                title: '해당하는 답변이 없어요',
                description: '답변을 쌓아 내용을 확인해 보세요!',
              )
            else
              for (final r in shown) ...[
                _InterviewRecordCard(record: r, onDelete: () => _delete(r)),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        );
      },
    );
  }
}

class _InterviewRecordCard extends StatelessWidget {
  const _InterviewRecordCard({required this.record, required this.onDelete});

  final InterviewRecord record;

  /// 길게 누르면 삭제 확인
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final draft = r.status == AnswerStatus.draft;
    final (String status, ReviewTone tone) = switch (r.status) {
      AnswerStatus.needsWork => ('보완필요', ReviewTone.warn),
      AnswerStatus.draft => ('작성 중', ReviewTone.draft),
      AnswerStatus.complete => ('완성 답변', ReviewTone.done),
    };
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: '삭제'): onDelete,
      },
      child: ReviewFolderCard(
        date: r.lastAt == null
            ? '작성 중'
            : formatDotSpaced(r.lastAt!).replaceAll(RegExp(r'\.$'), ''),
        // 복습 카드에는 점수를 보여주지 않는다 (상태 배지만)
        status: status,
        tone: tone,
        title: r.questionText,
        // 피그마: 보완 필요 = 평가 보기 + 다시 답변하기 / 작성 중 = 이어서 답변하기 / 완성 답변 = 평가 보기
        secondaryLabel: draft ? null : '평가 보기',
        onSecondary: draft
            ? null
            : () => context.push(Routes.answerView(r.questionId)),
        primaryLabel: switch (r.status) {
          AnswerStatus.draft => '이어서 답변하기',
          AnswerStatus.needsWork => '다시 답변하기',
          AnswerStatus.complete => null,
        },
        onPrimary: () => context.push(Routes.interviewAnswer(r.questionId)),
        onLongPress: onDelete,
      ),
    );
  }
}

class _CardGreyButton extends StatelessWidget {
  const _CardGreyButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFFE9EBED),
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: SizedBox(
            height: 42,
            child: Center(
              child: Text(
                label,
                style: AppTypography.subheading.copyWith(color: AppColors.textStrong),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
