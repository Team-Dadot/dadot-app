import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/home.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 피그마 최종 2-3 "기업 선택하기" 시트 (홈 기업 변경 ⇄ · 복습 헤더 기업 칩)
/// 면접이 가까운 집중 모드 기업은 위에 진한 카드(#303137, 라임 테두리)로, 나머지는 흰 목록에 라디오 체크 (피그마 1337:10109).
Future<void> showCompanySwitchSheet(BuildContext context, {required HomeSummary home, required String selectedId}) {
  return showAppSheet<void>(
    context,
    title: '기업 선택하기',
    builder: (sheetContext) => Consumer(
      builder: (_, ref, _) {
        final focus = home.companies.where((c) => c.focusMode).toList()
          ..sort((a, b) => (a.dday ?? 999).compareTo(b.dday ?? 999));
        final top = focus.firstOrNull;
        final rest = home.companies.where((c) => c.companyId != top?.companyId).toList();

        void pick(String id) {
          ref.read(selectedCompanyIdProvider.notifier).select(id);
          Navigator.of(sheetContext).pop();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null) ...[
                _FocusCompany(c: top, selected: top.companyId == selectedId, onTap: () => pick(top.companyId)),
                const SizedBox(height: AppSpacing.md),
              ],
              if (rest.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.button)),
                  child: Column(
                    children: [
                      for (var i = 0; i < rest.length; i++) ...[
                        if (i > 0) const SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: Color(0xFFDCE0E7))),
                        _CompanyRow(c: rest[i], selected: rest[i].companyId == selectedId, onTap: () => pick(rest[i].companyId)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _FocusCompany extends StatelessWidget {
  const _FocusCompany({required this.c, required this.selected, required this.onTap});

  final CompanyHome c;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.button);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.tabBar,
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.point, width: 1.5)),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.companyName} 면접', style: AppTypography.subheading.copyWith(color: AppColors.point)),
                      const SizedBox(height: AppSpacing.xs),
                      Text.rich(
                        TextSpan(
                          style: AppTypography.caption.copyWith(color: const Color(0xFFBCBFC5)),
                          children: const [
                            TextSpan(text: '면접이 얼마 남지 않았어요!\n'),
                            TextSpan(text: '집중모드로 연습해봐요', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                CheckMark(checked: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({required this.c, required this.selected, required this.onTap});

  final CompanyHome c;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(child: Text(c.companyName, style: AppTypography.subheading.copyWith(color: AppColors.textStrong))),
              CheckMark(checked: selected),
            ],
          ),
        ),
      ),
    );
  }
}
