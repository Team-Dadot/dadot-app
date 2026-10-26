import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 피그마 6-4 내 경험 · 자소서 관리 (밀어서 삭제)
class ExperiencesScreen extends ConsumerWidget {
  const ExperiencesScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Experience e) async {
    final ok = await showConfirmDialog(
      context,
      warning: true,
      title: '이 경험을 지울까요?',
      message: '‘${e.title}’ 경험이 지워지고 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok) return;
    try {
      await ref.read(profileRepositoryProvider).deleteExperience(e.id);
      ref.invalidate(experiencesProvider);
    } catch (err) {
      if (context.mounted) showErrorToast(context, err);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(experiencesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '내 경험 · 자소서 관리'),
      body: list.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(experiencesProvider)),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xl),
          children: [
            SectionTitle(
              '저장한 경험',
              trailing: Text(
                '${items.length}/${AppPolicy.maxExperiences}',
                style: AppTypography.body2Medium.copyWith(color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              const EmptyView(
                compact: true,
                title: '저장한 경험이 없어요',
                description: '경험을 저장하면 면접 질문과 피드백에 내 경험을 연결해 드려요.',
              ),
            for (final e in items) ...[
              // 피그마 6-4 슬라이드 삭제: 왼쪽으로 밀면 빨간 휴지통 → 삭제 확인 팝업
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _delete(context, ref, e);
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 28),
                  decoration: BoxDecoration(color: const Color(0xFFFF7B7B), borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.white),
                ),
                child: Semantics(
                  customSemanticsActions: {const CustomSemanticsAction(label: '삭제'): () => _delete(context, ref, e)},
                  child: OutlinedBox(
                    onTap: () => context.push(Routes.myExperience(e.id)),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: AppTypography.subheading.copyWith(fontWeight: AppTypography.bold)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          e.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '경험 추가하기',
              onPressed: items.length >= AppPolicy.maxExperiences ? null : () => context.push(Routes.myExperienceNew),
            ),
          ],
        ),
      ),
    );
  }
}
