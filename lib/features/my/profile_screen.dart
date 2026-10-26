import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import 'my_screen.dart' show LoginBadge;

/// 6-11 회원정보 수정
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final AppUser? _user = ref.read(sessionProvider).user;
  late final _nickname = TextEditingController(text: _user?.nickname ?? '');
  late final _email = TextEditingController(
    text: [_user?.email ?? '', if (_user?.loginMethod != LoginMethod.email) '(${_user?.loginMethod.label ?? ''} 계정)'].where((s) => s.isNotEmpty).join(' '),
  );
  late final _method = TextEditingController(text: _user?.loginMethod.detailLabel ?? '');
  late int _avatar = _user?.avatarIndex ?? 0;
  bool _saving = false;

  /// 기본 프로필 이미지 개수 (피그마: 5칸)
  static const _avatarCount = 5;

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _method.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(nickname: _nickname.text.trim(), avatarIndex: _avatar);
      ref.read(sessionProvider.notifier).updateUser(user);
      if (!mounted) return;
      showToast(context, '프로필을 저장했어요.');
      context.pop();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = _user?.loginMethod == LoginMethod.email;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '내 정보'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const PageTitle('나의 계정 정보'),
          const SizedBox(height: AppSpacing.gap),
          const FieldLabel('프로필 이미지'),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (var i = 0; i < _avatarCount; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Semantics(
                  button: true,
                  selected: i == _avatar,
                  label: '프로필 이미지 ${i + 1}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => _avatar = i),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.placeholder,
                        shape: BoxShape.circle,
                        border: Border.all(color: i == _avatar ? AppColors.primary : AppColors.placeholder, width: i == _avatar ? 2 : 1),
                      ),
                      // TODO(디자인): 기본 프로필 이미지가 나오면 교체
                      child: i == _avatar ? Text('선택', style: AppTypography.micro) : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const FieldLabel('닉네임'),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(controller: _nickname, hint: '닉네임', onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          Text('연결된 계정', style: AppTypography.subheading),
          const SizedBox(height: AppSpacing.sm),
          // 피그마 6-11: 흰 카드에 이메일 + 로그인 배지
          OutlinedBox(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    (_user?.email ?? '').isEmpty ? _method.text : _user!.email!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body1Medium,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (_user != null) LoginBadge(method: _user!.loginMethod),
                const Spacer(),
                Text(_method.text, style: AppTypography.caption.copyWith(color: AppColors.textPlaceholder)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isEmail ? '로그인 이메일은 변경할 수 없어요.' : '카카오·Apple 로그인은 계정 정보를 해당 서비스에서 관리해요.',
            style: AppTypography.caption,
          ),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '정보 저장하기', loading: _saving, onPressed: _nickname.text.trim().isEmpty ? null : _save),
      ]),
    );
  }
}
