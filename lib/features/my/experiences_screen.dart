import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/experience_sheet.dart';

/// 피그마 최종 6-4 내 경험 · 자소서 관리 (1007:11760 · 960:3903 · 1007:11823 · 1007:11867 · 1007:11792 · 763:17444)
/// - 목록: 제목 + 한 줄 미리보기, 누르면 보기 시트 (이 경험 수정하기 / 삭제하기)
/// - 편집: 체크해서 여러 개 삭제 → "2개의 경험을 삭제했어요 · 되돌리기"
/// - 경험 추가하기: 제목 + 내용 시트
class ExperiencesScreen extends ConsumerStatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  ConsumerState<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends ConsumerState<ExperiencesScreen> {
  bool _editing = false;
  final Set<String> _selected = {};
  bool _busy = false;

  /// 방금 지운 경험 (되돌리기용)
  List<Experience> _deleted = const [];
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
      ref.invalidate(experiencesProvider);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(int count) async {
    if (count >= AppPolicy.maxExperiences) {
      showToast(context, '경험은 최대 ${AppPolicy.maxExperiences}개까지 저장할 수 있어요.');
      return;
    }
    final draft = await showExperienceSheet(context);
    if (draft == null || !mounted) return;
    await _run(
      () => ref.read(profileRepositoryProvider).addExperiences([draft]),
    );
  }

  Future<void> _view(Experience e) async {
    final action = await showAppSheet<String>(
      context,
      title: e.title,
      expand: true,
      heightFactor: SheetHeights.view,
      builder: (_) => _ExperienceView(experience: e),
    );
    if (!mounted) return;
    if (action == 'edit') {
      final draft = await showExperienceSheet(
        context,
        title: '경험 수정하기',
        initial: ExperienceDraft(title: e.title, content: e.content),
        confirmLabel: '수정 완료',
      );
      if (draft == null || !mounted) return;
      await _run(() async {
        await ref
            .read(profileRepositoryProvider)
            .updateExperience(
              Experience(id: e.id, title: draft.title, content: draft.content),
            );
      });
    } else if (action == 'delete') {
      await _delete([e]);
    }
  }

  Future<void> _delete(List<Experience> items) async {
    if (items.isEmpty) return;
    // 피그마 1164:6572 삭제 확인 팝업
    final ok = await showConfirmDialog(
      context,
      warning: true,
      title: '정말 삭제할까요?',
      message: '이 작업은 되돌릴 수 없어요',
      cancelLabel: '취소',
      confirmLabel: '삭제',
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final repo = ref.read(profileRepositoryProvider);
      for (final e in items) {
        await repo.deleteExperience(e.id);
      }
    });
    if (!mounted) return;
    _undoTimer?.cancel();
    setState(() {
      _deleted = items;
      _editing = false;
      _selected.clear();
    });
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _deleted = const []);
    });
  }

  Future<void> _undo() async {
    final items = _deleted;
    _undoTimer?.cancel();
    setState(() => _deleted = const []);
    await _run(
      () => ref.read(profileRepositoryProvider).addExperiences([
        for (final e in items)
          ExperienceDraft(title: e.title, content: e.content),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(experiencesProvider);
    final items = list.asData?.value ?? const <Experience>[];
    // 피그마: "내 경험" · "2/100" · "전체 선택" 16 Medium #767A82
    final label = AppTypography.body1Medium.copyWith(
      fontSize: 16,
      color: AppColors.textCaption,
    );
    final allSelected = items.isNotEmpty && _selected.length == items.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppNavBar(
        title: '내 경험 · 자소서 관리',
        actions: [
          if (items.isNotEmpty || _editing)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _editing = !_editing;
                      _selected.clear();
                    }),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textCaption,
                textStyle: AppTypography.body2Medium,
              ),
              child: Text(_editing ? '취소' : '편집'),
            ),
        ],
      ),
      body: list.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(experiencesProvider),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xl,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _editing
                  // 피그마 1612:10732: 편집 중에는 전체 선택 줄이 내비 아래 8 더 내려온다
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Semantics(
                            checked: allSelected,
                            button: true,
                            child: InkWell(
                              onTap: () => setState(() {
                                if (allSelected) {
                                  _selected.clear();
                                } else {
                                  _selected
                                    ..clear()
                                    ..addAll(items.map((e) => e.id));
                                }
                              }),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CheckMark(checked: allSelected),
                                  const SizedBox(width: 10),
                                  Text('전체 선택', style: label),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(child: Text('내 경험', style: label)),
                        Text(
                          '${items.length}/${AppPolicy.maxExperiences}',
                          style: label,
                        ),
                      ],
                    ),
            ),
            if (items.isEmpty) ...[
              const EmptyView(
                card: true,
                title: '저장한 경험이 없어요',
                description: '경험을 추가하면 내 경험에 맞춘 질문을 받아요.',
              ),
              // QA 1520-9617: 빈 카드와 "삭제했어요" 띠가 붙어 겹쳐 보였다 → 카드 아래로 띄운다
              const SizedBox(height: AppSpacing.sm),
            ],
            for (final e in items) ...[
              _ExperienceCard(
                experience: e,
                editing: _editing,
                selected: _selected.contains(e.id),
                onTap: _busy
                    ? null
                    : () {
                        if (_editing) {
                          setState(
                            () => _selected.contains(e.id)
                                ? _selected.remove(e.id)
                                : _selected.add(e.id),
                          );
                        } else {
                          _view(e);
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_deleted.isNotEmpty)
              _UndoBanner(count: _deleted.length, onUndo: _undo),
          ],
        ),
      ),
      bottomNavigationBar: BottomCta(
        children: [
          if (_editing)
            _DeleteButton(
              count: _selected.length,
              loading: _busy,
              onPressed: _selected.isEmpty || _busy
                  ? null
                  : () => _delete(
                      items.where((e) => _selected.contains(e.id)).toList(),
                    ),
            )
          else
            AppButton(
              label: '경험 추가하기',
              loading: _busy,
              onPressed: _busy || list.isLoading
                  ? null
                  : () => _add(items.length),
            ),
        ],
      ),
    );
  }
}

/// 경험 카드: 제목 한 줄 / 한 줄 미리보기. 편집 중이면 앞에 체크, 고르면 진한 테두리.
class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.experience,
    required this.editing,
    required this.selected,
    required this.onTap,
  });

  final Experience experience;
  final bool editing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return Semantics(
      button: true,
      checked: editing ? selected : null,
      child: OutlinedBox(
        radius: AppRadius.button,
        onTap: onTap,
        // 피그마 1164:6538: 편집 중 고른 카드는 1px 진한 테두리 (체크 표시는 없음)
        borderColor: editing && selected ? AppColors.ink : null,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 피그마 1612:10732 · QA: 옆 화살표 없이 제목 한 줄
            Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle.copyWith(
                fontSize: 18,
                height: 1.4,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              e.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body1.copyWith(
                fontSize: 16,
                height: 1.4,
                color: AppColors.textCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보기 시트: 내용 + 이 경험 수정하기 / 삭제하기 ('edit' / 'delete' 를 돌려준다)
class _ExperienceView extends StatelessWidget {
  const _ExperienceView({required this.experience});

  final Experience experience;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.md,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    experience.content,
                    style: AppTypography.body1.copyWith(
                      color: AppColors.textStrong,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        BottomCta(
          color: AppColors.sheet,
          children: [
            AppButton(
              label: '이 경험 수정하기',
              onPressed: () => Navigator.of(context).pop('edit'),
            ),
            AppButton(
              label: '삭제하기',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 빨간 삭제하기 버튼 (편집 중)
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.count,
    required this.loading,
    required this.onPressed,
  });

  final int count;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: '$count개 경험 삭제하기',
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
          backgroundColor: AppColors.destructive,
          foregroundColor: AppColors.white,
          // 피그마 1612:10732: 0개를 고르면 회색 비활성 (#E9EBED · 글자 #9A9DA4), 처리 중에는 흐린 빨강
          disabledBackgroundColor: loading
              ? AppColors.destructive.withValues(alpha: 0.4)
              : const Color(0xFFE9EBED),
          disabledForegroundColor: loading
              ? AppColors.white
              : AppColors.textGuide,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.white,
                ),
              )
            : Text('$count개 경험 삭제하기'),
      ),
    );
  }
}

/// "● 2개의 경험을 삭제했어요   되돌리기" 분홍 띠
class _UndoBanner extends StatelessWidget {
  const _UndoBanner({required this.count, required this.onUndo});

  final int count;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        // 피그마 1164:6478: 분홍 띠 r12 · 13 Regular
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE3E3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.error_rounded,
                size: 16,
                color: AppColors.destructive,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '$count개의 경험을 삭제했어요.',
                style: AppTypography.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.destructive,
                ),
              ),
            ),
            InkWell(
              onTap: onUndo,
              child: Text(
                '되돌리기',
                style: AppTypography.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textCaption,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textCaption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
