import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_service.dart';

/// Firebase Analytics 구현. 분석 전송 실패가 앱 동작을 막지 않게 모든 호출의 오류를 삼킨다.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics]) : _a = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _a;

  @override
  Future<void> logScreen(String name) async {
    try {
      await _a.logScreenView(screenName: name);
    } catch (_) {}
  }

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await _a.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  @override
  Future<void> setUserId(String? id) async {
    try {
      await _a.setUserId(id: id);
    } catch (_) {}
  }
}
