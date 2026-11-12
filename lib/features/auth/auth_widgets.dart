import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/design_system.dart';

/// 입력창 오른쪽 작은 버튼 (피그마 Button/Small 1435:11509 · 68×32 · 모서리 8 · 12 SemiBold, 자간 -0.36).
/// 누를 수 있으면 검정(#15171B) 바탕 흰 글자, 못 누르면 #E9EBED 바탕 #303137 글자.
/// [accent] 는 라임 바탕 "인증 완료" 표시 (피그마 시안2 1435:11447) — 누르는 버튼이 아니다.
class InlineAction extends StatelessWidget {
  const InlineAction({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.accent = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool accent;

  /// 피그마 1526:9502 "재요청": 흰 바탕 + 옅은 선 + 진한 글자
  final bool outlined;

  /// 피그마 Button/Small 회색(#E9EBED) · 글자 #303137
  static const Color _mutedFill = Color(0xFFE9EBED);
  static const Color _mutedLabel = Color(0xFF303137);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        width: 68,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    final enabled = onTap != null;
    final chip = Container(
      width: 68,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: outlined ? AppColors.surface : (accent ? AppColors.point : (enabled ? AppColors.ink : _mutedFill)),
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: const Color(0xFFDEDFE1)) : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.captionStrong.copyWith(
          color: outlined ? _mutedLabel : (accent ? AppColors.ink : (enabled ? AppColors.white : _mutedLabel)),
          letterSpacing: -0.36,
        ),
      ),
    );
    if (accent) {
      return Semantics(label: label, child: ExcludeSemantics(child: chip));
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        behavior: HitTestBehavior.opaque,
        child: chip,
      ),
    );
  }
}

/// 입력칸 오른쪽 "다 됐어요" 체크 (피그마 Radio_large 1435:11679 — 20×20, 선 #9A9DA4 두께 1.875)
class FieldCheckIcon extends StatelessWidget {
  const FieldCheckIcon({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(width: 20, height: 20, child: CustomPaint(painter: _FieldCheckPainter())),
  );
}

class _FieldCheckPainter extends CustomPainter {
  const _FieldCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(14.25, 7.5)
        ..lineTo(8.9167, 12.5)
        ..lineTo(6.25, 10),
      Paint()
        ..color = AppColors.textGuide
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.875
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FieldCheckPainter old) => false;
}

/// 입력칸 오른쪽 지우기 ✕ (회색 원 16, 피그마 Group 1321315632)
class FieldClearButton extends StatelessWidget {
  const FieldClearButton({super.key, required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: InkResponse(
      radius: 18,
      onTap: onTap,
      child: const SizedBox(width: 24, height: 24, child: Center(child: ClearCircleIcon())),
    ),
  );
}

/// 입력칸 오른쪽 표시 (피그마 회원가입): 비어 있으면 없음 · 다 맞으면 회색 ✓ · 아니면 지우기 ✕
Widget? fieldMark({
  required TextEditingController controller,
  required bool valid,
  required String label,
  required VoidCallback onCleared,
}) {
  if (controller.text.isEmpty) return null;
  if (valid) return const FieldCheckIcon();
  return FieldClearButton(
    semanticLabel: '$label 지우기',
    onTap: () {
      controller.clear();
      onCleared();
    },
  );
}
