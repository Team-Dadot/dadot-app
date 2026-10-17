import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_button.dart';

/// 확인 팝업. 확인을 누르면 true. (피그마 예외 프레임이 비어 있어 시트 톤으로 맞춤)
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.title4),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(message, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.ctaGap),
                Expanded(child: AppButton(label: confirmLabel, onPressed: () => Navigator.of(context).pop(true))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// 피그마 바텀 시트 (손잡이 + 제목 + ✕). 결과를 돌려받으려면 Navigator.pop(context, value).
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
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(),
    builder: (context) {
      final media = MediaQuery.of(context);
      final content = Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Center(child: Container(width: 36, height: 4, color: AppColors.divider)),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.xs, AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: Semantics(header: true, child: Text(title, style: AppTypography.title4))),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22, color: AppColors.textPrimary),
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
      duration: const Duration(seconds: 3),
    ));
}

/// 오류 토스트
void showErrorToast(BuildContext context, Object error) => showToast(context, asAppException(error).userMessage);
