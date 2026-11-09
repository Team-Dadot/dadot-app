import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 학습 알림 예약 (QA "앱 개발 - 알림예약기능 구현 필요").
/// 서버는 알림 시간만 저장하고 보내 주지 않으므로, 기기에서 매일 그 시간에 로컬 알림을 띄운다.
/// 마이 > 알림 설정 / 첫 설정 STEP 5 에서 정한 시간 그대로. 끄면 예약을 지운다.
class ReminderService {
  ReminderService();

  static const _dailyId = 1001;
  static const _channelId = 'daily_study';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  /// 알림을 눌러 앱이 열렸을 때 (홈으로 보낸다)
  VoidCallback? onOpen;

  Future<bool> _init() => _ready ??= () async {
        try {
          tz.initializeTimeZones();
          try {
            final local = await FlutterTimezone.getLocalTimezone();
            tz.setLocalLocation(tz.getLocation(local.identifier));
          } catch (_) {
            tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
          }
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              // 권한은 "알림 허용하기" 를 눌렀을 때만 묻는다
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
            onDidReceiveNotificationResponse: (_) => onOpen?.call(),
          );
          return true;
        } catch (e) {
          // 테스트 환경 등 플러그인이 없는 곳
          debugPrint('[Reminder] init skipped: $e');
          return false;
        }
      }();

  /// OS 알림 권한 요청 (Android 13+ · iOS). 허용하면 true.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (e) {
      debugPrint('[Reminder] permission failed: $e');
      return false;
    }
  }

  /// 매일 [hour]:[minute] 학습 알림 (이미 있으면 바꿔 끼운다)
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: _dailyId);
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _dailyId,
        scheduledDate: at,
        title: '오늘의 학습 시간이에요',
        body: '오늘의 퀴즈와 면접 질문이 준비됐어요. 지금 풀어볼까요?',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '학습 알림',
            channelDescription: '매일 정한 시간에 오늘의 학습을 알려 드려요',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // 정확한 알람 권한 없이도 되는 방식 (몇 분 늦을 수 있음)
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('[Reminder] daily at $hour:$minute (next $at)');
    } catch (e) {
      debugPrint('[Reminder] schedule failed: $e');
    }
  }

  Future<void> cancelDaily() async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: _dailyId);
    } catch (_) {}
  }
}
