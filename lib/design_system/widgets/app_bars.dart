import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 피그마 내비 바: 왼쪽 ‹, 가운데 제목(18 Medium), 높이 56. [divider] 면 아래 1px 선 (퀴즈).
class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBack = true,
    this.actions,
    this.divider = false,
    this.color = AppColors.background,
  });

  final String title;

  /// 바탕색 (퀴즈 화면은 흰색)
  final Color color;
  final VoidCallback? onBack;
  final bool showBack;
  final List<Widget>? actions;
  final bool divider;

  @override
  Size get preferredSize => Size.fromHeight(AppSizes.navBarHeight + (divider ? 1 : 0));

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final back = showBack && (canPop || onBack != null);
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 폭을 화면 전체로 잡아야 ‹ 가 화면 왼쪽(20)에 붙는다.
            // (폭을 안 주면 Stack 이 제목 글자 크기로 줄어 가운데 놓이고, 제목 없는 퀴즈 화면에선 ‹ 가 가운데로 간다)
            SizedBox(
              width: double.infinity,
              height: AppSizes.navBarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Semantics(
                      header: true,
                      child: Text(title, style: AppTypography.navTitle, overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                  ),
                  if (back)
                    // 피그마: ‹ 는 8×15 선(굵기 2), 화면 왼쪽에서 20 떨어져 세로 가운데.
                    // 누르는 영역은 44×44 로 넓히되 그림은 정확히 x=20 에 오게 한다.
                    Positioned(
                      left: AppSpacing.screenH - 12,
                      top: 0,
                      bottom: 0,
                      child: Semantics(
                        button: true,
                        label: '뒤로',
                        excludeSemantics: true,
                        child: InkResponse(
                          key: const ValueKey('nav-back'),
                          onTap: onBack ?? () => Navigator.of(context).maybePop(),
                          radius: 22,
                          child: const SizedBox(
                            width: AppSizes.minTouch,
                            height: AppSizes.navBarHeight,
                            child: Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Align(alignment: Alignment.centerLeft, child: BackChevron()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (actions != null && actions!.isNotEmpty)
                    Positioned(
                      right: AppSpacing.xs,
                      top: 0,
                      bottom: 0,
                      child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
                    ),
                ],
              ),
            ),
            if (divider) const SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: AppColors.divider)),
          ],
        ),
      ),
    );
  }
}

/// 탭 화면 상단 (왼쪽 DADOT 워드마크 또는 "Review" 글자 + 오른쪽 기업 칩). 높이 52
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, this.title, this.trailing});

  /// 피그마 1313:8755 홈 상단 "dadot." 워드마크 (소문자 + 라임 점, 86×18)
  static const String logoAsset = 'assets/images/dadot_wordmark_dark.png';

  /// null 이면 DADOT 로고
  final String? title;
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
                if (title == null)
                  Image.asset(logoAsset, height: 18, semanticLabel: 'Dadot', filterQuality: FilterQuality.medium)
                else
                  // 피그마 1337:10216 Display/Header: Zalando Sans SemiExpanded Medium 24 · 줄 140% · 자간 -3% · #303137
                  Semantics(
                    header: true,
                    child: Text(
                      title!,
                      style: AppTypography.number(24, weight: FontWeight.w500, color: const Color(0xFF303137))
                          .copyWith(letterSpacing: -0.72),
                    ),
                  ),
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

/// 헤더 오른쪽 기업 전환 칩 — 차콜 알약 + 흰 원 로고 + 이름 + ▾
class CompanyChip extends StatelessWidget {
  const CompanyChip({super.key, required this.label, required this.onTap, this.emphasized = false, this.light = false});

  final String label;
  final VoidCallback? onTap;

  /// 면접 집중 모드 (주황 테두리)
  final bool emphasized;

  /// 글 안에 들어가는 밝은 칩 (홈 인사말 "[기아 ▾] 에 대해")
  final bool light;

  @override
  Widget build(BuildContext context) {
    final bg = light ? AppColors.accentSoft : AppColors.primary;
    final fg = light ? AppColors.accent : AppColors.white;
    return Semantics(
      button: true,
      label: '준비 기업 바꾸기, 지금 $label',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: emphasized ? const BorderSide(color: AppColors.accent, width: 1.5) : BorderSide.none),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(light ? 10 : 3, 3, 8, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!light) ...[
                  CompanyLogo(name: label, size: 25),
                  const SizedBox(width: 6),
                ],
                Text(label, style: AppTypography.body2Strong.copyWith(color: fg)),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 흰 원 안 기업 로고 자리. 로고 이미지가 없어서 기업 이름 앞 글자를 넣는다.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.name, this.size = AppSizes.logoTile, this.bordered = false});

  final String name;
  final double size;

  /// 흰 카드 위에서는 연한 테두리
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '' : name.trim().characters.take(2).toString();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: bordered ? Border.all(color: AppColors.divider) : null,
        ),
        child: Text(
          initial,
          maxLines: 1,
          style: AppTypography.captionStrong.copyWith(fontSize: size * 0.3, color: AppColors.textStrong, height: 1),
        ),
      ),
    );
  }
}

/// 피그마 뒤로 가기 ‹ (8×15, 선 굵기 2, 끝 둥글게)
class BackChevron extends StatelessWidget {
  const BackChevron({super.key, this.color = Colors.black});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(8, 15), painter: _ChevronPainter(color));
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
