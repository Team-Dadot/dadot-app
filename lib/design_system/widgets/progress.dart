import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 진행 막대 (높이 8, 둥근 알약). [gap] 이 0 이면 한 줄 막대(퀴즈), 아니면 칸 나뉜 막대(온보딩 STEP).
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.current, required this.total, this.gap = 6});

  final int current;
  final int total;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total단계 중 $current단계',
      excludeSemantics: true,
      child: gap <= 0
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                height: AppSizes.progressHeight,
                color: AppColors.progressTrack,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: total == 0 ? 0 : (current / total).clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.progressFill,
                      borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
                    ),
                  ),
                ),
              ),
            )
          : Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) SizedBox(width: gap),
                  Expanded(
                    child: Container(
                      height: AppSizes.progressHeight / 2,
                      decoration: BoxDecoration(
                        color: i <= current ? AppColors.progressFill : AppColors.progressTrack,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// 항목 점수 막대 한 줄 (질문에 대한 응답성 ▇▇▇ 17/20)
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.label, required this.score, required this.max, this.compact = false});

  final String label;
  final int score;
  final int max;

  /// 답변 보기 화면 (글자 12, 이름 칸 좁게)
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final v = max == 0 ? 0.0 : (score / max).clamp(0.0, 1.0);
    return Semantics(
      label: '$label $max점 중 $score점',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: compact ? 110 : 130,
            child: Text(label, style: (compact ? AppTypography.caption : AppTypography.body2).copyWith(color: AppColors.textBody)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                height: AppSizes.scoreBarHeight,
                color: AppColors.scoreTrack,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  child: ColoredBox(color: v >= 0.8 ? AppColors.primary : AppColors.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$score/$max', style: AppTypography.captionStrong),
        ],
      ),
    );
  }
}

/// 로딩 화면 (피그마 4-1 질문 생성 중 · 4-5 분석 중): 회색 원 72 + 제목 18 + 설명 14
class ProcessingView extends StatelessWidget {
  const ProcessingView({super.key, required this.title, this.description = '잠시만 기다려 주세요', this.iconAsset});

  final String title;
  final String description;

  /// 피그마 최종 로딩 아이콘 (질문 생성: load_question · 답변 분석: load_answer). 없으면 회색 원 + 스피너.
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null)
              _Pulse(child: Image.asset(iconAsset!, width: 48, height: 48, excludeFromSemantics: true))
            else
              Container(
                width: AppSizes.illustration,
                height: AppSizes.illustration,
                decoration: const BoxDecoration(color: AppColors.placeholder, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.white)),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: AppTypography.heading.copyWith(fontSize: 18, fontWeight: AppTypography.medium)),
            const SizedBox(height: AppSpacing.xs),
            Text(description, textAlign: TextAlign.center, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// 로딩 아이콘이 천천히 숨 쉬듯 움직인다 (기다리는 중이라는 표시)
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: Tween<double>(begin: 0.45, end: 1).animate(_c), child: widget.child);
}
