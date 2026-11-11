import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/core/config/app_policy.dart';
import 'package:swipe/core/error/app_exception.dart';
import 'package:swipe/core/network/api_client.dart';
import 'package:swipe/data/models/catalog.dart';
import 'package:swipe/data/models/settings.dart';
import 'package:swipe/features/common/format.dart';

void main() {
  group('D-day', () {
    final prep = Preparation(companyId: 'kia', companyName: '기아', interviewDate: DateTime(2026, 10, 24));
    test('남은 날', () => expect(prep.ddayFrom(DateTime(2026, 10, 14, 23)), 10));
    test('표기', () {
      expect(formatDday(10), 'D-10');
      expect(formatDday(0), 'D-day');
      expect(formatDday(-2), 'D+2');
    });
    test('면접일 없으면 null', () => expect(const Preparation(companyId: 'lg', companyName: 'LG전자').ddayFrom(DateTime.now()), isNull));
  });

  group('표기', () {
    test('면접일', () => expect(formatMonthDayWeek(DateTime(2026, 10, 24)), '10월 24일 (토)'));
    test('알림', () => expect(const NotificationSettings(enabled: true, hour: 9, minute: 0).summary, '매일 오전 9시 · 켜짐'));
  });

  group('비밀번호', () {
    test('영문·숫자·특수문자 포함 8~20자 (서버 규칙)', () {
      expect(AppPolicy.isValidPassword('abcd1234!'), isTrue);
      expect(AppPolicy.isValidPassword('abcd1234'), isFalse);
      expect(AppPolicy.isValidPassword('abcdefgh!'), isFalse);
      expect(AppPolicy.isValidPassword('ab12!'), isFalse);
      expect(AppPolicy.isValidPassword('abcd 1234'), isFalse);
      expect(AppPolicy.isValidPassword('a1${'b' * 63}'), isFalse);
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
      // 다닷 서버: 한도 소진 409, 트래픽 제한 429
      expect(AppException.kindFromCode(null, 409), AppErrorKind.feedbackQuotaExceeded);
      expect(AppException.kindFromCode('RATE_LIMIT_EXCEEDED', 429), AppErrorKind.server);
      expect(AppException.kindFromCode('INVALID_INPUT', 400), AppErrorKind.validation);
    });
  });

  group('응답 봉투', () {
    test('성공이면 data 만', () {
      expect(ApiClient.unwrap(200, {'success': true, 'data': {'id': 1}, 'error': null}), {'id': 1});
      expect(ApiClient.unwrap(204, null), isNull);
    });
    test('실패면 error.code · message 로 AppException', () {
      expect(
        () => ApiClient.unwrap(200, {
          'success': false,
          'data': null,
          'error': {'code': 'RESOURCE_NOT_FOUND', 'message': '없어요'},
        }),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.notFound).having((e) => e.userMessage, 'message', '없어요')),
      );
    });
    test('서버 메시지가 있으면 그걸 보여준다', () {
      expect(const AppException(AppErrorKind.server, message: '점검 중').userMessage, '점검 중');
      expect(const AppException(AppErrorKind.network).userMessage, isNotEmpty);
    });
  });
}
