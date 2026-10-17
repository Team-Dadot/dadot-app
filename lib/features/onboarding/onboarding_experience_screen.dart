import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'onboarding_common.dart';

/// 1-2 STEP 4/4 내 경험: 경험 제목 + 내용(5,000자) → 저장하고 시작하기 / 건너뛰고 시작하기 → 알림 → 완료
class OnboardingExperienceScreen extends ConsumerStatefulWidget {
  const OnboardingExperienceScreen({super.key});

  @override
  ConsumerState<OnboardingExperienceScreen> createState() => _OnboardingExperienceScreenState();
}

class _OnboardingExperienceScreenState extends ConsumerState<OnboardingExperienceScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _saving = false;

  /// 알림 화면에서 뒤로 와서 다시 누르면 같은 경험을 또 저장하지 않게
  String? _savedKey;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  String get _key => '${_title.text.trim()}\n${_content.text.trim()}';

  bool get _filled => _title.text.trim().isNotEmpty && _content.text.trim().isNotEmpty;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_savedKey == _key) {
      await context.push(Routes.onboardingNotification);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .addExperiences([ExperienceDraft(title: _title.text.trim(), content: _content.text.trim())]);
      ref.invalidate(experiencesProvider);
      _savedKey = _key;
      if (mounted) await context.push(Routes.onboardingNotification);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 4,
      title: '면접에서 꺼낼\n내 경험을 알려주세요.',
      description: '경험을 자유롭게 적어 주세요.',
      bottom: [
        AppButton(label: '저장하고 시작하기', loading: _saving, onPressed: _saving || !_filled ? null : _save),
        AppButton(
          label: '건너뛰고 시작하기',
          variant: AppButtonVariant.secondary,
          onPressed: _saving ? null : () => context.push(Routes.onboardingNotification),
        ),
      ],
      children: [
        const FieldLabel('경험 제목'),
        const SizedBox(height: AppSpacing.xs),
        AppTextField(
          controller: _title,
          hint: '예) 대학 서포터즈 SNS 운영',
          maxLength: AppPolicy.experienceTitleMaxLength,
          showLimitInCounter: false,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.gap),
        const FieldLabel('내 경험'),
        const SizedBox(height: AppSpacing.xs),
        AppTextField(
          controller: _content,
          hint: '경험을 자유롭게 적어 주세요.\n예) 6개월간 브랜드 SNS 계정을 운영하며 콘텐츠 기획을 맡았고, 팔로워를 2배로 늘렸어요.',
          minLines: 6,
          maxLines: 12,
          maxLength: AppPolicy.experienceMaxLength,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.gap),
        Text('경험은 마이 > 내 경험·자소서에서 더 추가하거나 고칠 수 있어요.', style: AppTypography.caption),
      ],
    );
  }
}
