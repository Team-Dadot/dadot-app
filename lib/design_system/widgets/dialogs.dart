import 'package:flutter/material.dart';

import 'toast.dart';

import '../../core/error/app_exception.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 확인 팝업 (피그마 최종 3-E6 · 6-E6 1393:12542): 흰 카드 모서리 16, 라임 ⚠, 가운데 제목 20 · 설명 16, 버튼 두 개(높이 52, 모서리 12, 글자 18).
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
  Widget button(String label, {required bool primary, required VoidCallback onTap}) =>
      _DialogButton(label: label, primary: primary, onTap: onTap);

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
            Text(title, textAlign: TextAlign.center, style: _dialogTitle),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(message, textAlign: TextAlign.center, style: _dialogMessage),
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

/// 팝업 글자 (피그마 Title/Section 20 SemiBold #15171B · Body/Default 16 Medium #55565A, 줄 140% · 자간 -3%)
final TextStyle _dialogTitle = AppTypography.title4.copyWith(color: AppColors.ink, height: 1.4, letterSpacing: -0.6);
final TextStyle _dialogMessage =
    AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.textSub, height: 1.4, letterSpacing: -0.48);

/// 팝업 버튼 (피그마 1393:12549 · 1273:11620): 높이 52 · 모서리 12 · Button/Large 18 SemiBold (자간 -0.54).
/// 주 버튼은 #15171B 바탕 흰 글자, 보조 버튼은 #DCE0E7 바탕 #55565A 글자.
/// (QA 763:17902: 글자가 14 로 나와 디자인보다 작았다)
class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.label, required this.primary, required this.onTap});

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: primary ? AppColors.ink : AppColors.fillMuted,
            foregroundColor: primary ? AppColors.white : AppColors.textSub,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            textStyle: AppTypography.button.copyWith(letterSpacing: -0.54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialogButton)),
            splashFactory: NoSplash.splashFactory,
          ),
          child: Text(label, maxLines: 1),
        ),
      );
}

/// 버튼 하나짜리 안내 팝업 (피그마 1-E3 "준비 기업 5개를 모두 채웠어요 · 닫기")
Future<void> showNoticeDialog(
  BuildContext context, {
  required String title,
  String? message,
  String buttonLabel = '닫기',
  bool warning = true,
}) {
  return showDialog<void>(
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
            Text(title, textAlign: TextAlign.center, style: _dialogTitle),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(message, textAlign: TextAlign.center, style: _dialogMessage),
            ],
            const SizedBox(height: 28),
            _DialogButton(label: buttonLabel, primary: true, onTap: () => Navigator.of(context).pop()),
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
  double heightFactor = SheetHeights.tall,
}) {
  return showBareSheet<T>(
    context,
    expand: expand,
    heightFactor: heightFactor,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title),
        if (expand) Expanded(child: builder(context)) else Flexible(child: builder(context)),
      ],
    ),
  );
}

/// 높이를 정해 두는 시트([expand])의 높이 — 피그마 874 높이 화면에서 잰 비율
class SheetHeights {
  SheetHeights._();

  /// 6-3 직무 선택 시트 (678 / 874)
  static const double tall = 0.78;

  /// 문제 해설 시트 (피그마 1337:10093 — 665 / 874)
  static const double explain = 665 / 874;

  /// 내 경험 추가하기 시트 (542 / 874)
  static const double form = 0.62;

  /// 내 경험 보기 시트 (502 / 874)
  static const double view = 0.57;
}

/// 제목 줄 없이 시트만 띄운다 (달력 · 직무 선택처럼 머리를 직접 그리는 시트). 키보드가 올라오면 그만큼 올라간다.
/// [expand] 면 화면 높이의 [heightFactor] 만큼, 아니면 내용 높이만큼.
Future<T?> showBareSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool expand = false,
  double heightFactor = SheetHeights.tall,
  Color color = AppColors.sheet,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: color,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    clipBehavior: Clip.antiAlias,
    builder: (context) {
      final media = MediaQuery.of(context);
      final content = Padding(padding: EdgeInsets.only(bottom: media.viewInsets.bottom), child: builder(context));
      // 키보드가 올라오면 시트 내용이 눌리지 않게 키보드 높이만큼 더 올린다 (화면 위 안전 영역에서 멈춤)
      return expand ? SizedBox(height: media.size.height * heightFactor + media.viewInsets.bottom, child: content) : content;
    },
  );
}

/// 시트 머리: 가운데 제목 16 SemiBold, 왼쪽 ‹ (있을 때), 오른쪽 ✕
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.onBack, this.onClose});

  final String title;

  /// 주면 왼쪽에 ‹ (직무 시트 안 분류 → 처음으로)
  final VoidCallback? onBack;

  /// 기본은 시트 닫기
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, AppSpacing.sm),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: AppTypography.subheading.copyWith(color: AppColors.cardDark)),
            ),
          ),
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: '뒤로',
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.cardDark),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '닫기',
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, size: 24, color: AppColors.cardDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 토스트 메시지 (하단 버튼이 있으면 그 위에 뜬다 — [AppToast])
void showToast(BuildContext context, String message) => AppToast.show(context, Text(message));

/// 완료 안내 토스트 (피그마 1074:12476 "✓ 준비 중인 기업이 2개 추가되었어요   확인"): 진한 바탕 + 라임 체크 + 라임 "확인"
void showDoneToast(BuildContext context, String message, {String actionLabel = '확인'}) => AppToast.show(
      context,
      Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: AppColors.point, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 13, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(message)),
        ],
      ),
      actionLabel: actionLabel,
      background: AppColors.cardDark,
    );

/// 안내 토스트 (피그마 회원가입 helpertext 1435:11283 — 진한 바탕 + 라임 ! 아이콘 + 14 Medium 흰 글자)
void showInfoToast(BuildContext context, String message) => AppToast.show(
      context,
      Row(
        children: [
          const ExcludeSemantics(child: Icon(Icons.error_rounded, size: 16, color: AppColors.point)),
          const SizedBox(width: 6),
          Expanded(child: Text(message)),
        ],
      ),
    );

/// 오류 토스트
void showErrorToast(BuildContext context, Object error) => showToast(context, asAppException(error).userMessage);
