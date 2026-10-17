import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 공통 입력창. 피그마: 흰 바탕, #BFBFBF 1px 테두리, 모서리 없음, 안쪽 14.
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

  static String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    final style = textStyle ?? (multiline ? AppTypography.body2.copyWith(color: AppColors.textPrimary) : AppTypography.body1);
    final field = TextField(
      controller: controller,
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

    return Semantics(
      label: semanticLabel,
      textField: true,
      child: Container(
        constraints: BoxConstraints(minHeight: multiline ? 0 : AppSizes.inputHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: readOnly ? AppColors.surfaceMuted : AppColors.surface,
          border: Border.all(color: readOnly ? AppColors.divider : AppColors.border),
        ),
        alignment: multiline ? null : Alignment.centerLeft,
        child: maxLength == null
            ? field
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
        child: Container(
          height: AppSizes.inputHeight + 4,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card),
          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  empty ? placeholder : value!,
                  style: AppTypography.body1.copyWith(color: empty ? AppColors.textPlaceholder : AppColors.textPrimary),
                ),
              ),
              Text(trailing, style: AppTypography.body2Medium),
            ],
          ),
        ),
      ),
    );
  }
}
