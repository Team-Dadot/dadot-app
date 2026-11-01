import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_button.dart';

/// 로딩 / 오류 / 빈 상태 공통 화면.
/// 피그마 최종 "개발 확인" (2-E6 · 4-E3 · 1-E1 · 5-E1 · 1-E2): 가운데 회색 아이콘 + 제목 18 SemiBold + 설명 14 회색.

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

/// 빈·오류 화면 가운데 아이콘 종류
enum StatusIcon {
  /// ⚠ (연결 오류 · 질문 생성 실패 · 로그인 실패)
  warning(Icons.warning_rounded),

  /// 🔍 (검색 결과 없음)
  search(Icons.search_rounded),

  /// 🚀 (복습 기록 없음)
  rocket(Icons.rocket_launch_rounded),

  /// 🛡 (재인증)
  shield(Icons.shield_rounded);

  const StatusIcon(this.icon);
  final IconData icon;
}

/// 가운데 아이콘 + 제목 + 설명 (빈 화면 · 오류 화면 공통 모양)
class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.title, this.description, this.icon = StatusIcon.warning});

  final String title;
  final String? description;
  final StatusIcon? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon!.icon, size: 44, color: AppColors.statusIcon)),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(title, textAlign: TextAlign.center, style: AppTypography.heading.copyWith(fontSize: 18, color: AppColors.ink)),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(description!, textAlign: TextAlign.center, style: AppTypography.body2.copyWith(color: AppColors.textCaption)),
          ],
        ],
      ),
    );
  }
}

/// 불러오기 실패. 연결 문제면 피그마 2-E6 문구 "연결이 원활하지 않아요 / 연결 상태를 확인하고 다시 시도해 주세요".
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false, this.title, this.description, this.retryLabel = '다시 시도'});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  /// 문구를 바꿀 때 (4-E3 "질문을 불러오지 못했어요")
  final String? title;
  final String? description;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final e = asAppException(error);
    final network = e.kind == AppErrorKind.network || e.kind == AppErrorKind.timeout;
    final t = title ?? (network ? '연결이 원활하지 않아요' : (compact ? e.userMessage : '불러오지 못했어요'));
    final d = description ?? (network ? '연결 상태를 확인하고 다시 시도해 주세요' : (compact ? null : e.userMessage));
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusMessage(title: t, description: d, icon: compact ? null : StatusIcon.warning),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(label: retryLabel, onPressed: onRetry, expand: false, small: true, variant: AppButtonVariant.secondary),
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
    this.card = false,
    this.icon = StatusIcon.rocket,
  });

  final String title;

  /// 제목 위 아이콘 (null 이면 없음)
  final StatusIcon? icon;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 목록 안에 들어가는 작은 빈 상태 (아이콘 없음)
  final bool compact;

  /// 흰 카드 안에 넣기 (6-E3 저장한 경험 없음)
  final bool card;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusMessage(title: title, description: description, icon: compact || card ? null : icon),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: actionLabel!, onPressed: onAction, expand: false),
        ],
      ],
    );
    if (card) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 40),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.button)),
        child: body,
      );
    }
    if (compact) return Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl), child: Center(child: body));
    return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: body));
  }
}
