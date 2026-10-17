import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 칸 나뉜 진행 막대 (온보딩 STEP 1/4: 간격 6, 퀴즈 1/5: 간격 4). 현재 단계까지 검정.
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
      child: Row(
        children: [
          for (var i = 1; i <= total; i++) ...[
            if (i > 1) SizedBox(width: gap),
            Expanded(
              child: Container(
                height: AppSizes.progressHeight,
                color: i <= current ? AppColors.primary : AppColors.progressTrack,
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
            child: Container(
              height: AppSizes.scoreBarHeight,
              color: AppColors.scoreTrack,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: v, heightFactor: 1, child: const ColoredBox(color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 10),
          Text('$score/$max', style: AppTypography.captionStrong),
        ],
      ),
    );
  }
}

/// 로딩 일러스트 자리 + 문구 (4-1 질문 생성 중, 4-5 분석 중)
class ProcessingView extends StatelessWidget {
  const ProcessingView({super.key, required this.title, this.description = '잠시만 기다려 주세요.'});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              color: AppColors.placeholder,
              alignment: Alignment.center,
              child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: AppSpacing.gap),
            Text(title, textAlign: TextAlign.center, style: AppTypography.heading),
            const SizedBox(height: AppSpacing.xs),
            Text(description, textAlign: TextAlign.center, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
