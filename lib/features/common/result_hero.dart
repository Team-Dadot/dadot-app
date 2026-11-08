import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// 결과 화면 윗부분 톤. 잘했으면 라임(불꽃), 아쉬우면 주황(느낌표).
enum ResultTone { pass, fail }

/// 피그마 최종 "면접 피드백" (1335:8520 완성 · 1335:8635 보완) · "정답 확인" (1332:7808 · 1332:7867) 윗부분.
/// 진한 바탕(번개 무늬) 위에 흰 내비 바 ‹ 제목 ✕, 그 아래 라임/주황 폴더 카드:
/// 배지 · 큰 제목 · ! 한 줄 설명 · 진행 바 · 오른쪽 위 일러스트.
class ResultHero extends StatelessWidget {
  const ResultHero({
    super.key,
    required this.tone,
    required this.navTitle,
    required this.badge,
    required this.title,
    required this.description,
    required this.progress,
    this.onBack,
    this.onClose,
    this.semanticLabel,
  });

  final ResultTone tone;
  final String navTitle;
  final String badge;

  /// 큰 제목 ("86%" 또는 "총 4문제 맞혔어요")
  final Widget title;

  /// 진행 바 위 한 줄 (! 아이콘 + 글자, 또는 누적 정답률)
  final Widget description;

  /// 0~1
  final double progress;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final String? semanticLabel;

  static const _dark = Color(0xFF303237);

  bool get _pass => tone == ResultTone.pass;

  /// 폴더 위 글자색 (라임 위 진한 글자, 주황 위 흰 글자)
  static Color textColor(ResultTone tone) =>
      tone == ResultTone.pass ? const Color(0xFF2B2B2C) : AppColors.white;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: _dark,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 배경: #252525 → #303237, 그 위 초록/적갈 장식 그라데이션, 흐린 번개
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF252525), _dark],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _pass ? const Color(0xFF31481C) : const Color(0xFF5F1901),
                      _dark,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -139,
            top: top - 62 - 152,
            width: 530,
            height: 500,
            child: Image.asset(
              _pass
                  ? 'assets/images/result_bg_pass.png'
                  : 'assets/images/result_bg_fail.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: top),
              _NavRow(title: navTitle, onBack: onBack, onClose: onClose),
              Padding(
                // 피그마: 내비 바 아래 55 에 폴더, 폴더 아래 25 에서 회색 본문 시작
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  55,
                  AppSpacing.screenH,
                  25,
                ),
                child: Semantics(
                  label: semanticLabel,
                  container: true,
                  child: _Folder(
                    tone: tone,
                    badge: badge,
                    title: title,
                    description: description,
                    progress: progress,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, this.onBack, this.onClose});

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.navBarHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.navTitle.copyWith(color: AppColors.white),
              maxLines: 1,
            ),
          ),
          if (onBack != null)
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
                  onTap: onBack,
                  radius: 22,
                  child: const SizedBox(
                    width: AppSizes.minTouch,
                    height: AppSizes.navBarHeight,
                    child: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BackChevron(color: AppColors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (onClose != null)
            Positioned(
              right: AppSpacing.screenH - 10,
              top: 0,
              bottom: 0,
              child: Semantics(
                button: true,
                label: '닫기',
                excludeSemantics: true,
                child: InkResponse(
                  key: const ValueKey('nav-close'),
                  onTap: onClose,
                  radius: 22,
                  child: const SizedBox(
                    width: AppSizes.minTouch,
                    height: AppSizes.navBarHeight,
                    child: Center(
                      child: CustomPaint(
                        size: Size(16, 16),
                        painter: _ClosePainter(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClosePainter extends CustomPainter {
  const _ClosePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(_ClosePainter old) => false;
}

/// 폴더 카드 (362×192, 탭 162 + 곡선 19, 탭 높이 44) + 오른쪽 위로 튀어나온 일러스트
class _Folder extends StatelessWidget {
  const _Folder({
    required this.tone,
    required this.badge,
    required this.title,
    required this.description,
    required this.progress,
  });

  final ResultTone tone;
  final String badge;
  final Widget title;
  final Widget description;
  final double progress;

  static const double height = 192;

  @override
  Widget build(BuildContext context) {
    final pass = tone == ResultTone.pass;
    final folder = pass ? AppColors.point : AppColors.accent;
    final deep = pass ? AppColors.pointText : const Color(0xFF5F2A19);
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FolderCard(
              color: folder,
              tabWidth: 162,
              tabHeight: 44,
              curveWidth: 19,
              radius: AppRadius.button,
              bodyPadding: EdgeInsets.zero,
              tab: const SizedBox.shrink(),
              child: const SizedBox(height: height - 44),
            ),
          ),
          // 일러스트(오른쪽 기준): 불꽃 134×150 (폴더 위 -51) / 느낌표 94×131 + 번개 162×81
          if (pass)
            Positioned(
              right: -2,
              top: -51,
              child: Image.asset(
                'assets/images/result_flame.png',
                width: 134,
                height: 150,
                excludeFromSemantics: true,
              ),
            )
          else ...[
            Positioned(
              right: -16,
              top: -40,
              child: Image.asset(
                'assets/images/result_bolts.png',
                width: 162,
                height: 81,
                excludeFromSemantics: true,
              ),
            ),
            Positioned(
              right: 27,
              top: -20,
              child: Image.asset(
                'assets/images/result_alert.png',
                width: 94,
                height: 131,
                excludeFromSemantics: true,
              ),
            ),
          ],
          Positioned(
            left: 22,
            top: 19,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              decoration: BoxDecoration(
                color: pass ? const Color(0xFFFAFFDF) : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge,
                style: AppTypography.body2Strong.copyWith(
                  color: deep,
                  height: 1.2,
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 18,
            bottom: 25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                const SizedBox(height: AppSpacing.xs),
                description,
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    height: 8,
                    color: AppColors.white,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: deep,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "! 조건을 모두 만족한 좋은 답변이에요" — 검정 원 안 라임/주황 느낌표 + 14 Medium
class ResultAlertLine extends StatelessWidget {
  const ResultAlertLine({super.key, required this.tone, required this.text});

  final ResultTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final pass = tone == ResultTone.pass;
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: Text(
            '!',
            style: AppTypography.caption.copyWith(
              fontWeight: AppTypography.semibold,
              color: pass ? AppColors.point : AppColors.accent,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body2Medium.copyWith(
              color: pass ? const Color(0xFF1E1E1E) : AppColors.white,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
