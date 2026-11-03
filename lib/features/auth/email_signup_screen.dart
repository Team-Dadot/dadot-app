import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'terms_agreement.dart';

/// 피그마 최종 "이메일로 가입 1~3" (763:17915 · 956:5074 · 956:5087)
/// 이메일(+ 인증번호) · 비밀번호 · 비밀번호 확인 + 이용약관 동의 → 회원가입.
/// 서버 흐름: 인증번호 보내기(SIGN_UP) → 6자리 확인(verificationToken) → 가입(acceptedTermsIds = 서버 약관 id).
/// 틀린 칸은 오른쪽 빨간 ! 와 아래 빨간 안내 글자.
class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  ConsumerState<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends ConsumerState<EmailSignupScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  /// 한 번 벗어난 칸만 오류를 보여준다 (치는 중에 빨간 글자가 뜨지 않게)
  final Set<FocusNode> _touched = {};
  Set<String> _agreed = {};

  /// 인증번호를 보낸 이메일 · verificationId
  String? _codeEmail;
  String? _verificationId;

  /// 인증을 마친 이메일 · verificationToken
  String? _verifiedEmail;
  String? _verificationToken;

  bool _sending = false;
  bool _verifying = false;
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
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [_emailFocus, _passwordFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  String get _emailText => _email.text.trim();
  bool get _verified => _verificationToken != null && _verifiedEmail == _emailText;
  bool get _codeSent => _verificationId != null && _codeEmail == _emailText;

  String? get _emailError =>
      _email.text.isNotEmpty && !AppPolicy.isValidEmail(_email.text) ? '올바르지 않은 이메일 형식입니다' : null;
  String? get _passwordError =>
      _password.text.isNotEmpty && !AppPolicy.isValidPassword(_password.text) ? '영문,숫자,특수문자 조합 8-20자로 입력해 주세요' : null;
  String? get _confirmError => _confirm.text.isNotEmpty && _confirm.text != _password.text ? '비밀번호가 일치하지 않습니다' : null;

  bool _valid(List<SignupTerm> terms) =>
      _verified &&
      AppPolicy.isValidPassword(_password.text) &&
      _confirm.text == _password.text &&
      requiredTermsAgreed(terms, _agreed);

  String? _shown(FocusNode f, String? error) => _touched.contains(f) ? error : null;

  Future<void> _sendCode() async {
    if (!AppPolicy.isValidEmail(_email.text)) {
      setState(() => _touched.add(_emailFocus));
      return;
    }
    setState(() => _sending = true);
    try {
      final id = await ref.read(authRepositoryProvider).sendEmailCode(email: _emailText, purpose: EmailCodePurpose.signUp);
      if (!mounted) return;
      setState(() {
        _verificationId = id;
        _codeEmail = _emailText;
        _code.clear();
      });
      showToast(context, '인증번호를 보냈어요. 메일함을 확인해 주세요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final id = _verificationId;
    if (id == null || _code.text.trim().length != 6) return;
    setState(() => _verifying = true);
    try {
      final token = await ref.read(authRepositoryProvider).verifyEmailCode(verificationId: id, code: _code.text.trim());
      if (!mounted) return;
      setState(() {
        _verificationToken = token;
        _verifiedEmail = _emailText;
      });
      FocusScope.of(context).nextFocus();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).signUpWithEmail(
            email: _emailText,
            password: _password.text,
            verificationToken: _verificationToken!,
            termIds: _agreed.toList(),
          );
      // 이동은 라우터 redirect 가 처리 (첫 설정으로)
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(serverAppConfigProvider);
    final terms = config.asData?.value.terms;
    // 서버가 가입을 막아 둔 동안 (app-config signupAvailable=false)
    final closed = config.asData?.value.signupAvailable == false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '이메일로 가입하기'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          if (closed) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.destructiveSoft, borderRadius: BorderRadius.circular(AppRadius.button)),
              child: Text('지금은 새로 가입할 수 없어요. 잠시 후 다시 시도해 주세요.', style: AppTypography.body2Medium.copyWith(color: AppColors.destructive)),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const FieldLabel('이메일'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _email,
            focusNode: _emailFocus,
            hint: '아이디로 사용할 이메일',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            errorText: _shown(_emailFocus, _emailError),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _verified ? null : _sendCode(),
            semanticLabel: '이메일',
            trailing: _verified
                ? Text('인증 완료', style: AppTypography.body2Strong.copyWith(color: AppColors.pointDeep))
                : _InlineAction(
                    label: _codeSent ? '재전송' : '인증 요청',
                    loading: _sending,
                    onTap: AppPolicy.isValidEmail(_email.text) ? _sendCode : null,
                  ),
          ),
          if (_codeSent && !_verified) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _code,
              hint: '이메일로 받은 인증번호 6자리',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _verify(),
              semanticLabel: '인증번호',
              trailing: _InlineAction(label: '확인', loading: _verifying, onTap: _code.text.trim().length == 6 ? _verify : null),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('인증번호는 10분 동안 쓸 수 있어요', style: AppTypography.caption.copyWith(color: AppColors.textCaption)),
          ],
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
          if (config.hasError) ...[
            const SizedBox(height: AppSpacing.xl),
            ErrorView(error: config.error!, compact: true, onRetry: () => ref.invalidate(serverAppConfigProvider)),
          ] else if (terms == null) ...[
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(height: 120, child: LoadingView()),
          ] else if (terms.isNotEmpty) ...[
            // 서버 약관이 없으면 (아직 게시 전) 동의 칸을 그리지 않는다
            const SizedBox(height: AppSpacing.xl),
            const FieldLabel('이용약관 동의'),
            const SizedBox(height: AppSpacing.xs),
            TermsChecklist(terms: terms, agreed: _agreed, onChanged: (v) => setState(() => _agreed = v)),
          ],
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(
          label: '회원가입',
          loading: _saving,
          onPressed: terms != null && !closed && _valid(terms) && !_saving ? _submit : null,
        ),
      ]),
    );
  }
}

/// 입력창 오른쪽 작은 버튼 (인증 요청 · 재전송 · 확인)
class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: enabled ? AppColors.ink : AppColors.fillMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, style: AppTypography.caption.copyWith(color: enabled ? AppColors.white : AppColors.textGuide, fontWeight: AppTypography.medium)),
        ),
      ),
    );
  }
}
