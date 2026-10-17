import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../design_system/design_system.dart';
import '../onboarding/onboarding_common.dart';

/// 6-5 경험 추가 (파일 첨부 / 직접 입력) → 1-7 경험 후보 확인
class ExperienceAddScreen extends ConsumerStatefulWidget {
  const ExperienceAddScreen({super.key, this.initialText});

  /// 피드백 화면 "이 답변의 경험을 내 경험에 추가" 에서 넘어온 답변
  final String? initialText;

  @override
  ConsumerState<ExperienceAddScreen> createState() => _ExperienceAddScreenState();
}

class _ExperienceAddScreenState extends ConsumerState<ExperienceAddScreen> {
  late final _text = TextEditingController(text: widget.initialText ?? '');
  bool _splitting = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _split() async {
    FocusScope.of(context).unfocus();
    setState(() => _splitting = true);
    try {
      final drafts = await ref.read(profileRepositoryProvider).splitExperiences(_text.text);
      ref.read(experienceDraftsProvider.notifier).set(drafts);
      if (mounted) await context.push(Routes.myExperienceConfirm);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _splitting = false);
    }
  }

  void _attach() {
    // TODO(백엔드): 파일 업로드·분석 API 가 생기면 file_picker 로 연결
    showToast(context, '파일 첨부는 준비 중이에요. 지금은 내용을 붙여 넣어 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '경험 추가'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const PageTitle('면접에서 꺼낼\n내 경험을 알려주세요.', description: '자소서·이력서를 첨부하거나 경험을 자유롭게 적어 주세요.'),
          const SizedBox(height: AppSpacing.gap),
          Semantics(
            button: true,
            label: '자소서·이력서 파일 첨부. PDF, Word, 한글, TXT, 10MB까지',
            excludeSemantics: true,
            child: InkWell(
              onTap: _attach,
              child: CustomPaint(
                painter: _DashedBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Text('＋', style: AppTypography.title3.copyWith(fontWeight: AppTypography.regular)),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('자소서·이력서 파일 첨부', style: AppTypography.body1Strong),
                          const SizedBox(height: 2),
                          Text('PDF · Word · 한글 · TXT, 10MB까지', style: AppTypography.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          Text('또는 직접 입력', textAlign: TextAlign.center, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.gap),
          AppTextField(
            controller: _text,
            hint: '경험을 자유롭게 적어 주세요. 여러 개를 한 번에 적어도 돼요.',
            minLines: 7,
            maxLines: 14,
            maxLength: AppPolicy.experienceMaxLength,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.gap),
          Text('AI가 경험별로 나눠서 보여드려요. 확인한 경험만 저장돼요.', style: AppTypography.caption),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '경험 나눠서 확인하기  →', loading: _splitting, onPressed: _text.text.trim().isEmpty ? null : _split),
      ]),
    );
  }
}

/// 점선 테두리 (파일 첨부 상자)
class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    const gap = 3.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (var d = 0.0; d < total; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, total), paint);
      }
    }

    final r = Offset.zero & size;
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
