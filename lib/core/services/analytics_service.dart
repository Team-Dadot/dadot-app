/// 운영 지표 (Firebase Analytics). 테스트·Mock 에서는 아무것도 보내지 않는 [NoopAnalyticsService].
///
/// 개인정보(이메일·이름·답변 내용)는 이벤트에 넣지 않는다. 사용자는 서버 id 로만 구분한다.
abstract interface class AnalyticsService {
  Future<void> logScreen(String name);
  Future<void> logEvent(String name, [Map<String, Object>? params]);
  Future<void> setUserId(String? id);
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> logScreen(String name) async {}

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {}

  @override
  Future<void> setUserId(String? id) async {}
}

/// 화면 이름: 경로에서 id 부분(숫자·uuid 가 들어간 조각)을 ':id' 로 바꿔 화면별로 묶는다.
/// 예) /quiz/123/result → /quiz/:id/result
String analyticsScreenName(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).map(
        (s) => RegExp(r'\d').hasMatch(s) ? ':id' : s,
      );
  return segments.isEmpty ? '/' : '/${segments.join('/')}';
}
