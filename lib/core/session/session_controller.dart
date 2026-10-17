import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auth.dart';
import '../error/app_exception.dart';
import '../providers.dart';
import '../services/app_info.dart';

enum SessionStatus {
  /// 앱 시작 직후 토큰 확인 중 (스플래시)
  unknown,
  unauthenticated,

  /// 로그인은 했지만 첫 설정(준비 기업·직무·면접일·경험) 전
  onboarding,
  ready,
}

class SessionState {
  const SessionState({required this.status, this.user, this.bootstrapError});

  static const initial = SessionState(status: SessionStatus.unknown);

  final SessionStatus status;
  final AppUser? user;

  /// 앱 시작 시 네트워크 오류 (스플래시에서 다시 시도)
  final AppException? bootstrapError;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// 로그인한 사용자 id. 데이터 provider 들이 이걸 watch 해서 계정이 바뀌면 새로 불러온다.
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider.select((s) => s.user?.id)));

class SessionController extends Notifier<SessionState> {
  StreamSubscription<void>? _unauthorizedSub;

  @override
  SessionState build() {
    _unauthorizedSub = ref.read(authEventsProvider).onUnauthorized.listen((_) => _expire());
    ref.onDispose(() => _unauthorizedSub?.cancel());
    Future.microtask(bootstrap);
    return SessionState.initial;
  }

  /// 저장된 토큰으로 로그인 상태 복원
  Future<void> bootstrap() async {
    state = SessionState.initial;
    final tokens = ref.read(tokenStorageProvider);
    final token = await tokens.readAccessToken();
    if (!ref.mounted) return;
    if (token == null) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return;
    }
    try {
      final user = await ref.read(authRepositoryProvider).fetchMe();
      if (!ref.mounted) return;
      _setUser(user);
      if (user.onboardingCompleted) unawaited(_registerPushToken());
    } on AppException catch (e) {
      if (!ref.mounted) return;
      if (e.kind == AppErrorKind.unauthorized) {
        await tokens.clear();
        state = const SessionState(status: SessionStatus.unauthenticated);
      } else {
        state = SessionState(status: SessionStatus.unknown, bootstrapError: e);
      }
    }
  }

  /// 소셜 로그인 (1-1). 사용자가 창을 닫으면 SocialAuthCancelled 를 그대로 던진다.
  Future<void> signIn(SocialProvider provider) async {
    final credential = await ref.read(socialAuthServiceProvider).signIn(provider);
    final session = await ref.read(authRepositoryProvider).signInWithSocial(credential);
    await ref.read(tokenStorageProvider).save(accessToken: session.accessToken, refreshToken: session.refreshToken);
    if (!ref.mounted) return;
    _setUser(session.user);
    if (session.user.onboardingCompleted) unawaited(_registerPushToken());
  }

  /// 마이에서 사용자 정보가 바뀌었을 때
  void updateUser(AppUser user) {
    state = SessionState(status: state.status, user: user);
  }

  /// 첫 설정 완료 → 라우터가 홈으로 보낸다
  Future<void> completeOnboarding() async {
    final user = await ref.read(profileRepositoryProvider).completeOnboarding();
    if (!ref.mounted) return;
    state = SessionState(status: SessionStatus.ready, user: user);
    unawaited(_registerPushToken());
  }

  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // 서버 로그아웃이 실패해도 기기에서는 로그아웃
    }
    await _clearLocal();
  }

  /// 회원 탈퇴. 서버 삭제가 실패하면 예외를 던지고 로그인 상태를 유지한다.
  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    await ref.read(tokenStorageProvider).clear();
    await ref.read(localStoreProvider).clearUserData();
    try {
      await ref.read(socialAuthServiceProvider).signOut();
    } catch (_) {}
    if (!ref.mounted) return;
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  /// 토큰 갱신까지 실패 → 로그인 화면으로
  Future<void> _expire() async {
    if (state.status == SessionStatus.unauthenticated) return;
    await ref.read(tokenStorageProvider).clear();
    if (!ref.mounted) return;
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  void _setUser(AppUser user) {
    state = SessionState(
      status: user.onboardingCompleted ? SessionStatus.ready : SessionStatus.onboarding,
      user: user,
    );
  }

  Future<void> _registerPushToken() async {
    try {
      final token = await ref.read(pushServiceProvider).getToken();
      if (token == null) return;
      await ref.read(profileRepositoryProvider).registerPushToken(token: token, platform: AppInfo.platform);
    } catch (_) {
      // 푸시 토큰 등록 실패는 화면에 알리지 않는다
    }
  }

  /// 알림 권한 허용 직후 호출
  Future<void> registerPushToken() => _registerPushToken();
}
