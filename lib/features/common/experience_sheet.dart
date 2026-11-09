import 'package:flutter/material.dart';

import '../../core/config/app_policy.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';

/// 피그마 최종 "내 경험 추가하기" 시트 (942:4460 · 763:17198): 경험 제목 + 내용 + 추가하기.
/// 첫 설정 STEP 4 · 마이 > 내 경험이 같이 쓴다. 고치기면 [initial] 과 [confirmLabel] 을 넘긴다.
Future<ExperienceDraft?> showExperienceSheet(
  BuildContext context, {
  String title = '내 경험 추가하기',
  ExperienceDraft? initial,
  String confirmLabel = '추가하기',
}) {
  return showAppSheet<ExperienceDraft>(
    context,
    title: title,
    expand: true,
    heightFactor: SheetHeights.form,
    builder: (_) => _ExperienceForm(initial: initial, confirmLabel: confirmLabel),
  );
}

class _ExperienceForm extends StatefulWidget {
  const _ExperienceForm({this.initial, required this.confirmLabel});

  final ExperienceDraft? initial;
  final String confirmLabel;

  @override
  State<_ExperienceForm> createState() => _ExperienceFormState();
}

class _ExperienceFormState extends State<_ExperienceForm> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _content = TextEditingController(text: widget.initial?.content ?? '');

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool get _filled => _title.text.trim().isNotEmpty && _content.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.md),
            children: [
              const FieldLabel('경험 제목'),
              const SizedBox(height: AppSpacing.xs),
              AppTextField(
                controller: _title,
                hint: '제목을 입력해주세요',
                maxLength: null,
                // QA: 키보드는 칸을 눌렀을 때만 (자동으로 올리지 않는다)
                onChanged: (_) => setState(() {}),
                semanticLabel: '경험 제목',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _content,
                hint: '경험을 자유롭게 적어 주세요.',
                minLines: 9,
                maxLines: 14,
                maxLength: AppPolicy.experienceMaxLength,
                showLimitInCounter: false,
                onChanged: (_) => setState(() {}),
                semanticLabel: '경험 내용',
              ),
            ],
          ),
        ),
        BottomCta(
          color: AppColors.sheet,
          children: [
            AppButton(
              label: widget.confirmLabel,
              onPressed: !_filled
                  ? null
                  : () => Navigator.of(context).pop(ExperienceDraft(title: _title.text.trim(), content: _content.text.trim())),
            ),
          ],
        ),
      ],
    );
  }
}

/// 경험 한 줄 카드 — 제목 + ⌄. 누르면 펼쳐서 내용 (첫 설정 "추가한 내 경험")
class ExperienceAccordion extends StatefulWidget {
  const ExperienceAccordion({super.key, required this.experience});

  final Experience experience;

  @override
  State<ExperienceAccordion> createState() => _ExperienceAccordionState();
}

class _ExperienceAccordionState extends State<ExperienceAccordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.experience;
    return OutlinedBox(
      radius: AppRadius.button,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 18),
                child: Row(
                  children: [
                    Expanded(child: Text(e.title, style: AppTypography.cardTitle.copyWith(color: AppColors.ink))),
                    ExcludeSemantics(
                      child: Icon(
                        _open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.statusIcon,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: LineDivider()),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: Text(e.content, style: AppTypography.body1.copyWith(color: AppColors.textSub, height: 1.6)),
            ),
          ],
        ],
      ),
    );
  }
}

/// "+ 내 경험 추가하기 / 경험을 추가하고 맞춤형 질문을 받아요" 카드
class AddExperienceCard extends StatelessWidget {
  const AddExperienceCard({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '내 경험 추가하기. 경험을 추가하고 맞춤형 질문을 받아요',
      excludeSemantics: true,
      child: OutlinedBox(
        radius: AppRadius.button,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.cardDark, shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: AppColors.white, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('내 경험 추가하기', style: AppTypography.body2Strong.copyWith(color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('경험을 추가하고 맞춤형 질문을 받아요', style: AppTypography.caption.copyWith(color: AppColors.textCaption)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
