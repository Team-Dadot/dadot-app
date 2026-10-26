import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/router/app_router.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';

/// 6-7 지원 정보·면접 일정
class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preps = ref.watch(preparationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '지원 정보 · 면접 일정'),
      body: preps.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(preparationsProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
          children: [
            SectionTitle(
              '내가 지원한 기업',
              trailing: Text(
                '${list.length}/${AppPolicy.maxCompanies}',
                style: AppTypography.body2Medium.copyWith(color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (list.isEmpty)
              EmptyView(
                compact: true,
                title: '준비 중인 기업이 없어요',
                actionLabel: '준비 기업 추가하기',
                onAction: () => context.push(Routes.myCompanies),
              ),
            for (final p in list) ...[
              CompanyTile(
                name: p.companyName,
                subtitle: prepSubtitle(jobName: p.jobName, dday: p.ddayFrom(DateTime.now()), date: p.interviewDate),
                trailing: Text('수정', style: AppTypography.caption.copyWith(color: AppColors.textPlaceholder)),
                onTap: () => context.push(Routes.myApplication(p.companyId)),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
