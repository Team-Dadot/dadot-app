import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 확인 팝업 (피그마 최종 3-E6 · 6-E6): 흰 카드 모서리 16, 라임 ⚠, 가운데 제목 20 · 설명 16, 버튼 두 개(높이 48, 모서리 12).
/// 확인을 누르면 true. [warning] 이면 위에 ⚠ 아이콘.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool warning = false,
}) async {
  final result = await showChoiceDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    warning: warning,
  );
  return result ?? false;
}

/// [showConfirmDialog] 와 같은 팝업. 오른쪽(차콜) = true, 왼쪽(회색) = false, 바깥을 눌러 닫으면 null.
/// 왼쪽 버튼이 실제 동작인 경우(퀴즈 "그만하기 / 진행하기")에 쓴다.
Future<bool?> showChoiceDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool warning = false,
}) {
  Widget button(String label, {required bool primary, required VoidCallback onTap}) => SizedBox(
        height: AppSizes.buttonHeightDialog,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: primary ? AppColors.ink : AppColors.fillMuted,
            foregroundColor: primary ? AppColors.white : AppColors.textSub,
            textStyle: AppTypography.buttonSmall.copyWith(fontWeight: primary ? AppTypography.bold : AppTypography.semibold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialogButton)),
            splashFactory: NoSplash.splashFactory,
          ),
          child: Text(label),
        ),
      );

  return showDialog<bool>(
    context: context,
    barrierColor: AppColors.scrimStrong,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            if (warning) ...[
              Image.asset('assets/images/icons/warning.png', width: 48, height: 48, excludeFromSemantics: true),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(title, textAlign: TextAlign.center, style: AppTypography.title4.copyWith(color: AppColors.ink)),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.textSub),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: button(cancelLabel, primary: false, onTap: () => Navigator.of(context).pop(false))),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: button(confirmLabel, primary: true, onTap: () => Navigator.of(context).pop(true))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 피그마 바텀 시트 (바탕 #F1F1F1, 위 모서리 20, 가운데 제목 16 + 오른쪽 ✕). 결과를 돌려받으려면 Navigator.pop(context, value).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.sheet,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    clipBehavior: Clip.antiAlias,
    builder: (context) {
      final media = MediaQuery.of(context);
      final content = Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.xs, AppSpacing.sm),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Semantics(
                      header: true,
                      child: Text(title, textAlign: TextAlign.center, style: AppTypography.subheading.copyWith(color: AppColors.cardDark)),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 24, color: AppColors.cardDark),
                    ),
                  ),
                ],
              ),
            ),
            if (expand) Expanded(child: builder(context)) else Flexible(child: builder(context)),
          ],
        ),
      );
      return expand ? SizedBox(height: media.size.height * 0.85, child: content) : content;
    },
  );
}

/// 하단 토스트 메시지
void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      duration: const Duration(seconds: 3),
    ));
}

/// 오류 토스트
void showErrorToast(BuildContext context, Object error) => showToast(context, asAppException(error).userMessage);
