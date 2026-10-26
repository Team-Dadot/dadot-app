import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_button.dart';

/// 로딩 / 오류 / 빈 상태 공통 화면.
/// 빈 화면은 피그마 5-E1 (가운데 아이콘 + 제목 18 SemiBold + 설명 14) 기준.

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary)),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, textAlign: TextAlign.center, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = asAppException(error);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(compact ? e.userMessage : '불러오지 못했어요', textAlign: TextAlign.center, style: AppTypography.subheading),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(e.userMessage, textAlign: TextAlign.center, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(label: '다시 시도', onPressed: onRetry, expand: false, small: true, variant: AppButtonVariant.outline),
        ],
      ],
    );
    if (compact) return Padding(padding: const EdgeInsets.all(AppSpacing.md), child: content);
    return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: content));
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.icon = Icons.rocket_launch_rounded,
  });

  final String title;

  /// 제목 위 아이콘 (null 이면 없음)
  final IconData? icon;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 목록 안에 들어가는 작은 빈 상태
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null && !compact) ...[
          Icon(icon, size: 40, color: const Color(0xFFA9B1C2)),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(title, textAlign: TextAlign.center, style: AppTypography.heading.copyWith(fontSize: 18)),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(description!, textAlign: TextAlign.center, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: actionLabel!, onPressed: onAction, expand: false),
        ],
      ],
    );
    if (compact) return Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl), child: Center(child: body));
    return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: body));
  }
}
