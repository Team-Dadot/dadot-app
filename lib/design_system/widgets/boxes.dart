import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_bars.dart';

/// 회색 원 이미지 자리 (로딩 · 완료 일러스트). 피그마에서 아직 그림이 없는 곳.
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
        decoration: const BoxDecoration(color: AppColors.placeholder, shape: BoxShape.circle),
      ),
    );
  }
}

/// 흰 카드 (모서리 20). 피그마 작업 프레임은 테두리 없이 흰 카드를 쓴다.
/// [borderColor] 를 주면 테두리를 그린다 (선택된 기업 등).
class OutlinedBox extends StatelessWidget {
  const OutlinedBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderColor,
    this.borderWidth = 1,
    this.color = AppColors.surface,
    this.onTap,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double radius;
  final double borderWidth;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: shape,
        border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: shape, child: box));
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
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: child,
    );
  }
}

/// 태그 색
enum TagTone { gray, dark, accent, info }

/// 작은 알약 태그 (객관식, 실적, 보완 필요, 76점 …)
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.dark = false, this.tone});

  final String label;

  /// 차콜 바탕 (면접 집중 모드 배지 등)
  final bool dark;

  /// 주황(보완 필요) · 파랑(완성 답변) 등. 주면 [dark] 보다 우선.
  final TagTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? (dark ? TagTone.dark : TagTone.gray);
    final (Color bg, Color fg, Color? line) = switch (t) {
      TagTone.gray => (AppColors.fillSecondary, AppColors.textBody, null),
      TagTone.dark => (AppColors.primary, AppColors.white, null),
      TagTone.accent => (AppColors.accentSoft, AppColors.accent, AppColors.accent.withValues(alpha: 0.35)),
      TagTone.info => (AppColors.infoSoft, AppColors.info, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: line == null ? null : Border.all(color: line, width: 0.8),
      ),
      child: Text(label, style: AppTypography.microStrong.copyWith(color: fg)),
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

  /// true 면 24 (단계·설정 화면), false 면 22 (탭 화면). 피그마 마이·알림 화면 제목은 24 Bold.
  final bool large;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(text, style: large ? AppTypography.title1 : AppTypography.title2)),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(description!, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// 섹션 제목 + 오른쪽 보조 글자. 기본은 피그마 "나의 학습 현황 · 학습 · 나의 준비 기업" 처럼 16 Medium 회색.
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
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: large
                  ? AppTypography.heading
                  : AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: AppColors.textTertiary),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 입력 항목 이름 (14 Medium 회색 — 피그마 "경험 제목 · 지원 직무")
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.body2Medium.copyWith(color: AppColors.textSecondary));
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
      decoration: BoxDecoration(color: done ? AppColors.primary : AppColors.fillSecondary, shape: BoxShape.circle),
      child: Text(done ? '✓' : label, style: AppTypography.body2Strong.copyWith(color: done ? AppColors.white : AppColors.textPrimary)),
    );
  }
}

/// 흰 카드 안 목록 한 줄 (제목 + 설명 + 오른쪽 값 + ›). 피그마 홈 "기업 퀴즈 0/5 ›", 마이 메뉴.
/// [MenuGroup] 안에 넣으면 줄 사이에 0.5px 선이 들어간다.
class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.title, this.subtitle, this.value, required this.onTap, this.showChevron = true});

  final String title;
  final String? subtitle;

  /// 오른쪽 값 ("0/5", "켜짐")
  final String? value;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTypography.rowTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTypography.caption),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(value!, style: AppTypography.rowTitle.copyWith(color: AppColors.textStrong)),
              ],
              if (showChevron) ...[const SizedBox(width: AppSpacing.xs), const Chevron()],
            ],
          ),
        ),
      ),
    );
  }
}

/// 흰 카드(모서리 20) 안에 [MenuRow] 를 0.5px 선으로 나눠 담는다.
class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm)});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 0.5, width: double.infinity, child: ColoredBox(color: Color(0xFFDCDCDC))),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// "›" 화살표 (20, 회색)
class Chevron extends StatelessWidget {
  const Chevron({super.key, this.color = AppColors.placeholder});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Icon(Icons.chevron_right_rounded, size: 22, color: color));
}

/// 기업 한 줄 — 흰 카드(모서리 20) 안 원 로고 44 + 이름 16 + 설명 12 + 오른쪽 (피그마 6-2 준비 기업 관리)
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

  /// 선택되면 차콜 테두리
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: OutlinedBox(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        borderColor: selected ? AppColors.primary : null,
        borderWidth: 1.5,
        child: Row(
          children: [
            CompanyLogo(name: name, bordered: true),
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
                    Text(extra!, style: AppTypography.captionStrong.copyWith(color: AppColors.accent)),
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

/// 알약 선택 칩 (복습 필터 · 직무). 선택되면 차콜 바탕 흰 글자, 아니면 흰 바탕 회색 글자.
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
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            child: Text(
              label,
              style: selected
                  ? AppTypography.body2Strong.copyWith(color: AppColors.white)
                  : AppTypography.body2Medium.copyWith(color: AppColors.textPlaceholder),
            ),
          ),
        ),
      ),
    );
  }
}

/// 밑줄 탭 (복습: 퀴즈 / 면접). 선택된 칸은 차콜 글자 + 1.4px 차콜 밑줄.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: i == index ? AppColors.primary : const Color(0xFFEBEBEB), width: 1.4),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: AppTypography.subheading.copyWith(
                      letterSpacing: 0.07,
                      color: i == index ? AppColors.primary : const Color(0xFF979797),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 켜기/끄기 스위치 (학습 알림 받기). 이름은 예전 그대로 두고 모양만 둥근 스위치.
class SquareToggle extends StatelessWidget {
  const SquareToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 51,
          height: 31,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? AppColors.primary : AppColors.placeholder,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 27,
            height: 27,
            decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// 체크 표시 — 고르면 라임 원 + 진한 ✓, 아니면 #C5C5C5 테두리 원 (피그마 최종 checkBox 20)
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.checked, this.size = 20});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? AppColors.point : Colors.transparent,
            border: checked ? null : Border.all(color: AppColors.borderLight, width: 1.25),
          ),
          child: checked ? Icon(Icons.check_rounded, size: size * 0.7, color: AppColors.ink) : null,
        ),
      );
}

/// "▾" 표시 (Noto Sans KR 에 글자가 없어 아이콘으로)
class DropdownMark extends StatelessWidget {
  const DropdownMark({super.key});

  @override
  Widget build(BuildContext context) =>
      const ExcludeSemantics(child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textPrimary));
}
