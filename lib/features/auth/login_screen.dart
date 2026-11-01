import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/router/app_router.dart';
import '../../core/services/app_info.dart';
import '../../core/services/social_auth_service.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';

/// 피그마 최종 1-1 시작 · 로그인 (763:17466) / 1-E1 로그인 실패 (763:17912)
/// DADOT 로고 + 한 줄 소개, 아래 카카오(노랑) · Apple(검정) · 이메일(회색) 버튼.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  SocialProvider? _loading;

  /// 1-E1: 로그인이 실패하면 로고 자리에 "일시적인 오류가 발생했어요"
  bool _failed = false;

  Future<void> _signIn(SocialProvider provider) async {
    if (_loading != null) return;
    setState(() {
      _loading = provider;
      _failed = false;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(provider);
      // 이동은 라우터 redirect 가 처리 (신규 → 온보딩, 기존 → 홈)
    } on SocialAuthCancelled {
      // 사용자가 닫음 → 아무것도 안 함
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = AppInfo.isIOS ? AppPolicy.loginProvidersIos : AppPolicy.loginProvidersAndroid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: _failed
                    ? const StatusMessage(title: '일시적인 오류가 발생했어요', description: '잠시 후 다시 시도해 주세요')
                    : const _Intro(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in providers) ...[
                    _LoginButton(
                      provider: p,
                      loading: _loading == p,
                      onPressed: _loading == null ? () => _signIn(p) : null,
                    ),
                    const SizedBox(height: AppSpacing.ctaGap),
                  ],
                  AppButton(
                    label: '이메일로 시작하기',
                    variant: AppButtonVariant.secondary,
                    onPressed: _loading == null ? () => context.push(Routes.emailSignup) : null,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppHeader.logoAsset, height: 32, semanticLabel: 'Dadot'),
        const SizedBox(height: AppSpacing.md),
        Text(
          '공시 기반 퀴즈로 익히고\n내 경험을 담아 답해보세요',
          textAlign: TextAlign.center,
          style: AppTypography.body2Medium.copyWith(color: AppColors.textSub),
        ),
      ],
    );
  }
}

/// 소셜 로그인 버튼 (카카오 노랑 + 말풍선 · Apple 검정 + 사과)
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.provider, required this.loading, required this.onPressed});

  final SocialProvider provider;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // 피그마 1-1 로그인 버튼 아이콘 (카카오 말풍선 20×18, Apple 로고 18×21) — 피그마에서 PNG 로 내보냄
    final (Color bg, Color fg, Widget icon) = switch (provider) {
      SocialProvider.kakao => (
          AppColors.kakao,
          AppColors.ink,
          Image.asset('assets/images/icons/login_kakao.png', width: 20, height: 18, excludeFromSemantics: true),
        ),
      SocialProvider.apple => (
          AppColors.ink,
          AppColors.white,
          Image.asset('assets/images/icons/login_apple.png', width: 18, height: 21, excludeFromSemantics: true),
        ),
      SocialProvider.google => (AppColors.surface, AppColors.ink, const Icon(Icons.g_mobiledata_rounded, size: 22, color: AppColors.ink)),
    };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: provider.buttonLabel,
      excludeSemantics: true,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg.withValues(alpha: 0.5),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          splashFactory: NoSplash.splashFactory,
        ),
        child: loading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.xs),
                  Text(provider.buttonLabel),
                ],
              ),
      ),
    );
  }
}
