import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'boxes.dart';

/// 피그마 iOS/NavBar: "〈 제목" 왼쪽 정렬, 높이 44
class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({super.key, required this.title, this.onBack, this.showBack = true, this.actions});

  final String title;
  final VoidCallback? onBack;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.navBarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final back = showBack && (canPop || onBack != null);
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSizes.navBarHeight,
          child: Row(
            children: [
              if (back)
                Semantics(
                  button: true,
                  label: '뒤로',
                  child: InkWell(
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                      width: AppSizes.minTouch,
                      height: AppSizes.navBarHeight,
                      child: Center(child: Text('〈', style: AppTypography.title3.copyWith(fontWeight: AppTypography.regular))),
                    ),
                  ),
                )
              else
                const SizedBox(width: AppSpacing.screenH),
              Expanded(child: Text(title, style: AppTypography.heading, overflow: TextOverflow.ellipsis)),
              ...?actions,
              const SizedBox(width: AppSpacing.screenH),
            ],
          ),
        ),
      ),
    );
  }
}

/// 탭 화면 상단 (로고 + 공시노트 + 오른쪽 기업 칩). 높이 52
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.headerHeight);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSizes.headerHeight,
          child: Padding(
            padding: AppSpacing.screen,
            child: Row(
              children: [
                // TODO(디자인): 앱 로고가 나오면 교체
                const LogoBox(size: AppSizes.logoHeader),
                const SizedBox(width: AppSpacing.xs),
                Text('공시노트', style: AppTypography.heading),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 헤더 오른쪽 "기아 ▾" 기업 전환 칩
class CompanyChip extends StatelessWidget {
  const CompanyChip({super.key, required this.label, required this.onTap, this.emphasized = false});

  final String label;
  final VoidCallback? onTap;

  /// 면접 집중 모드 (테두리 진하게)
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '준비 기업 바꾸기, 지금 $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: emphasized ? AppColors.primary : AppColors.borderChip)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(label, style: AppTypography.body2Medium), const DropdownMark()],
          ),
        ),
      ),
    );
  }
}
