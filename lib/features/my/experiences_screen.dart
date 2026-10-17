import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 6-4 내 경험 목록
class ExperiencesScreen extends ConsumerWidget {
  const ExperiencesScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Experience e) async {
    final ok = await showConfirmDialog(
      context,
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
      appBar: const AppNavBar(title: '내 경험·자소서'),
      body: list.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(experiencesProvider)),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
          children: [
            AppButton(
              label: '＋ 경험 추가하기',
              onPressed: items.length >= AppPolicy.maxExperiences ? null : () => context.push(Routes.myExperienceNew),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('자소서·이력서 첨부 또는 직접 입력, 여러 경험을 한 번에', textAlign: TextAlign.center, style: AppTypography.micro),
            const SizedBox(height: AppSpacing.lg),
            SectionTitle(
              '저장한 경험 ${items.length}개',
              trailing: Text('${items.length} / ${AppPolicy.maxExperiences}', style: AppTypography.captionStrong),
            ),
            const SizedBox(height: AppSpacing.gap),
            if (items.isEmpty)
              const EmptyView(
                compact: true,
                title: '저장한 경험이 없어요',
                description: '경험을 저장하면 면접 질문과 피드백에 내 경험을 연결해 드려요.',
              ),
            for (final e in items) ...[
              OutlinedBox(
                borderColor: AppColors.divider,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: AppTypography.cardTitle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(e.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        TextLink(label: '내용 수정  ›', style: AppTypography.body2Medium, onTap: () => context.push(Routes.myExperience(e.id))),
                        const Spacer(),
                        TextLink(label: '삭제', style: AppTypography.body2Medium, onTap: () => _delete(context, ref, e)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
            ],
          ],
        ),
      ),
    );
  }
}
