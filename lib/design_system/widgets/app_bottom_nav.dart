import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// 피그마 TabBar (홈 / 복습 / 마이). 위 테두리 #D9D9D9, 위 여백 8, 아이콘 24 + 글자 11.
/// 피그마는 아이콘 자리가 회색 네모라서 같은 크기의 Material 아이콘을 넣었다.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xxs),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == currentIndex,
                    button: true,
                    label: items[i].label,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              items[i].icon,
                              size: AppSizes.tabIcon,
                              color: i == currentIndex ? AppColors.primary : AppColors.border,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              items[i].label,
                              style: i == currentIndex
                                  ? AppTypography.tab.copyWith(color: AppColors.primary, fontWeight: AppTypography.bold)
                                  : AppTypography.tab.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
