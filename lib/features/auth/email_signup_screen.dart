import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/error/app_exception.dart';
import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'auth_widgets.dart';
import 'terms_agreement.dart';

/// 피그마 최종 "회원가입" (1164:6153 빈 칸 · 1164:6203 오류 · 1164:6270 입력 완료)
/// 이메일(+ 인증번호, 서버 필수) · 비밀번호 · 비밀번호 확인 + 이용약관 → 회원가입.
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

  /// 인증번호가 틀렸을 때 칸 아래 빨간 글자 (피그마 1435:11390 — 토스트가 아니라 하단 서브 텍스트)
  String? _codeError;

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
  bool get _verified =>
      _verificationToken != null && _verifiedEmail == _emailText;
  bool get _codeSent => _verificationId != null && _codeEmail == _emailText;

  String? get _emailError =>
      _email.text.isNotEmpty && !AppPolicy.isValidEmail(_email.text)
      ? '이메일 형식이 올바르지 않아요'
      : null;
  String? get _passwordError =>
      _password.text.isEmpty ? null : AppPolicy.passwordProblem(_password.text);
  String? get _confirmError =>
      _confirm.text.isNotEmpty && _confirm.text != _password.text
      ? '비밀번호가 일치하지 않아요'
      : null;

  bool _valid(List<SignupTerm> terms) =>
      _verified &&
      AppPolicy.isValidPassword(_password.text) &&
      _confirm.text == _password.text &&
      requiredTermsAgreed(terms, _agreed);

  String? _shown(FocusNode f, String? error) =>
      _touched.contains(f) ? error : null;

  Future<void> _sendCode() async {
    if (!AppPolicy.isValidEmail(_email.text)) {
      setState(() => _touched.add(_emailFocus));
      return;
    }
    setState(() => _sending = true);
    try {
      final id = await ref
          .read(authRepositoryProvider)
          .sendEmailCode(email: _emailText, purpose: EmailCodePurpose.signUp);
      if (!mounted) return;
      setState(() {
        _verificationId = id;
        _codeEmail = _emailText;
        _code.clear();
        _codeError = null;
      });
      showInfoToast(context, '인증 번호를 보냈어요. 메일함을 확인해 주세요.');
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
      final token = await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(verificationId: id, code: _code.text.trim());
      if (!mounted) return;
      setState(() {
        _verificationToken = token;
        _verifiedEmail = _emailText;
        _codeError = null;
      });
      FocusScope.of(context).nextFocus();
    } catch (e) {
      if (!mounted) return;
      // 피그마 QA(1435:11798): 인증번호가 틀리면 토스트 대신 칸 아래 빨간 서브 텍스트로 알려 준다
      final err = asAppException(e);
      if (err.kind == AppErrorKind.validation ||
          err.kind == AppErrorKind.unauthorized ||
          err.kind == AppErrorKind.notFound) {
        setState(() => _codeError = '인증번호가 일치하지 않아요');
      } else {
        showErrorToast(context, err);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .signUpWithEmail(
            email: _emailText,
            password: _password.text,
            verificationToken: _verificationToken!,
            termIds: serverTermIds(_agreed),
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
    final terms = config.asData == null
        ? null
        : displayTerms(config.asData!.value);
    // 서버가 가입을 막아 둔 동안 (app-config signupAvailable=false)
    final closed = config.asData?.value.signupAvailable == false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '회원가입'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          27,
          AppSpacing.screenH,
          AppSpacing.xl,
        ),
        children: [
          if (closed) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.destructiveSoft,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Text(
                '지금은 새로 가입할 수 없어요. 잠시 후 다시 시도해 주세요.',
                style: AppTypography.body2Medium.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const _Label('이메일'),
          AppTextField(
            controller: _email,
            focusNode: _emailFocus,
            bordered: true,
            hint: 'example@email.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            errorText: _shown(_emailFocus, _emailError),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _verified ? null : _sendCode(),
            semanticLabel: '이메일',
            // 피그마 시안2 (1435:11436): 지우기 ✕ + 오른쪽 작은 버튼. 인증이 끝나면 라임 "인증 완료" 칩.
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_email.text.isNotEmpty) ...[
                  FieldClearButton(
                    semanticLabel: '이메일 지우기',
                    onTap: () {
                      _email.clear();
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                if (_verified)
                  const InlineAction(label: '인증 완료', onTap: null, accent: true)
                else
                  InlineAction(
                    label: _codeSent ? '재요청' : '인증 요청',
                    loading: _sending,
                    onTap: AppPolicy.isValidEmail(_email.text)
                        ? _sendCode
                        : null,
                  ),
              ],
            ),
          ),
          if (_codeSent && !_verified) ...[
            // 피그마 1435:11234: 이메일 칸 아래 12 에 인증번호 칸 (안내 문구는 칸 안내 글자로 합쳤다)
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _code,
              bordered: true,
              hint: '인증번호 6자리 (10분 이내)',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              errorText: _codeError,
              onChanged: (_) => setState(() => _codeError = null),
              onSubmitted: (_) => _verify(),
              semanticLabel: '인증번호',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_code.text.isNotEmpty) ...[
                    FieldClearButton(
                      semanticLabel: '인증번호 지우기',
                      onTap: () {
                        _code.clear();
                        setState(() => _codeError = null);
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  InlineAction(
                    label: '확인',
                    loading: _verifying,
                    onTap: _code.text.trim().length == 6 ? _verify : null,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          const _Label('비밀번호'),
          AppTextField(
            controller: _password,
            focusNode: _passwordFocus,
            bordered: true,
            hint: AppPolicy.passwordHint,
            obscureText: true,
            textInputAction: TextInputAction.next,
            errorText: _shown(_passwordFocus, _passwordError),
            onChanged: (_) => setState(() {}),
            semanticLabel: '비밀번호',
            trailing: fieldMark(
              controller: _password,
              valid: AppPolicy.isValidPassword(_password.text),
              label: '비밀번호',
              onCleared: () => setState(() {}),
            ),
          ),
          const SizedBox(height: 28),
          const _Label('비밀번호 확인'),
          AppTextField(
            controller: _confirm,
            focusNode: _confirmFocus,
            bordered: true,
            hint: '비밀번호를 한번 더 입력해 주세요',
            obscureText: true,
            errorText: _shown(_confirmFocus, _confirmError),
            onChanged: (_) => setState(() {}),
            semanticLabel: '비밀번호 확인',
            trailing: fieldMark(
              controller: _confirm,
              valid: _confirm.text.isNotEmpty && _confirm.text == _password.text,
              label: '비밀번호 확인',
              onCleared: () => setState(() {}),
            ),
          ),
          if (config.hasError) ...[
            const SizedBox(height: AppSpacing.xl),
            ErrorView(
              error: config.error!,
              compact: true,
              onRetry: () => ref.invalidate(serverAppConfigProvider),
            ),
          ] else if (terms == null) ...[
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(height: 120, child: LoadingView()),
          ] else if (terms.isNotEmpty) ...[
            // 서버 약관이 없으면 (아직 게시 전) 동의 칸을 그리지 않는다
            const SizedBox(height: 28),
            const _Label('이용약관'),
            TermsChecklist(
              terms: terms,
              agreed: _agreed,
              onChanged: (v) => setState(() => _agreed = v),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomCta(
        children: [
          AppButton(
            label: '회원가입',
            loading: _saving,
            onPressed: terms != null && !closed && _valid(terms) && !_saving
                ? _submit
                : null,
          ),
        ],
      ),
    );
  }
}

/// 입력칸 위 라벨 (피그마 14 Medium #55565A, 아래 4)
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: AppTypography.body2Medium.copyWith(color: AppColors.textSub),
    ),
  );
}
