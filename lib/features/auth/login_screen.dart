import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/services/app_info.dart';
import '../../core/services/social_auth_service.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';

/// 1-1 시작 · 로그인
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  SocialProvider? _loading;

  Future<void> _signIn(SocialProvider provider) async {
    if (_loading != null) return;
    setState(() => _loading = provider);
    try {
      await ref.read(sessionProvider.notifier).signIn(provider);
      // 이동은 라우터 redirect 가 처리 (신규 → 온보딩, 기존 → 홈)
    } on SocialAuthCancelled {
      // 사용자가 닫음 → 아무것도 안 함
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  // TODO(결정 1): 이메일 로그인 화면이 피그마에 아직 없음 ("각 로그인별 화면 필요")
  void _signInWithEmail() => showToast(context, '이메일 로그인은 준비 중이에요.');

  @override
  Widget build(BuildContext context) {
    final providers = AppInfo.isIOS ? AppPolicy.loginProvidersIos : AppPolicy.loginProvidersAndroid;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _Intro()),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.introGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in providers) ...[
                    AppButton(
                      label: p.buttonLabel,
                      loading: _loading == p,
                      onPressed: _loading == null ? () => _signIn(p) : null,
                      variant: p == SocialProvider.apple ? AppButtonVariant.primary : AppButtonVariant.secondary,
                    ),
                    const SizedBox(height: AppSpacing.ctaGap),
                  ],
                  AppButton(
                    label: '이메일로 시작하기',
                    onPressed: _loading == null ? _signInWithEmail : null,
                    variant: AppButtonVariant.outline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(AppHeader.logoAsset, height: 40, semanticLabel: 'Dadot'),
          const SizedBox(height: AppSpacing.introGap),
          Text('기업의 이야기,\n나의 답변으로.', textAlign: TextAlign.center, style: AppTypography.display),
          const SizedBox(height: AppSpacing.introGap),
          Text(
            '공시로 기업을 알아가고,\n내 경험과 연결해 면접을 준비해요.',
            textAlign: TextAlign.center,
            style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
