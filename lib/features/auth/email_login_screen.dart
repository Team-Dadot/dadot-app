import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/error/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../design_system/design_system.dart';
import 'password_reset_screen.dart';

/// 피그마 최종 "이메일로 로그인" (1164:6052 빈 칸 · 1164:6079 이메일 형식 오류 · 1164:6116 입력 완료)
/// ‹ 이메일로 시작하기 / 이메일 · 비밀번호 → 로그인 → 비밀번호 찾기 · "아직 다닷 회원이 아니신가요? 회원가입"
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _emailTouched = false;
  bool _saving = false;

  /// 로그인 실패 안내 (비밀번호 칸 아래 빨간 글자). 다시 입력하면 지운다.
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus && mounted) {
        setState(() => _emailTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _valid =>
      AppPolicy.isValidEmail(_email.text) && _password.text.isNotEmpty;

  /// 피그마 1164:6079: 이메일 칸을 벗어났는데 형식이 틀리면 빨간 테두리
  String? get _emailError =>
      _emailTouched &&
          _email.text.isNotEmpty &&
          !AppPolicy.isValidEmail(_email.text)
      ? '이메일 형식이 올바르지 않아요'
      : null;

  Future<void> _submit() async {
    if (!_valid || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .signInWithEmail(email: _email.text.trim(), password: _password.text);
      // 이동은 라우터 redirect 가 처리 (첫 설정 전 → 온보딩, 끝났으면 → 홈)
    } catch (e) {
      if (!mounted) return;
      final err = asAppException(e);
      // 보통 앱처럼: 이메일·비밀번호가 틀리면 어느 쪽이 틀렸는지 알려 주지 않고 한 문장으로 (계정 존재 여부 노출 방지)
      if (err.kind == AppErrorKind.validation || err.kind == AppErrorKind.unauthorized || err.kind == AppErrorKind.notFound) {
        setState(() => _loginError = '이메일 또는 비밀번호가 일치하지 않아요');
      } else {
        showErrorToast(context, err);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '이메일로 시작하기'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
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
              focusNode: _emailFocus,
              bordered: true,
              clearable: true,
              hint: '이메일을 입력해주세요',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _emailError ?? (_loginError == null ? null : ''),
              onChanged: (_) => setState(() => _loginError = null),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              semanticLabel: '이메일',
            ),
            const SizedBox(height: AppSpacing.lg),
            const AuthFieldLabel('비밀번호'),
            AppTextField(
              controller: _password,
              focusNode: _passwordFocus,
              bordered: true,
              clearable: true,
              hint: '비밀번호를 입력해주세요',
              obscureText: true,
              textInputAction: TextInputAction.done,
              errorText: _loginError,
              onChanged: (_) => setState(() => _loginError = null),
              onSubmitted: (_) => _submit(),
              semanticLabel: '비밀번호',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '로그인',
              loading: _saving,
              onPressed: _valid && !_saving ? _submit : null,
            ),
            // 피그마 1435:11151: 로그인 버튼 아래 20 — "비밀번호 찾기 | 회원가입" 한 줄.
            // QA 메모(1435:11796): 그냥 글자처럼 보인다는 피드백 → 밑줄 + 12 → 14
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AuthLink(
                  label: '비밀번호 찾기',
                  onTap: _saving
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PasswordResetScreen(),
                          ),
                        ),
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  color: AppColors.textSub,
                ),
                _AuthLink(
                  label: '회원가입',
                  onTap: _saving ? null : () => context.push(Routes.emailSignup),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인 버튼 아래 글자 링크 (피그마 1435:11152 · 1435:11154 — 14 Regular #55565A, 밑줄, 자간 -0.42)
class _AuthLink extends StatelessWidget {
  const _AuthLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: AppTypography.body2.copyWith(
            color: AppColors.textSub,
            height: 1.4,
            letterSpacing: -0.42,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textSub,
          ),
        ),
      ),
    ),
  );
}

/// 입력칸 위 라벨 (피그마 14 Medium #55565A, 아래 4)
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

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
