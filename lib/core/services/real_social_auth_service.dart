import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/models/auth.dart';
import '../error/app_exception.dart';
import 'social_auth_service.dart';

/// 실제 카카오 · Apple SDK 로그인.
/// - 카카오: 카카오톡이 있으면 카카오톡으로, 없거나 실패하면 카카오계정(웹)으로 → accessToken 을 서버에 보낸다
/// - Apple: 서버 nonce 원문의 SHA-256 을 SDK 에 넣고 → identityToken · authorizationCode · nonce 원문을 서버에 보낸다
class RealSocialAuthService implements SocialAuthService {
  const RealSocialAuthService({required this.kakaoReady});

  /// main.dart 에서 KakaoSdk.init 을 했는지 (네이티브 앱 키가 있는지)
  final bool kakaoReady;

  @override
  Future<SocialCredential> signIn(SocialProvider provider, {String? nonce}) => switch (provider) {
        SocialProvider.kakao => _kakao(),
        SocialProvider.apple => _apple(nonce),
        SocialProvider.google => throw const AppException(AppErrorKind.validation, message: 'Google 로그인은 지원하지 않아요.'),
      };

  Future<SocialCredential> _kakao() async {
    if (!kakaoReady) {
      throw const AppException(AppErrorKind.unknown, message: '카카오 앱 키가 설정되지 않았어요.', code: 'KAKAO_KEY_MISSING');
    }
    OAuthToken token;
    try {
      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } on PlatformException catch (e) {
          // 카카오톡 화면에서 취소 → 웹 로그인으로 넘기지 않는다
          if (e.code == 'CANCELED') throw const SocialAuthCancelled();
          // 카카오톡에 연결된 계정이 없는 경우 등 → 카카오계정으로
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } on SocialAuthCancelled {
      rethrow;
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) throw const SocialAuthCancelled();
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const SocialAuthCancelled();
      rethrow;
    }
    return SocialCredential(provider: SocialProvider.kakao, token: token.accessToken);
  }

  Future<SocialCredential> _apple(String? nonce) async {
    if (nonce == null || nonce.isEmpty) throw const AppException(AppErrorKind.server, message: 'Apple 로그인 준비에 실패했어요. 다시 시도해 주세요.');
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
      );
      final idToken = c.identityToken;
      if (idToken == null) throw const AppException(AppErrorKind.unknown, message: 'Apple 로그인 정보를 받지 못했어요.');
      return SocialCredential(provider: SocialProvider.apple, token: idToken, authorizationCode: c.authorizationCode, nonce: nonce);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw const SocialAuthCancelled();
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!kakaoReady) return;
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오로 로그인하지 않았거나 이미 만료된 경우
    }
  }
}
