import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/home.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 피그마 최종 2-3 "기업 선택하기" 시트 (홈 기업 변경 ⇄ · 복습 헤더 기업 칩)
/// 면접이 가까운 집중 모드 기업은 위에 진한 카드(#303137, 테두리 없음)로, 나머지는 흰 목록에 라디오 체크 (피그마 1529:11425).
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
          // 피그마 1529:11425: 시트 위에서 80 에 카드 시작 (머리 줄이 80), 카드 사이 16
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xxl),
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
                        if (i > 0) const SizedBox(height: 0.5, width: double.infinity, child: ColoredBox(color: Color(0xFFDCE0E7))),
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
        shape: RoundedRectangleBorder(borderRadius: radius),
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
                      // 피그마 1529:11430 · 11431: 16 SemiBold 라임 · 8 · 12 Medium #BCBFC5 (둘째 줄 SemiBold), 줄 140%
                      Text('${c.companyName} 면접', style: AppTypography.subheading.copyWith(color: AppColors.point, height: 1.4)),
                      const SizedBox(height: AppSpacing.xs),
                      Text.rich(
                        TextSpan(
                          style: AppTypography.caption.copyWith(color: const Color(0xFFBCBFC5), fontWeight: AppTypography.medium, height: 1.4),
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
        // 피그마 1529:11434: 위아래 21 · 16 SemiBold #303137
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 21),
          child: Row(
            children: [
              Expanded(child: Text(c.companyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.subheading.copyWith(color: const Color(0xFF303137), height: 1.4))),
              CheckMark(checked: selected),
            ],
          ),
        ),
      ),
    );
  }
}
