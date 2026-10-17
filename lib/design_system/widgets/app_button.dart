import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 피그마 Button 컴포넌트 Primary / Secondary / Outline. 높이 52, 모서리 없음.
/// text 는 "공시 근거 먼저 보기 ›" 같은 글자 링크.
enum AppButtonVariant { primary, secondary, outline, text }

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
      AppButtonVariant.primary => (AppColors.primary, AppColors.onPrimary, null),
      AppButtonVariant.secondary => (AppColors.fillSecondary, AppColors.textPrimary, null),
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
      disabledBackgroundColor: variant == AppButtonVariant.primary ? AppColors.disabledFill : bg,
      disabledForegroundColor: variant == AppButtonVariant.primary ? AppColors.white : AppColors.textDisabled,
      textStyle: small ? AppTypography.body2Strong : AppTypography.button,
      shape: RoundedRectangleBorder(side: side ?? BorderSide.none),
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

/// 화면 하단에 고정되는 버튼 영역 (피그마 Bottom CTA: 위 8, 좌우 20, 간격 6)
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
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
