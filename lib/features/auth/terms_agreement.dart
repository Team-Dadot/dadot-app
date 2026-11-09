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

/// 앱에서만 받는 개인정보 수집·이용 동의 줄 id (서버 acceptedTermsIds 에는 보내지 않는다)
const privacyTermId = 'privacy';

/// 화면에 그릴 약관: 서버 약관(SERVICE_TERMS) + 피그마의 "(필수) 개인정보 수집 및 이용 동의" 줄.
/// 서버는 개인정보 처리방침을 동의 대상이 아닌 안내 링크(privacyPolicyUrl)로 준다 → 앱에서 필수 체크로만 받는다.
List<SignupTerm> displayTerms(ServerAppConfig config) {
  if (config.terms.isEmpty) return const [];
  return [
    ...config.terms,
    if (!config.terms.any((t) => t.title.contains('개인정보')))
      SignupTerm(
        id: privacyTermId,
        title: '개인정보 수집 및 이용 동의',
        required: true,
        url: config.privacyPolicyUrl,
      ),
  ];
}

/// 서버로 보낼 약관 id (앱 전용 줄은 뺀다)
List<String> serverTermIds(Set<String> agreed) =>
    agreed.where((id) => id != privacyTermId).toList();

/// 약관 "보기" 로 열 원문 주소: 개인정보 줄 → 개인정보 수집 및 이용 동의, 나머지 → 이용약관
String termDocumentUrl(WidgetRef ref, SignupTerm t) {
  final config = ref.read(appConfigProvider);
  final privacy = t.id == privacyTermId || t.title.contains('개인정보');
  return privacy ? config.privacyPolicyUrl : config.termsUrl;
}

/// 피그마 1164:6153 · 1273:11725 이용약관 카드: "○ 이용약관에 모두 동의합니다" / "○ (필수) 이용약관동의 ··· 보기"
class TermsChecklist extends ConsumerWidget {
  const TermsChecklist({
    super.key,
    required this.terms,
    required this.agreed,
    required this.onChanged,
  });

  final List<SignupTerm> terms;
  final Set<String> agreed;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = terms.isNotEmpty && terms.every((t) => agreed.contains(t.id));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            checked: all,
            label: '이용약관에 모두 동의합니다',
            excludeSemantics: true,
            child: InkWell(
              onTap: () =>
                  onChanged(all ? <String>{} : terms.map((t) => t.id).toSet()),
              child: Container(
                height: 64,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.fillMuted),
                  ),
                ),
                child: Row(
                  children: [
                    CheckMark(checked: all),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '이용약관에 모두 동의합니다',
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final t in terms)
            AgreeRow(
              label: '(${t.required ? '필수' : '선택'}) ${t.title}',
              checked: agreed.contains(t.id),
              onTap: () => onChanged(
                agreed.contains(t.id)
                    ? ({...agreed}..remove(t.id))
                    : {...agreed, t.id},
              ),
              // 원문은 앱 설정의 노션 주소로 연다 (이용약관 · 개인정보 수집 및 이용)
              onOpen: () => unawaited(ref.read(linkServiceProvider).open(termDocumentUrl(ref, t))),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 약관 한 줄: ○ (16) + 글자 14 + 오른쪽 "보기"(원문)
class AgreeRow extends StatelessWidget {
  const AgreeRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
    this.onOpen,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  /// 약관 원문 열기 ("보기")
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 4),
              CheckMark(checked: checked, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
              ),
              if (onOpen != null)
                GestureDetector(
                  onTap: onOpen,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Text(
                      '보기',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textGuide,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textGuide,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 피그마 1273:11725 "이용약관 동의하기" 바텀시트 (소셜 첫 가입, 서버 SIGN_UP_REQUIRED).
/// 이용약관 카드 + "시작하기". 동의한 서버 약관 id 를 돌려준다. 닫으면 null.
Future<List<String>?> showTermsSheet(BuildContext context) {
  return showAppSheet<List<String>>(
    context,
    title: '이용약관 동의하기',
    // QA: 고정 높이(340)라 약관 줄이 버튼 뒤로 잘렸다 → 내용 높이만큼 (길면 스크롤)
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
    final terms = config.asData == null
        ? null
        : displayTerms(config.asData!.value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: config.hasError
              ? ErrorView(
                  error: config.error!,
                  compact: true,
                  onRetry: () => ref.invalidate(serverAppConfigProvider),
                )
              : terms == null
              ? const SizedBox(height: 160, child: LoadingView())
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xs,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  children: [
                    if (terms.isNotEmpty)
                      TermsChecklist(
                        terms: terms,
                        agreed: _agreed,
                        onChanged: (v) => setState(() => _agreed = v),
                      )
                    else
                      Text(
                        '다닷을 시작하려면 아래 버튼을 눌러 주세요',
                        style: AppTypography.body2Medium.copyWith(
                          color: AppColors.textSub,
                        ),
                      ),
                  ],
                ),
        ),
        BottomCta(
          color: AppColors.sheet,
          children: [
            AppButton(
              label: '시작하기',
              onPressed: terms == null || !requiredTermsAgreed(terms, _agreed)
                  ? null
                  : () => Navigator.of(context).pop(serverTermIds(_agreed)),
            ),
          ],
        ),
      ],
    );
  }
}
