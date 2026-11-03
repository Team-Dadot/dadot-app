import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 필수 약관에 모두 동의했는지
bool requiredTermsAgreed(List<SignupTerm> terms, Set<String> agreed) =>
    terms.where((t) => t.required).every((t) => agreed.contains(t.id));

/// 약관 동의 묶음: "필수 이용약관에 모두 동의합니다" + 약관마다 한 줄(› 원문).
/// 약관 목록은 서버 앱 설정(GET /v1/app-config signupTerms) 그대로 그린다. 고른 id 를 가입 요청 acceptedTermsIds 로 보낸다.
class TermsChecklist extends ConsumerWidget {
  const TermsChecklist({super.key, required this.terms, required this.agreed, required this.onChanged});

  final List<SignupTerm> terms;
  final Set<String> agreed;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = terms.isNotEmpty && terms.every((t) => agreed.contains(t.id));
    return OutlinedBox(
      radius: AppRadius.button,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Column(
        children: [
          AgreeRow(
            label: terms.any((t) => !t.required) ? '약관에 모두 동의합니다' : '필수 이용약관에 모두 동의합니다',
            strong: true,
            checked: all,
            onTap: () => onChanged(all ? <String>{} : terms.map((t) => t.id).toSet()),
          ),
          const LineDivider(),
          for (final t in terms)
            AgreeRow(
              label: '(${t.required ? '필수' : '선택'}) ${t.title}',
              checked: agreed.contains(t.id),
              onTap: () => onChanged(agreed.contains(t.id) ? ({...agreed}..remove(t.id)) : {...agreed, t.id}),
              onOpen: t.url == null || t.url!.isEmpty ? null : () => unawaited(ref.read(linkServiceProvider).open(t.url!)),
            ),
        ],
      ),
    );
  }
}

/// 약관 한 줄: 글자(+ › 원문 보기) + 오른쪽 체크
class AgreeRow extends StatelessWidget {
  const AgreeRow({super.key, required this.label, required this.checked, required this.onTap, this.onOpen, this.strong = false});

  final String label;
  final bool checked;
  final VoidCallback onTap;

  /// 약관 원문 열기 (›)
  final VoidCallback? onOpen;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? AppTypography.body2Strong.copyWith(color: AppColors.ink)
        : AppTypography.body2Medium.copyWith(color: AppColors.textStrong);
    return Semantics(
      checked: checked,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Flexible(child: Text(label, style: style)),
              if (onOpen != null)
                GestureDetector(
                  onTap: onOpen,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textGuide),
                  ),
                ),
              const Spacer(),
              CheckMark(checked: checked),
            ],
          ),
        ),
      ),
    );
  }
}

/// 소셜 첫 가입 약관 동의 시트 (서버 SIGN_UP_REQUIRED). 동의한 약관 id 를 돌려준다. 닫으면 null.
Future<List<String>?> showTermsSheet(BuildContext context) {
  return showAppSheet<List<String>>(
    context,
    title: '약관 동의',
    expand: true,
    heightFactor: SheetHeights.view,
    builder: (_) => const _TermsSheet(),
  );
}

class _TermsSheet extends ConsumerStatefulWidget {
  const _TermsSheet();

  @override
  ConsumerState<_TermsSheet> createState() => _TermsSheetState();
}

class _TermsSheetState extends ConsumerState<_TermsSheet> {
  Set<String> _agreed = {};

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(serverAppConfigProvider);
    final terms = config.asData?.value.terms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: config.hasError
              ? ErrorView(error: config.error!, onRetry: () => ref.invalidate(serverAppConfigProvider))
              : terms == null
                  ? const LoadingView()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.md),
                      children: [
                        Text('다닷을 시작하려면 약관에 동의해 주세요', style: AppTypography.body2Medium.copyWith(color: AppColors.textSub)),
                        const SizedBox(height: AppSpacing.md),
                        if (terms.isNotEmpty)
                          TermsChecklist(terms: terms, agreed: _agreed, onChanged: (v) => setState(() => _agreed = v)),
                      ],
                    ),
        ),
        BottomCta(color: AppColors.sheet, children: [
          AppButton(
            label: '동의하고 시작하기',
            onPressed: terms == null || !requiredTermsAgreed(terms, _agreed)
                ? null
                : () => Navigator.of(context).pop(_agreed.toList()),
          ),
        ]),
      ],
    );
  }
}
