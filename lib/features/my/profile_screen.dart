import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/social_auth_service.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import 'my_screen.dart' show LoginBadge;

/// 피그마 최종 6-11 회원정보 수정 "내 정보" (763:15378): 연결된 계정 한 줄 (이메일 + 로그인 배지 ›)
/// 누르면 이메일 회원은 비밀번호 변경, 소셜 회원은 6-12 재인증 화면.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final isEmail = user?.loginMethod == LoginMethod.email;
    final account = (user?.email ?? '').isNotEmpty ? user!.email! : user?.loginMethod.detailLabel ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '내 정보'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.sm),
            child: Text('연결된 계정', style: AppTypography.body2Medium.copyWith(color: AppColors.textCaption)),
          ),
          Semantics(
            button: true,
            label: '연결된 계정 $account, ${user?.loginMethod.label ?? ''}',
            excludeSemantics: true,
            child: OutlinedBox(
              radius: AppRadius.button,
              onTap: user == null
                  ? null
                  : () => isEmail ? context.push(Routes.myPassword) : Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReauthScreen())),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 18),
              child: Row(
                children: [
                  Flexible(child: Text(account, overflow: TextOverflow.ellipsis, style: AppTypography.body1Medium.copyWith(color: AppColors.ink))),
                  const SizedBox(width: AppSpacing.xs),
                  if (user != null) LoginBadge(method: user.loginMethod),
                  const Spacer(),
                  const Chevron(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 피그마 6-12 비밀번호 변경 (대체) "수정하기" (970:4322): 개인정보 보호를 위한 인증 → 로그인한 소셜 계정으로 재인증
class ReauthScreen extends ConsumerStatefulWidget {
  const ReauthScreen({super.key});

  @override
  ConsumerState<ReauthScreen> createState() => _ReauthScreenState();
}

class _ReauthScreenState extends ConsumerState<ReauthScreen> {
  bool _busy = false;

  Future<void> _reauth(SocialProvider provider, String label) async {
    setState(() => _busy = true);
    try {
      final nonce = await ref.read(authRepositoryProvider).prepareSocial(provider);
      await ref.read(socialAuthServiceProvider).signIn(provider, nonce: nonce);
      if (!mounted) return;
      showToast(context, '인증했어요. 계정 정보는 $label에서 바꿀 수 있어요.');
      Navigator.of(context).pop();
    } on SocialAuthCancelled {
      // 닫음
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = ref.watch(sessionProvider.select((s) => s.user?.loginMethod)) ?? LoginMethod.kakao;
    final (SocialProvider provider, String label, IconData icon, Color iconBg) = switch (method) {
      LoginMethod.apple => (SocialProvider.apple, 'Apple', Icons.apple, AppColors.ink),
      LoginMethod.google => (SocialProvider.google, 'Google', Icons.g_mobiledata_rounded, AppColors.fillMuted),
      _ => (SocialProvider.kakao, '카카오톡', Icons.chat_bubble_rounded, AppColors.kakao),
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '수정하기'),
      // 피그마 서브 그래픽 "개인 정보보호 그래픽" (1514:9672): 내비 아래 43 에 그림 · 제목 20 · 설명 16 · 38 아래 흰 버튼(52, 모서리 16)
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 224 - 113 - StateGraphic.privacy.height, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const StatusMessage(
            icon: StatusIcon.shield,
            title: '개인정보 보호를 위한 인증이 필요해요',
            description: '로그인 계정으로 재인증을 진행해주세요',
            titleColor: AppColors.ink,
            descriptionColor: AppColors.textCaption,
          ),
          const SizedBox(height: 38),
          Semantics(
            button: true,
            label: '$label 계정으로 인증',
            excludeSemantics: true,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: _busy ? null : () => _reauth(provider, label),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary))
                      else ...[
                        switch (method) {
                          LoginMethod.apple || LoginMethod.google => Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(4)),
                              child: method == LoginMethod.apple
                                  ? Image.asset('assets/images/icons/login_apple.png', excludeFromSemantics: true)
                                  : Icon(icon, size: 13, color: AppColors.ink),
                            ),
                          // 피그마: 노란 네모(#FFE812, 모서리 4) 안 말풍선
                          _ => Image.asset('assets/images/icons/kakao_square.png', width: 20, height: 20, excludeFromSemantics: true),
                        },
                        const SizedBox(width: 9),
                        Text(
                          '$label 계정으로 인증',
                          style: AppTypography.body2Medium.copyWith(color: AppColors.ink, height: 1.4, letterSpacing: -0.42),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
