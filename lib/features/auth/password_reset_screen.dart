import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import 'auth_widgets.dart';
import 'email_login_screen.dart' show AuthFieldLabel;

/// 이메일 로그인 "비밀번호 찾기" (서버: 인증번호 PASSWORD_RESET → POST /v1/auth/password/reset).
/// 피그마에 전용 프레임이 없어 회원가입 화면(1164:6153)과 같은 입력칸·버튼으로 만들었다.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _verificationId;
  String? _codeEmail;
  String? _token;
  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _emailText => _email.text.trim();
  bool get _codeSent => _verificationId != null && _codeEmail == _emailText;
  bool get _verified => _token != null && _codeEmail == _emailText;

  String? get _passwordError =>
      _password.text.isNotEmpty && !AppPolicy.isValidPassword(_password.text)
      ? AppPolicy.passwordRule
      : null;
  String? get _confirmError =>
      _confirm.text.isNotEmpty && _confirm.text != _password.text
      ? '비밀번호가 일치하지 않아요'
      : null;

  bool get _valid =>
      _verified &&
      AppPolicy.isValidPassword(_password.text) &&
      _confirm.text == _password.text;

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      final id = await ref
          .read(authRepositoryProvider)
          .sendEmailCode(
            email: _emailText,
            purpose: EmailCodePurpose.passwordReset,
          );
      if (!mounted) return;
      setState(() {
        _verificationId = id;
        _codeEmail = _emailText;
        _token = null;
        _code.clear();
      });
      showToast(context, '가입한 이메일이면 인증번호를 보냈어요. 메일함을 확인해 주세요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final id = _verificationId;
    if (id == null) return;
    setState(() => _verifying = true);
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(verificationId: id, code: _code.text.trim());
      if (mounted) setState(() => _token = token);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            verificationToken: _token!,
            newPassword: _password.text,
          );
      if (!mounted) return;
      showDoneToast(context, '비밀번호를 바꿨어요. 새 비밀번호로 로그인해 주세요.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '비밀번호 찾기'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          27,
          AppSpacing.screenH,
          AppSpacing.xl,
        ),
        children: [
          const AuthFieldLabel('이메일'),
          AppTextField(
            controller: _email,
            bordered: true,
            hint: '가입한 이메일',
            keyboardType: TextInputType.emailAddress,
            readOnly: _verified,
            onChanged: (_) => setState(() {}),
            semanticLabel: '이메일',
            trailing: _verified
                ? Text(
                    '인증 완료',
                    style: AppTypography.body2Strong.copyWith(
                      color: AppColors.pointDeep,
                    ),
                  )
                : InlineAction(
                    label: _codeSent ? '재전송' : '인증 요청',
                    loading: _sending,
                    onTap: AppPolicy.isValidEmail(_email.text)
                        ? _sendCode
                        : null,
                  ),
          ),
          if (_codeSent && !_verified) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _code,
              bordered: true,
              hint: '이메일로 받은 인증번호 6자리',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _verify(),
              semanticLabel: '인증번호',
              trailing: InlineAction(
                label: '확인',
                loading: _verifying,
                onTap: _code.text.trim().length == 6 ? _verify : null,
              ),
            ),
          ],
          if (_verified) ...[
            const SizedBox(height: 28),
            const AuthFieldLabel('새 비밀번호'),
            AppTextField(
              controller: _password,
              bordered: true,
              hint: AppPolicy.passwordHint,
              obscureText: true,
              errorText: _passwordError,
              onChanged: (_) => setState(() {}),
              semanticLabel: '새 비밀번호',
            ),
            const SizedBox(height: 28),
            const AuthFieldLabel('새 비밀번호 확인'),
            AppTextField(
              controller: _confirm,
              bordered: true,
              hint: '비밀번호를 한번 더 입력해 주세요',
              obscureText: true,
              errorText: _confirmError,
              onChanged: (_) => setState(() {}),
              semanticLabel: '새 비밀번호 확인',
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomCta(
        children: [
          AppButton(
            label: '비밀번호 바꾸기',
            loading: _saving,
            onPressed: _valid && !_saving ? _save : null,
          ),
        ],
      ),
    );
  }
}
