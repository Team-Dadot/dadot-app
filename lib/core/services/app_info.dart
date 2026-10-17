import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 앱 버전 · 플랫폼. 문의 전송과 푸시 토큰 등록에 쓴다.
/// 버전은 빌드할 때 --dart-define=APP_VERSION=1.0.0 으로 넣거나,
/// package_info_plus 를 추가해 pubspec 버전을 읽도록 바꿔도 된다.
class AppInfo {
  AppInfo._();

  static const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static String get platform {
    if (kIsWeb) return 'WEB';
    if (Platform.isIOS) return 'IOS';
    if (Platform.isAndroid) return 'ANDROID';
    return 'OTHER';
  }

  // defaultTargetPlatform 을 써야 테스트에서 플랫폼을 바꿔 볼 수 있다
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
}
