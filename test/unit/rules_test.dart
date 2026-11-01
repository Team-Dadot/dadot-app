import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/core/config/app_policy.dart';
import 'package:swipe/core/error/app_exception.dart';
import 'package:swipe/data/models/catalog.dart';
import 'package:swipe/data/models/settings.dart';
import 'package:swipe/features/common/format.dart';

void main() {
  group('D-day', () {
    final prep = Preparation(companyId: 'kia', companyName: '기아', interviewDate: DateTime(2026, 10, 24));
    test('남은 날', () => expect(prep.ddayFrom(DateTime(2026, 10, 14, 23)), 10));
    test('표기', () {
      expect(formatDday(10), 'D-10');
      expect(formatDday(0), 'D-Day');
      expect(formatDday(-2), 'D+2');
    });
    test('면접일 없으면 null', () => expect(const Preparation(companyId: 'lg', companyName: 'LG전자').ddayFrom(DateTime.now()), isNull));
  });

  group('표기', () {
    test('면접일', () => expect(formatMonthDayWeek(DateTime(2026, 10, 24)), '10월 24일 (토)'));
    test('알림', () => expect(const NotificationSettings(enabled: true, hour: 9, minute: 0).summary, '매일 오전 9시 · 켜짐'));
  });

  group('비밀번호', () {
    test('영문·숫자·특수문자 8~20자', () {
      // 피그마 이메일 가입: 영문·숫자·특수문자 조합 8-20자
      expect(AppPolicy.isValidPassword('abcd1234!'), isTrue);
      expect(AppPolicy.isValidPassword('abcd1234'), isFalse);
      expect(AppPolicy.isValidPassword('abcdefgh!'), isFalse);
      expect(AppPolicy.isValidPassword('ab12!'), isFalse);
      expect(AppPolicy.isValidPassword('abcd1234!abcd1234!abc'), isFalse);
      expect(AppPolicy.isValidEmail('jimin@kakao.com'), isTrue);
      expect(AppPolicy.isValidEmail('12351390@gmail'), isFalse);
    });
  });

  group('AppException.kindFromCode', () {
    test('서버 코드 우선', () {
      expect(AppException.kindFromCode('FEEDBACK_QUOTA_EXCEEDED', 400), AppErrorKind.feedbackQuotaExceeded);
      expect(AppException.kindFromCode('CONTENT_NOT_READY', 409), AppErrorKind.contentNotReady);
    });
    test('상태 코드 매핑', () {
      expect(AppException.kindFromCode(null, 401), AppErrorKind.unauthorized);
      expect(AppException.kindFromCode(null, 404), AppErrorKind.notFound);
      expect(AppException.kindFromCode(null, 422), AppErrorKind.validation);
      expect(AppException.kindFromCode(null, 503), AppErrorKind.server);
    });
    test('서버 메시지가 있으면 그걸 보여준다', () {
      expect(const AppException(AppErrorKind.server, message: '점검 중').userMessage, '점검 중');
      expect(const AppException(AppErrorKind.network).userMessage, isNotEmpty);
    });
  });
}
