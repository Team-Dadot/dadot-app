import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/design_system.dart';

/// 하단 탭 3개: 홈 / 복습 / 마이 (피그마 최종 탭 바, Iconex Home · Document · User)
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    AppBottomNavItem(label: '홈', icon: Icons.home_rounded, asset: 'assets/images/icons/tab_home.png'),
    AppBottomNavItem(label: '복습', icon: Icons.description_rounded, asset: 'assets/images/icons/tab_review.png'),
    AppBottomNavItem(label: '마이', icon: Icons.person_rounded, asset: 'assets/images/icons/tab_my.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: shell,
      bottomNavigationBar: AppBottomNav(
        items: _items,
        currentIndex: shell.currentIndex,
        // 같은 탭을 다시 누르면 그 탭의 첫 화면으로
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
