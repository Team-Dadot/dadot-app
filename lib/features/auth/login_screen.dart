import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/error/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/services/app_info.dart';
import '../../core/services/social_auth_service.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import 'terms_agreement.dart';

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

  /// 실패 이유 (서버·SDK 메시지). 원인을 알 수 있게 오류 화면 아래에 보여준다.
  String? _reason;

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
    } on SocialSignUpRequired catch (pending) {
      // 처음 온 소셜 사용자: 약관 동의 후 가입 (registrationToken 10분 유효)
      await _completeSignup(pending);
    } catch (e, st) {
      debugPrint('[LOGIN] ${provider.wire} 실패: $e\n$st');
      if (mounted) {
        setState(() {
          _failed = true;
          _reason = _describe(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  /// 상세 SDK 오류는 디버그 로그로만 남기고 화면에는 한글 안내를 보여준다.
  String _describe(Object error) {
    final cause = unwrapAppError(error);
    if (cause is AppException) return cause.userMessage;
    if (cause is PlatformException) {
      final code = cause.code.toLowerCase();
      if (code.contains('network') || code.contains('connection')) {
        return '인터넷 연결을 확인한 뒤 다시 로그인해 주세요.';
      }
      return '로그인하지 못했어요. 잠시 후 다시 시도해 주세요.';
    }
    return '로그인하지 못했어요. 잠시 후 다시 시도해 주세요.';
  }

  Future<void> _completeSignup(SocialSignUpRequired pending) async {
    if (!mounted) return;
    final termIds = await showTermsSheet(context);
    if (termIds == null || !mounted) return;
    try {
      await ref.read(sessionProvider.notifier).completeSocialSignup(registrationToken: pending.registrationToken, termIds: termIds);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = AppInfo.isIOS ? AppPolicy.loginProvidersIos : AppPolicy.loginProvidersAndroid;
    // SafeArea 안쪽에서는 위·아래 안전 영역이 이미 빠져 있어서, 바깥(이 build)에서 먼저 잰다
    final inset = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _failed
                  ? Center(child: StatusMessage(title: '일시적인 오류가 발생했어요', description: _reason ?? '잠시 후 다시 시도해 주세요'))
                  // 피그마 1622:10552: 로고 윗선이 화면 높이의 357/874 (1300:8036 의 339 에서 아래로 내림).
                  // QA: 버튼 위 남은 칸 한가운데에 둬서 디자인보다 위에 있었다 → 버튼 개수와 상관없이 같은 높이에 둔다
                  : LayoutBuilder(
                      builder: (context, box) {
                        // 로고 윗선 = 화면 전체 높이의 357/874. 안전 영역(상태 표시줄)만큼은 SafeArea 가 이미 내려 준다.
                        final top = MediaQuery.sizeOf(context).height * 357 / 874 - inset.top;
                        const block = 80.0;
                        final max = box.maxHeight - block;
                        return Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: top.clamp(0, max < 0 ? 0 : max).toDouble()),
                            child: const _Intro(),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              // 피그마 1622:10555: 버튼 묶음 아래가 화면 아래에서 36 (홈 인디케이터 영역 포함)
              padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, (36 - inset.bottom).clamp(0.0, 36.0)),
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
                    onPressed: _loading == null ? () => context.push(Routes.emailLogin) : null,
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
        // 피그마 1337:11993 로고 170×36.75, 17 아래 한 줄 소개 (1300:8047: 16 SemiBold #303137)
        // 피그마 1622:10564 · 1622:10563: 로고는 가운데에서 왼쪽으로 1.89, 소개 글은 2 치우쳐 있다
        Transform.translate(
          offset: const Offset(-1.89, 0),
          child: Image.asset('assets/images/dadot_wordmark_login.png', width: 170.2, height: 36.75, semanticLabel: 'Dadot'),
        ),
        const SizedBox(height: 17.25),
        Transform.translate(
          offset: const Offset(-2, 0),
          child: Text(
            '공시 기반 핵심들로 준비하는 기업 분석',
            textAlign: TextAlign.center,
            style: AppTypography.subheading.copyWith(color: const Color(0xFF303137), height: 1.4, letterSpacing: -0.48),
          ),
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
