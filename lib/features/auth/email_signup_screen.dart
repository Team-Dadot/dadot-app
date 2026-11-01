import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../design_system/design_system.dart';

/// 피그마 최종 "이메일로 가입 1~3" (763:17915 · 956:5074 · 956:5087)
/// 이메일 · 비밀번호 · 비밀번호 확인 + 이용약관 동의(전체 / 이용약관 / 개인정보) → 회원가입.
/// 틀린 칸은 오른쪽 빨간 ! 와 아래 빨간 안내 글자.
class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  ConsumerState<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends ConsumerState<EmailSignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  /// 한 번 벗어난 칸만 오류를 보여준다 (치는 중에 빨간 글자가 뜨지 않게)
  final Set<FocusNode> _touched = {};
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final f in [_emailFocus, _passwordFocus, _confirmFocus]) {
      f.addListener(() {
        if (!f.hasFocus && mounted) setState(() => _touched.add(f));
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [_emailFocus, _passwordFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  String? get _emailError =>
      _email.text.isNotEmpty && !AppPolicy.isValidEmail(_email.text) ? '올바르지 않은 이메일 형식입니다' : null;
  String? get _passwordError =>
      _password.text.isNotEmpty && !AppPolicy.isValidPassword(_password.text) ? '영문,숫자,특수문자 조합 8-20자로 입력해 주세요' : null;
  String? get _confirmError => _confirm.text.isNotEmpty && _confirm.text != _password.text ? '비밀번호가 일치하지 않습니다' : null;

  bool get _valid =>
      AppPolicy.isValidEmail(_email.text) &&
      AppPolicy.isValidPassword(_password.text) &&
      _confirm.text == _password.text &&
      _agreeTerms &&
      _agreePrivacy;

  String? _shown(FocusNode f, String? error) => _touched.contains(f) ? error : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).signUpWithEmail(email: _email.text.trim(), password: _password.text);
      // 이동은 라우터 redirect 가 처리 (첫 설정으로)
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDoc(String url) => unawaited(ref.read(linkServiceProvider).open(url));

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final all = _agreeTerms && _agreePrivacy;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '이메일로 시작하기'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const FieldLabel('이메일'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _email,
            focusNode: _emailFocus,
            hint: '아이디로 사용할 이메일',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: _shown(_emailFocus, _emailError),
            onChanged: (_) => setState(() {}),
            semanticLabel: '이메일',
          ),
          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('비밀번호'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _password,
            focusNode: _passwordFocus,
            hint: '${AppPolicy.minPasswordLength}-${AppPolicy.maxPasswordLength}자 비밀번호',
            obscureText: true,
            textInputAction: TextInputAction.next,
            errorText: _shown(_passwordFocus, _passwordError),
            onChanged: (_) => setState(() {}),
            semanticLabel: '비밀번호',
          ),
          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('비밀번호 확인'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _confirm,
            focusNode: _confirmFocus,
            hint: '비밀번호 확인',
            obscureText: true,
            errorText: _shown(_confirmFocus, _confirmError),
            onChanged: (_) => setState(() {}),
            semanticLabel: '비밀번호 확인',
          ),
          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('이용약관 동의'),
          const SizedBox(height: AppSpacing.xs),
          OutlinedBox(
            radius: AppRadius.button,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Column(
              children: [
                _AgreeRow(
                  label: '필수 이용약관에 모두 동의합니다',
                  strong: true,
                  checked: all,
                  onTap: () => setState(() {
                    _agreeTerms = !all;
                    _agreePrivacy = !all;
                  }),
                ),
                const LineDivider(),
                _AgreeRow(
                  label: '(필수) 이용약관동의',
                  checked: _agreeTerms,
                  onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                  onOpen: () => _openDoc(config.termsUrl),
                ),
                _AgreeRow(
                  label: '(필수) 개인정보 수집 및 이용 동의',
                  checked: _agreePrivacy,
                  onTap: () => setState(() => _agreePrivacy = !_agreePrivacy),
                  onOpen: () => _openDoc(config.privacyPolicyUrl),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '회원가입', loading: _saving, onPressed: _valid && !_saving ? _submit : null),
      ]),
    );
  }
}

/// 약관 한 줄: 글자(+ › 원문 보기) + 오른쪽 체크
class _AgreeRow extends StatelessWidget {
  const _AgreeRow({required this.label, required this.checked, required this.onTap, this.onOpen, this.strong = false});

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
