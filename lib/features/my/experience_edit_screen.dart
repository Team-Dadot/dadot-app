import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 6-6 경험 수정 (1건)
class ExperienceEditScreen extends ConsumerStatefulWidget {
  const ExperienceEditScreen({super.key, required this.experienceId});

  final String experienceId;

  @override
  ConsumerState<ExperienceEditScreen> createState() => _ExperienceEditScreenState();
}

class _ExperienceEditScreenState extends ConsumerState<ExperienceEditScreen> {
  TextEditingController? _title;
  TextEditingController? _content;
  bool _saving = false;

  @override
  void dispose() {
    _title?.dispose();
    _content?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateExperience(
            Experience(id: widget.experienceId, title: _title!.text.trim(), content: _content!.text.trim()),
          );
      ref.invalidate(experiencesProvider);
      if (!mounted) return;
      showToast(context, '경험을 저장했어요.');
      context.pop();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(experiencesProvider);
    final e = list.asData?.value.where((x) => x.id == widget.experienceId).firstOrNull;
    if (e != null && _title == null) {
      _title = TextEditingController(text: e.title);
      _content = TextEditingController(text: e.content);
    }
    final ready = _title != null;
    final valid = ready && _title!.text.trim().isNotEmpty && _content!.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '경험 수정'),
      body: list.hasError
          ? ErrorView(error: list.error!, onRetry: () => ref.invalidate(experiencesProvider))
          : !ready
              ? (list.isLoading ? const LoadingView() : const EmptyView(title: '지워진 경험이에요'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
                  children: [
                    const PageTitle('경험을\n수정해요.'),
                    const SizedBox(height: AppSpacing.gap),
                    const FieldLabel('경험 제목'),
                    const SizedBox(height: AppSpacing.xs),
                    AppTextField(controller: _title!, hint: '경험 제목', onChanged: (_) => setState(() {})),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('경험 내용'),
                    const SizedBox(height: AppSpacing.xs),
                    AppTextField(
                      controller: _content!,
                      hint: '경험 내용',
                      minLines: 6,
                      maxLines: 14,
                      maxLength: AppPolicy.experienceMaxLength,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
      bottomNavigationBar: ready ? BottomCta(children: [AppButton(label: '경험 저장하기', loading: _saving, onPressed: valid ? _save : null)]) : null,
    );
  }
}
