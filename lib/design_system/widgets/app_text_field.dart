import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 공통 입력창. 피그마 작업 프레임: 흰 바탕, 테두리 없음, 모서리 16, 안쪽 20·16.
/// [maxLength] 를 주면 상자 안 오른쪽 아래에 "0 / 10,000자" 카운터가 보인다.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.autofocus = false,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.counterSuffix = '자',
    this.showLimitInCounter = true,
    this.textStyle,
    this.semanticLabel,
    this.errorText,
    this.trailing,
    this.focusNode,
    this.onSubmitted,
    this.bordered = false,
    this.clearable = false,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  /// 읽기 전용이면 회색 바탕 (로그인 이메일 등)
  final bool readOnly;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String counterSuffix;

  /// false 면 "0자" 처럼 최대값 없이
  final bool showLimitInCounter;
  final TextStyle? textStyle;
  final String? semanticLabel;

  /// 피그마 이메일 가입 2: 빨간 ! 표시 + 아래 빨간 안내 글자
  final String? errorText;

  /// 한 줄 입력창 오른쪽 (검색 🔍 · 지우기 ✕)
  final Widget? trailing;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  /// 피그마 이메일 로그인·가입 (1164:6116 · 1164:6203): 회색 1px 테두리 · 모서리 12 · 높이 52.
  /// 틀리면 빨간 테두리 + 아래 빨간 안내 (오른쪽 ! 표시 없음)
  final bool bordered;

  /// 글자가 있으면 오른쪽에 회색 원 ✕ (16, #DCE0E7) — 누르면 지운다 (피그마 1164:6116 이메일 로그인)
  final bool clearable;

  static String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    if (!clearable || trailing != null || maxLines > 1 || readOnly) return _build(context, trailing);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => _build(
        context,
        value.text.isEmpty
            ? null
            : Semantics(
                button: true,
                label: '${semanticLabel ?? '입력'} 지우기',
                excludeSemantics: true,
                child: InkResponse(
                  radius: 18,
                  onTap: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                  child: const SizedBox(width: 24, height: 24, child: Center(child: ClearCircleIcon())),
                ),
              ),
      ),
    );
  }

  Widget _build(BuildContext context, Widget? trailing) {
    final multiline = maxLines > 1;
    final style = textStyle ?? (multiline ? AppTypography.body1.copyWith(color: AppColors.textStrong, height: 1.6) : AppTypography.body1);
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      readOnly: readOnly,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      obscureText: obscureText,
      textInputAction: textInputAction ?? (multiline ? TextInputAction.newline : TextInputAction.done),
      keyboardType: keyboardType ?? (multiline ? TextInputType.multiline : null),
      style: readOnly ? style.copyWith(color: AppColors.textPlaceholder) : style,
      cursorColor: AppColors.primary,
      inputFormatters: maxLength == null ? null : [LengthLimitingTextInputFormatter(maxLength)],
      decoration: InputDecoration(
        hintText: hint,
        hintMaxLines: 6,
        hintStyle: style.copyWith(color: AppColors.textPlaceholder),
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );

    final hasError = errorText != null && errorText!.isNotEmpty;
    final Widget? side = hasError && !bordered
        ? const ExcludeSemantics(child: Icon(Icons.error_rounded, size: 18, color: AppColors.destructive))
        : trailing;
    final box = Semantics(
      label: semanticLabel,
      textField: true,
      child: Container(
        constraints: BoxConstraints(minHeight: multiline ? 0 : (bordered ? 52 : AppSizes.inputHeight)),
        padding: EdgeInsets.symmetric(horizontal: bordered ? 15 : AppSpacing.lg, vertical: multiline ? AppSpacing.lg : AppSpacing.sm),
        decoration: BoxDecoration(
          color: readOnly ? AppColors.surfaceMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(bordered ? 12 : (multiline ? AppRadius.lg : AppRadius.md)),
          border: bordered ? Border.all(color: hasError ? AppColors.destructive : const Color(0xFFE9EBED)) : null,
        ),
        alignment: multiline ? null : Alignment.centerLeft,
        child: maxLength == null
            ? (side == null || multiline ? field : Row(children: [Expanded(child: field), const SizedBox(width: AppSpacing.xs), side]))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field,
                  const SizedBox(height: AppSpacing.xs),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, _) {
                      final n = value.text.characters.length;
                      return Text(
                        showLimitInCounter ? '${_comma(n)} / ${_comma(maxLength!)}$counterSuffix' : '${_comma(n)}$counterSuffix',
                        textAlign: TextAlign.right,
                        style: AppTypography.micro,
                      );
                    },
                  ),
                ],
              ),
      ),
    );
    if (!hasError) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        SizedBox(height: bordered ? 4 : 6),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: EdgeInsets.only(left: bordered ? 0 : AppSpacing.xxs),
            child: Text(errorText!, style: AppTypography.caption.copyWith(color: AppColors.destructive)),
          ),
        ),
      ],
    );
  }
}

/// 회색 원 안 흰 ✕ (16×16, 원 #DCE0E7 · 선 1.5)
class ClearCircleIcon extends StatelessWidget {
  const ClearCircleIcon({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(size: Size(16, 16), painter: _ClearCirclePainter());
}

class _ClearCirclePainter extends CustomPainter {
  const _ClearCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width / 2, Paint()..color = const Color(0xFFDCE0E7));
    final p = Paint()
      ..color = AppColors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const h = 2.5;
    canvas.drawLine(c.translate(-h, -h), c.translate(h, h), p);
    canvas.drawLine(c.translate(h, -h), c.translate(-h, h), p);
  }

  @override
  bool shouldRepaint(_ClearCirclePainter old) => false;
}

/// 검색창 (피그마 1-2 "기업 이름을 검색해보세요 🔍" · 6-2 "새로운 기업 추가하기"). 글자가 있으면 ✕ 로 지운다.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    required this.hint,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  /// [onTap] 으로 쓰면 없어도 된다
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  /// 주면 입력 대신 눌러서 검색 화면으로 간다
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return Semantics(
        button: true,
        label: hint,
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: AppSizes.inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(child: Text(hint, style: AppTypography.body1.copyWith(color: AppColors.textPlaceholder))),
                  const Icon(Icons.search_rounded, size: 22, color: AppColors.textCaption),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final controller = this.controller!;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, _) => AppTextField(
        controller: controller,
        focusNode: focusNode,
        hint: hint,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        trailing: value.text.isEmpty
            ? const ExcludeSemantics(child: Icon(Icons.search_rounded, size: 22, color: AppColors.textCaption))
            : Semantics(
                button: true,
                label: '검색어 지우기',
                child: InkResponse(
                  radius: 18,
                  onTap: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                  child: const Icon(Icons.close_rounded, size: 22, color: AppColors.textStrong),
                ),
              ),
      ),
    );
  }
}

/// 눌러서 고르는 입력칸 (지원 직무 ›, 면접일 달력)
class SelectField extends StatelessWidget {
  const SelectField({super.key, required this.value, required this.placeholder, required this.onTap, this.trailing = '›'});

  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.isEmpty;
    return Semantics(
      button: true,
      label: empty ? placeholder : value,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: AppSizes.inputHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  empty ? placeholder : value!,
                  style: AppTypography.body1.copyWith(color: empty ? AppColors.textPlaceholder : AppColors.textPrimary),
                ),
              ),
              if (trailing == '›')
                const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.placeholder)
              else
                Text(trailing, style: AppTypography.body2Medium.copyWith(color: AppColors.textPlaceholder)),
            ],
          ),
        ),
      ),
    );
  }
}
