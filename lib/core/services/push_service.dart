import 'dart:async';

/// 푸시 알림 (매일 퀴즈 알림). Firebase 설정 파일이 생기면 FCM 구현으로 바꾼다.
///
/// FCM 붙이는 법 (docs/RELEASE_CHECKLIST.md 3장):
///  1. firebase_core, firebase_messaging 추가 + flutterfire configure
///  2. 이 인터페이스를 구현한 FcmPushService 작성
///     - requestPermission: FirebaseMessaging.instance.requestPermission()
///       (Android 13+ 는 POST_NOTIFICATIONS 런타임 권한도 이걸로 요청됨)
///     - getToken / onTokenRefresh: FirebaseMessaging.instance
///     - onOpenRoute: onMessageOpenedApp + getInitialMessage 의 data['route']
///  3. core/providers.dart 의 pushServiceProvider 에서 바꿔 끼우기
abstract interface class PushService {
  /// OS 알림 권한 요청. 허용하면 true.
  Future<bool> requestPermission();

  Future<String?> getToken();
  Stream<String> get onTokenRefresh;

  /// 알림을 눌러 앱이 열렸을 때 이동할 경로 (예: /quiz/kia)
  Stream<String> get onOpenRoute;

  /// 앱이 꺼진 상태에서 알림으로 열렸을 때의 경로
  Future<String?> initialRoute();
}

class NoopPushService implements PushService {
  NoopPushService();

  final _routes = StreamController<String>.broadcast();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<String> get onOpenRoute => _routes.stream;

  @override
  Future<String?> initialRoute() async => null;

  /// 개발용: 알림 클릭 흉내
  void simulateOpen(String route) => _routes.add(route);
}
