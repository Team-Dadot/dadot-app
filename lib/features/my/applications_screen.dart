import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: const AppNavBar(title: '지원 정보·면접 일정'),
      body: preps.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(preparationsProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
          children: [
            const PageTitle('기업마다 따로\n지원 정보를 관리해요.'),
            const SizedBox(height: AppSpacing.gap),
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
                subtitle: prepSubtitle(jobName: p.jobName, date: p.interviewDate, showDate: true),
                trailing: const Chevron(),
                onTap: () => context.push(Routes.myApplication(p.companyId)),
              ),
              const SizedBox(height: AppSpacing.gap),
            ],
          ],
        ),
      ),
    );
  }
}
