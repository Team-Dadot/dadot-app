import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 휴대폰 설정 화면 열기 (알림 권한을 거부한 뒤 다시 켤 때).
/// - iOS: 이 앱의 설정 화면 (app-settings:)
/// - Android: 이 앱의 알림 설정 화면 (MainActivity 의 dadot/system_settings 채널)
class SystemSettings {
  SystemSettings._();

  static const _channel = MethodChannel('dadot/system_settings');

  static Future<void> openNotificationSettings() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<void>('openNotificationSettings');
      } else {
        await launchUrl(Uri.parse('app-settings:'));
      }
    } catch (e) {
      debugPrint('[SystemSettings] open failed: $e');
    }
  }
}
