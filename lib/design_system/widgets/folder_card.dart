import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// 피그마 "Folder Card": 위쪽에 폴더 탭이 붙은 카드 (홈 오늘의 학습 · 복습 기록 카드).
///
/// ```
///  ╭──────────╮__________________
///  │ [tab]     ╲    [trailing]    │  ← 뒤 폴더(backColor, 없으면 투명)
///  │            ╲________________╮│
///  │  body                        │
///  ╰──────────────────────────────╯
/// ```
/// [mirror] 면 탭이 오른쪽에 붙는다 (홈 기업 바꾸기 상태).
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.tab,
    required this.child,
    this.trailing,
    this.color = AppColors.primary,
    this.backColor,
    this.tabWidth,
    this.trailingWidth = 120,
    this.tabHeight = 53,
    this.curveWidth = 57,
    this.radius = AppRadius.xl,
    this.bottomRadius,
    this.mirror = false,
    this.bodyPadding = const EdgeInsets.fromLTRB(12, 16, 12, 12),
    this.onTrailingTap,
  });

  /// 탭 안 내용 (오늘의 학습 / 2026. 11. 11)
  final Widget tab;

  /// 탭 옆 빈 칸에 들어가는 내용 (기업 바꾸기 ⇄ / 오답 ●)
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  final Widget child;
  final Color color;

  /// 뒤 폴더 색 (홈: #D9DADE). null 이면 뒤 폴더 없음.
  final Color? backColor;

  /// 탭 너비. null 이면 (전체 - curveWidth - trailingWidth)
  final double? tabWidth;
  final double trailingWidth;
  final double tabHeight;
  final double curveWidth;
  final double radius;

  /// 아래 모서리 (null 이면 [radius]). 홈 카드처럼 아래에 다른 몸통이 이어지면 0.
  final double? bottomRadius;
  final bool mirror;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final maxTab = (w - curveWidth - radius).clamp(radius * 2, double.infinity).toDouble();
        final tw = (tabWidth ?? (w - curveWidth - trailingWidth)).clamp(radius * 2, maxTab).toDouble();
        final tabBox = SizedBox(
          width: tw,
          height: tabHeight,
          child: Padding(
            padding: EdgeInsets.only(left: mirror ? 0 : 20, right: mirror ? 20 : 0),
            child: Align(alignment: mirror ? Alignment.centerRight : Alignment.centerLeft, child: tab),
          ),
        );
        Widget trail = SizedBox(
          height: tabHeight,
          child: Padding(
            padding: EdgeInsets.only(left: mirror ? 20 : 0, right: mirror ? 0 : 20, top: backColor == null ? 0 : 5),
            child: Align(alignment: mirror ? Alignment.centerLeft : Alignment.centerRight, child: trailing),
          ),
        );
        if (onTrailingTap != null) {
          trail = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTrailingTap, child: trail);
        }
        final topRow = Row(
          textDirection: mirror ? TextDirection.rtl : TextDirection.ltr,
          children: [
            tabBox,
            SizedBox(width: curveWidth),
            Expanded(child: trail),
          ],
        );
        return CustomPaint(
          painter: _FolderPainter(
            color: color,
            backColor: backColor,
            tabWidth: tw,
            tabHeight: tabHeight,
            curveWidth: curveWidth,
            radius: radius,
            bottomRadius: bottomRadius ?? radius,
            mirror: mirror,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topRow,
              Padding(padding: bodyPadding, child: child),
            ],
          ),
        );
      },
    );
  }
}

class _FolderPainter extends CustomPainter {
  _FolderPainter({
    required this.color,
    required this.backColor,
    required this.tabWidth,
    required this.tabHeight,
    required this.curveWidth,
    required this.radius,
    required this.bottomRadius,
    required this.mirror,
  });

  final Color color;
  final Color? backColor;
  final double tabWidth;
  final double tabHeight;
  final double curveWidth;
  final double radius;
  final double bottomRadius;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (mirror) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    if (backColor != null) {
      final back = RRect.fromLTRBAndCorners(
        0,
        5,
        w,
        tabHeight + 20,
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      );
      canvas.drawRRect(back, Paint()..color = backColor!);
    }
    final r = radius;
    final cx = tabWidth;
    final cw = curveWidth;
    final th = tabHeight;
    final path = Path()
      ..moveTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(cx - 6, 0)
      // 탭 → 몸통으로 내려가는 S 곡선 (피그마 "② Curve")
      ..cubicTo(cx + cw * 0.35, 0, cx + cw * 0.55, th, cx + cw, th)
      ..lineTo(w - r, th)
      ..arcToPoint(Offset(w, th + r), radius: Radius.circular(r))
      ..lineTo(w, h - bottomRadius)
      ..arcToPoint(Offset(w - bottomRadius, h), radius: Radius.circular(bottomRadius))
      ..lineTo(bottomRadius, h)
      ..arcToPoint(Offset(0, h - bottomRadius), radius: Radius.circular(bottomRadius))
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FolderPainter old) =>
      old.color != color ||
      old.backColor != backColor ||
      old.tabWidth != tabWidth ||
      old.tabHeight != tabHeight ||
      old.curveWidth != curveWidth ||
      old.radius != radius ||
      old.bottomRadius != bottomRadius ||
      old.mirror != mirror;
}
