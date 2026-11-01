import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 피그마 버튼. Primary(차콜) / Secondary(연회색) / Point(라임) / Outline. 큰 버튼 높이 56·모서리 16, 작은 버튼 42·모서리 10.
/// text 는 "공시 근거 먼저 보기 ›" 같은 글자 링크.
/// [point] 은 라임 버튼 (복습 "다시 풀기 · 다시 답변하기"), [ink] 는 가장 진한 바탕에 라임 글자 (홈 오늘의 학습하기).
enum AppButtonVariant { primary, secondary, outline, text, point, ink }

/// 공통 버튼. [loading] 이면 스피너를 보여주고 누를 수 없다.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    if (variant == AppButtonVariant.text) {
      return TextLink(label: label, onTap: enabled ? onPressed : null);
    }

    final height = small ? AppSizes.buttonHeightSmall : AppSizes.buttonHeight;
    final (Color bg, Color fg, BorderSide? side) = switch (variant) {
      // 피그마 변수 bg/cta-primary = gray/900 (#15171B)
      AppButtonVariant.primary => (AppColors.ink, AppColors.onPrimary, null),
      AppButtonVariant.secondary => (
          small ? AppColors.fillSecondary : AppColors.fillMuted,
          small ? AppColors.textStrong.withValues(alpha: 0.65) : AppColors.textSub,
          null,
        ),
      AppButtonVariant.point => (AppColors.point, AppColors.ink, null),
      // 홈 "오늘의 학습하기": 가장 진한 바탕 + 라임 글자
      AppButtonVariant.ink => (AppColors.ink, AppColors.point, null),
      AppButtonVariant.outline => (AppColors.white, AppColors.textPrimary, const BorderSide(color: AppColors.borderStrong)),
      AppButtonVariant.text => (Colors.transparent, AppColors.textSub, null),
    };

    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        // 긴 문구("다른 기업 학습하기 · LG전자 오늘 8개 남음 →")는 잘리지 않게 줄여서 한 줄로
        : FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, textAlign: TextAlign.center));

    final style = TextButton.styleFrom(
      minimumSize: Size(expand ? double.infinity : 0, height),
      padding: EdgeInsets.symmetric(horizontal: small ? AppSpacing.sm : AppSpacing.lg),
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: variant == AppButtonVariant.secondary ? bg : AppColors.disabledFill,
      disabledForegroundColor: AppColors.textDisabled,
      textStyle: small ? AppTypography.buttonSmall : AppTypography.button,
      shape: RoundedRectangleBorder(
        side: side ?? BorderSide.none,
        borderRadius: BorderRadius.circular(small ? AppRadius.sm : AppRadius.button),
      ),
      splashFactory: NoSplash.splashFactory,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: TextButton(onPressed: enabled ? onPressed : null, style: style, child: child),
    );
  }
}

/// "오늘 기록 복습하기 ›" 같은 가운데 정렬 글자 링크
class TextLink extends StatelessWidget {
  const TextLink({super.key, required this.label, required this.onTap, this.style, this.align = TextAlign.center});

  final String label;
  final VoidCallback? onTap;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Center(
            widthFactor: 1,
            child: Text(label, textAlign: align, style: style ?? AppTypography.body2Medium.copyWith(color: AppColors.textSub)),
          ),
        ),
      ),
    );
  }
}

/// 화면 하단에 고정되는 버튼 영역 (피그마: 좌우 20, 간격 8, 바탕은 화면색)
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.children, this.color = AppColors.background});

  final List<Widget> children;

  /// 바탕색 (화면 바탕과 맞춘다 — 퀴즈는 흰색)
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.ctaGap),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
