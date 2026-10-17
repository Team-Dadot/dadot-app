import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/home.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';

/// 2-3 준비 기업 전환 시트 (홈·복습 헤더의 "기아 ▾")
Future<void> showCompanySwitchSheet(BuildContext context, {required HomeSummary home, required String selectedId}) {
  return showAppSheet<void>(
    context,
    title: '어느 기업을 준비할까요?',
    builder: (sheetContext) => Consumer(
      builder: (_, ref, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in home.companies) ...[
              CompanyTile(
                name: c.companyName,
                subtitle: prepSubtitle(jobName: c.preparation.jobName, dday: c.dday, date: c.preparation.interviewDate),
                extra: c.remainingToday == 0 ? '오늘 학습 완료' : '오늘 ${c.remainingToday}개 남음',
                selected: c.companyId == selectedId,
                trailing: c.companyId == selectedId ? Text('✓', style: AppTypography.body2Medium) : null,
                onTap: () {
                  ref.read(selectedCompanyIdProvider.notifier).select(c.companyId);
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: AppSpacing.gap),
            ],
            AppButton(
              label: '준비 기업 추가·관리',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push(Routes.myCompanies);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
