import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../design_system/design_system.dart';

/// 6-12 비밀번호 변경 (이메일·비밀번호 회원만)
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _sendingCode = false;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _sendingCode = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordCode();
      if (mounted) showToast(context, '가입한 이메일로 본인 확인 코드를 보냈어요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  String? get _problem {
    if (_code.text.trim().length != 6) return '본인 확인 코드 6자리를 입력해 주세요.';
    if (!AppPolicy.isValidPassword(_password.text)) return '새 비밀번호는 영문·숫자를 포함해 8자 이상이에요.';
    if (_password.text != _confirm.text) return '새 비밀번호가 서로 달라요.';
    return null;
  }

  Future<void> _save() async {
    final problem = _problem;
    if (problem != null) {
      showToast(context, problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(code: _code.text.trim(), newPassword: _password.text);
      if (!mounted) return;
      showToast(context, '비밀번호를 바꿨어요.');
      context.pop();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = _code.text.isNotEmpty && _password.text.isNotEmpty && _confirm.text.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '비밀번호 변경'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const PageTitle('비밀번호를\n관리해요.', description: '가입한 이메일로 본인 확인 코드를 보내드려요.'),
          const SizedBox(height: AppSpacing.gap),
          const FieldLabel('본인 확인 코드'),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _code,
                  hint: '6자리 코드',
                  keyboardType: TextInputType.number,
                  maxLength: null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                height: AppSizes.inputHeight,
                child: AppButton(
                  label: '코드 보내기',
                  small: true,
                  expand: false,
                  variant: AppButtonVariant.secondary,
                  loading: _sendingCode,
                  onPressed: _sendCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const FieldLabel('새 비밀번호'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(controller: _password, hint: '영문·숫자 포함 8자 이상', obscureText: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          const FieldLabel('새 비밀번호 확인'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(controller: _confirm, hint: '한 번 더 입력해 주세요', obscureText: true, onChanged: (_) => setState(() {})),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '본인 확인 후 비밀번호 변경', loading: _saving, onPressed: filled ? _save : null),
      ]),
    );
  }
}
