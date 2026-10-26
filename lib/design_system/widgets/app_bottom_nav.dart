import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.label, required this.icon, this.asset});

  final String label;
  final IconData icon;

  /// 피그마 아이콘 PNG (흰색으로 그려 두고 색을 입힌다). 있으면 [icon] 대신 쓴다.
  final String? asset;
}

/// 피그마 탭 바 (홈 / 복습 / 마이): 차콜 #303137, 위 모서리 24, Iconex 아이콘 24 + 글자 12 Medium.
/// 선택된 탭 #BCBEC2, 나머지 #5C5D63.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.tabBar,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.tabBar)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == currentIndex,
                      button: true,
                      label: items[i].label,
                      excludeSemantics: true,
                      child: InkResponse(
                        onTap: () => onTap(i),
                        radius: 32,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (items[i].asset != null)
                              Image.asset(
                                items[i].asset!,
                                width: AppSizes.tabIcon,
                                height: AppSizes.tabIcon,
                                color: i == currentIndex ? AppColors.tabActive : AppColors.tabInactive,
                                colorBlendMode: BlendMode.srcIn,
                              )
                            else
                              Icon(
                                items[i].icon,
                                size: AppSizes.tabIcon,
                                color: i == currentIndex ? AppColors.tabActive : AppColors.tabInactive,
                              ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              items[i].label,
                              style: AppTypography.tab.copyWith(
                                color: i == currentIndex ? AppColors.tabActive : AppColors.tabInactive,
                                fontWeight: AppTypography.medium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
