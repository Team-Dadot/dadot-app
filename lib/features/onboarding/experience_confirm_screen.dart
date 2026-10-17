import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'onboarding_common.dart';

/// 1-7 경험 후보 확인. 첫 설정(1-6)과 마이 > 경험 등록(6-5) 둘 다 여기로 온다.
class ExperienceConfirmScreen extends ConsumerStatefulWidget {
  const ExperienceConfirmScreen({super.key, required this.onboarding});

  /// true 면 저장 후 첫 설정을 마치고 홈으로
  final bool onboarding;

  @override
  ConsumerState<ExperienceConfirmScreen> createState() => _ExperienceConfirmScreenState();
}

class _Candidate {
  _Candidate(ExperienceDraft d)
      : title = TextEditingController(text: d.title),
        content = TextEditingController(text: d.content);

  final TextEditingController title;
  final TextEditingController content;
  bool keep = true;

  bool get valid => title.text.trim().isNotEmpty && content.text.trim().isNotEmpty;
}

class _ExperienceConfirmScreenState extends ConsumerState<ExperienceConfirmScreen> {
  late final List<_Candidate> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = [for (final d in ref.read(experienceDraftsProvider)) _Candidate(d)];
  }

  @override
  void dispose() {
    for (final c in _items) {
      c.title.dispose();
      c.content.dispose();
    }
    super.dispose();
  }

  List<_Candidate> get _kept => _items.where((c) => c.keep && c.valid).toList();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).addExperiences([
        for (final c in _kept) ExperienceDraft(title: c.title.text.trim(), content: c.content.text.trim()),
      ]);
      ref.invalidate(experiencesProvider);
      ref.read(experienceDraftsProvider.notifier).set(const []);
      if (widget.onboarding) {
        await ref.read(sessionProvider.notifier).completeOnboarding();
      } else if (mounted) {
        showToast(context, '경험 ${_kept.length}개를 저장했어요.');
        context.go(Routes.myExperiences);
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _kept.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '경험 확인'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const PageTitle('사용할 경험을\n확인해 주세요.', description: 'AI가 나눈 경험이에요. 제목·내용을 고치거나 빼도 돼요.'),
          const SizedBox(height: AppSpacing.gap),
          if (_items.isEmpty) const EmptyView(compact: true, title: '나눌 경험을 찾지 못했어요', description: '뒤로 가서 경험을 조금 더 자세히 적어 주세요.'),
          for (final c in _items) ...[
            OutlinedBox(
              borderColor: AppColors.divider,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    checked: c.keep,
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => c.keep = !c.keep),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                        child: Row(
                          children: [
                            CheckMark(checked: c.keep),
                            const SizedBox(width: AppSpacing.xs),
                            Text('이 경험 저장', style: AppTypography.body2Medium),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: c.title,
                    hint: '경험 제목',
                    maxLength: null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: c.content,
                    hint: '경험 내용',
                    minLines: 3,
                    maxLines: 8,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
          ],
          if (_items.length > AppPolicy.maxExperiences)
            Text('경험은 최대 ${AppPolicy.maxExperiences}개까지 저장할 수 있어요.', style: AppTypography.caption),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '선택한 경험 $count개 저장', loading: _saving, onPressed: count == 0 ? null : _save),
      ]),
    );
  }
}
