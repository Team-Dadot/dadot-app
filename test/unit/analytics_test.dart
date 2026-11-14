import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/core/services/analytics_service.dart';

void main() {
  test('화면 이름에서 id 조각은 :id 로 가린다', () {
    expect(analyticsScreenName('/quiz/123/result'), '/quiz/:id/result');
    expect(analyticsScreenName('/home'), '/home');
    expect(analyticsScreenName('/'), '/');
    expect(analyticsScreenName('/interview/a1b2c3/answer'), '/interview/:id/answer');
  });
}
