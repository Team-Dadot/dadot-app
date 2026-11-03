import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../design_system/design_system.dart';

/// 이메일 · 비밀번호 로그인 (POST /v1/auth/login). 아래 "회원가입" 으로 이메일 가입 화면.
/// 피그마에 전용 프레임이 없어 이메일 가입 화면과 같은 입력창·버튼으로 만들었다.
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _valid => AppPolicy.isValidEmail(_email.text) && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).signInWithEmail(email: _email.text.trim(), password: _password.text);
      // 이동은 라우터 redirect 가 처리 (첫 설정 전 → 온보딩, 끝났으면 → 홈)
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
      appBar: const AppNavBar(title: '이메일로 로그인'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const FieldLabel('이메일'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _email,
            hint: '가입한 이메일',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            semanticLabel: '이메일',
          ),
          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('비밀번호'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: _password,
            focusNode: _passwordFocus,
            hint: '비밀번호',
            obscureText: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            semanticLabel: '비밀번호',
          ),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '로그인', loading: _saving, onPressed: _valid && !_saving ? _submit : null),
        Center(
          child: TextButton(
            onPressed: _saving ? null : () => context.push(Routes.emailSignup),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '아직 회원이 아니신가요? ', style: AppTypography.body2Medium.copyWith(color: AppColors.textCaption)),
                TextSpan(text: '회원가입', style: AppTypography.body2Strong.copyWith(color: AppColors.ink)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
