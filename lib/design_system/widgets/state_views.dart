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

/// 피그마 "서브 그래픽" (1514:9544): 회색 그림 + 라임 배지. 그림 아래 끝이 제목 윗선에 닿게 잘라 두었다(간격 포함).
enum StateGraphic {
  /// 질문을 만들고 있어요 (1514:9603)
  question('assets/images/state_question.png', 66, 73),

  /// 검색 결과가 없어요 (1514:9656)
  search('assets/images/state_search.png', 78, 80),

  /// 질문을 불러오지 못했어요 · 연결 오류 (1514:9640)
  error('assets/images/state_error.png', 62, 73),

  /// 답변을 텍스트로 변환 중이에요 (1514:9616)
  convert('assets/images/state_convert.png', 66, 72),

  /// 답변을 분석하고 있어요 (1514:9590)
  analyze('assets/images/state_analyze.png', 66, 74),

  /// 개인정보 보호를 위한 인증 (1514:9672)
  privacy('assets/images/state_privacy.png', 64, 69);

  const StateGraphic(this.asset, this.width, this.height);
  final String asset;
  final double width;
  final double height;

  Widget image() => Image.asset(asset, width: width, height: height, excludeFromSemantics: true);
}

/// 서브 그래픽 화면 글자 (피그마 Title/Section 20 SemiBold · Body/Default 16 Medium, 줄 140% · 자간 -3%)
class StateText {
  StateText._();

  static TextStyle title([Color color = const Color(0xFF303137)]) =>
      AppTypography.heading.copyWith(fontSize: 20, height: 1.4, letterSpacing: -0.6, color: color);

  static TextStyle description([Color color = AppColors.textGuide]) =>
      AppTypography.body1Medium.copyWith(fontSize: 16, height: 1.4, letterSpacing: -0.48, color: color);
}

/// 빈·오류 화면 가운데 아이콘 종류
enum StatusIcon {
  /// ⚠ (연결 오류 · 질문 생성 실패 · 로그인 실패)
  warning(Icons.warning_rounded, StateGraphic.error),

  /// 🔍 (검색 결과 없음)
  search(Icons.search_rounded, StateGraphic.search),

  /// 🚀 (복습 기록 없음)
  rocket(Icons.rocket_launch_rounded),

  /// 🛡 (재인증)
  shield(Icons.shield_rounded, StateGraphic.privacy);

  const StatusIcon(this.icon, [this.graphic]);
  final IconData icon;

  /// 피그마 서브 그래픽이 있으면 그 그림
  final StateGraphic? graphic;
}

/// 가운데 아이콘 + 제목 + 설명 (빈 화면 · 오류 화면 공통 모양)
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.title,
    this.description,
    this.icon = StatusIcon.warning,
    this.titleColor,
    this.descriptionColor,
  });

  final String title;
  final String? description;
  final StatusIcon? icon;
  final Color? titleColor;
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) {
    final graphic = icon?.graphic;
    // 서브 그래픽 화면: 그림 바로 아래 제목 20 · 설명 16 (간격 8)
    if (graphic != null) {
      return Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            graphic.image(),
            Text(title, textAlign: TextAlign.center, style: StateText.title(titleColor ?? const Color(0xFF303137))),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(description!, textAlign: TextAlign.center, style: StateText.description(descriptionColor ?? AppColors.textGuide)),
            ],
          ],
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon!.icon, size: 44, color: AppColors.statusIcon)),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(title, textAlign: TextAlign.center, style: AppTypography.heading.copyWith(fontSize: 18, color: titleColor ?? AppColors.ink)),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(description!, textAlign: TextAlign.center, style: AppTypography.body2.copyWith(color: descriptionColor ?? AppColors.textCaption)),
          ],
        ],
      ),
    );
  }
}

/// 피그마 서브 그래픽 화면처럼 "제목·설명 묶음"을 화면 한가운데 두고 그림은 그 위에 얹는다.
/// (그림까지 합쳐 가운데 두면 글자가 그림 높이 절반만큼 위로 올라간다)
class CenteredStatus extends StatelessWidget {
  const CenteredStatus({super.key, required this.graphicHeight, required this.child});

  final double graphicHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Center(child: Transform.translate(offset: Offset(0, -graphicHeight / 2), child: child));
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
    return CenteredStatus(
      graphicHeight: StateGraphic.error.height,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH), child: content),
    );
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
