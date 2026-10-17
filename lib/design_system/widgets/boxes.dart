import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 회색 이미지 자리 (로고 · 프로필 · 로딩 일러스트). 피그마에서 아직 그림이 없는 곳.
class LogoBox extends StatelessWidget {
  const LogoBox({super.key, this.size = AppSizes.logoTile, this.label = '로고'});

  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        color: AppColors.placeholder,
        alignment: Alignment.center,
        child: label.isEmpty ? null : Text(label, style: AppTypography.micro, maxLines: 1),
      ),
    );
  }
}

/// 테두리 박스 (카드). 피그마 기본 테두리 #BFBFBF 1px.
class OutlinedBox extends StatelessWidget {
  const OutlinedBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderColor = AppColors.border,
    this.borderWidth = 1,
    this.color = AppColors.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final double borderWidth;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color, border: Border.all(color: borderColor, width: borderWidth)),
      child: child,
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, child: box));
  }
}

/// 회색 안내 박스 (해설, 변환된 내용, 알림 예시)
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.md)});

  /// 글자만 넣을 때
  InfoBox.text(String text, {super.key, this.padding = const EdgeInsets.all(AppSpacing.md)})
      : child = Text(text, style: AppTypography.caption.copyWith(color: AppColors.textSub));

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: padding, color: AppColors.surfaceMuted, child: child);
  }
}

/// 작은 회색 태그 (객관식, 실적, 보완 필요 …)
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.dark = false});

  final String label;

  /// 검정 바탕 (면접 집중 모드 배지 등)
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      color: dark ? AppColors.primary : AppColors.fillSecondary,
      child: Text(label, style: AppTypography.microStrong.copyWith(color: dark ? AppColors.white : AppColors.textBody)),
    );
  }
}

/// 태그 여러 개 (간격 6)
class TagRow extends StatelessWidget {
  const TagRow(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: [for (final l in labels) TagChip(l)]);
  }
}

/// 1px 구분선
class LineDivider extends StatelessWidget {
  const LineDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: AppColors.divider));
}

/// 화면 상단 큰 제목 (24 Bold 또는 22 Bold)
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.large = true, this.description});

  final String text;

  /// true 면 24 (단계·설정 화면), false 면 22 (탭 화면)
  final bool large;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(text, style: large ? AppTypography.title1 : AppTypography.title2)),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.gap),
          Text(description!, style: AppTypography.body1.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// 섹션 제목 (16 Bold) + 오른쪽 보조 글자
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.large = false});

  final String text;
  final Widget? trailing;

  /// 17 Bold (홈 "오늘의 학습")
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Semantics(header: true, child: Text(text, style: large ? AppTypography.heading : AppTypography.subheading))),
        ?trailing,
      ],
    );
  }
}

/// 입력 항목 이름 (13 Bold)
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppTypography.body2Strong);
}

/// 번호 박스 (홈 오늘의 학습 1 / 2, 완료되면 ✓)
class IndexBox extends StatelessWidget {
  const IndexBox({super.key, required this.label, this.done = false});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.indexBox,
      height: AppSizes.indexBox,
      alignment: Alignment.center,
      color: done ? AppColors.primary : AppColors.fillSecondary,
      child: Text(done ? '✓' : label, style: AppTypography.body2Strong.copyWith(color: done ? AppColors.white : AppColors.textPrimary)),
    );
  }
}

/// 마이 화면 목록 한 줄 (제목 + 설명 + ›), 아래 구분선 포함
class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.title, this.subtitle, required this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.card),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.rowTitle),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppTypography.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Chevron(),
              ],
            ),
          ),
        ),
        const LineDivider(),
      ],
    );
  }
}

/// "›" 화살표
class Chevron extends StatelessWidget {
  const Chevron({super.key});

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Text('›', style: AppTypography.subheading.copyWith(fontWeight: AppTypography.regular, color: AppColors.textSecondary)));
}

/// 기업 한 줄 (로고 40 + 이름 15 Bold + 설명 12 + 오른쪽)
class CompanyTile extends StatelessWidget {
  const CompanyTile({
    super.key,
    required this.name,
    this.subtitle,
    this.extra,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final String name;
  final String? subtitle;

  /// 셋째 줄 (전환 시트 "오늘 8개 남음")
  final String? extra;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 선택되면 테두리 #212121, 아니면 #D9D9D9
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: OutlinedBox(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.card),
        borderColor: selected ? AppColors.primary : AppColors.divider,
        borderWidth: 1,
        child: Row(
          children: [
            const LogoBox(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.cardTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTypography.caption),
                  ],
                  if (extra != null) ...[
                    const SizedBox(height: 2),
                    Text(extra!, style: AppTypography.captionStrong),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 선택 칩 (문의 종류, 복습 필터, 직무). 선택되면 검정 바탕.
class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label, style: AppTypography.body2.copyWith(color: selected ? AppColors.white : AppColors.textPrimary)),
        ),
      ),
    );
  }
}

/// 두 칸 탭 (퀴즈 복습 / 면접 복습)
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.fillChoice,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    color: i == index ? AppColors.surface : Colors.transparent,
                    child: Text(
                      labels[i],
                      style: i == index ? AppTypography.body1Strong : AppTypography.body1.copyWith(color: AppColors.textSecondary),
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

/// 네모 스위치 (학습 알림 받기)
class SquareToggle extends StatelessWidget {
  const SquareToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.primary : AppColors.surface,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 20, color: value ? AppColors.white : AppColors.primary),
        ),
      ),
    );
  }
}

/// 체크 표시 (■ / □) — 기업 선택, 경험 저장
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Text(checked ? '■' : '□', style: AppTypography.body2Medium.copyWith(color: AppColors.textStrong)),
      );
}

/// "▾" 표시 (Noto Sans KR 에 글자가 없어 아이콘으로)
class DropdownMark extends StatelessWidget {
  const DropdownMark({super.key});

  @override
  Widget build(BuildContext context) =>
      const ExcludeSemantics(child: Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textPrimary));
}
