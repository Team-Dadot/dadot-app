// 인증 갱신·제출 복구 회귀 테스트. 실제 API·AI·DB를 호출하지 않는다.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swipe/core/config/app_config.dart';
import 'package:swipe/core/providers.dart';
import 'package:swipe/core/session/session_controller.dart';
import 'package:swipe/core/services/social_auth_service.dart';
import 'package:swipe/data/repositories/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe/core/config/app_policy.dart';
import 'package:swipe/core/error/app_exception.dart';
import 'package:swipe/core/network/api_client.dart';
import 'package:swipe/core/storage/local_store.dart';
import 'package:swipe/core/storage/token_storage.dart';
import 'package:swipe/data/models/auth.dart';
import 'package:swipe/data/models/interview.dart';
import 'package:swipe/data/remote/remote_repositories.dart';

class _RecordTokens extends TokenStorage {
  _RecordTokens([this.raw]);
  String? raw;
  @override
  Future<String?> readRecord() async => raw;
  @override
  Future<void> writeRecord(String? value) async { raw = value; }
}

class _Reply {
  _Reply(this.status, this.body);
  final int status;
  final Object? body;
}
_Reply ok(Object? data) => _Reply(200, {'success': true, 'data': data, 'error': null});
_Reply fail(int status, String code) => _Reply(status, {'success': false, 'data': null,
  'error': {'code': code, 'message': '검토용 오류 안내'}});

class _Call {
  _Call(RequestOptions options)
      : method = options.method, path = options.uri.path,
        headers = Map<String, dynamic>.from(options.headers), data = options.data;
  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Object? data;
  Map<String, dynamic> get body => data is String
      ? (jsonDecode(data as String) as Map).cast<String, dynamic>()
      : (data as Map).cast<String, dynamic>();
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handle);
  final FutureOr<_Reply> Function(RequestOptions) handle;
  final List<_Call> calls = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? stream, Future<void>? cancel) async {
    calls.add(_Call(o));
    final reply = await handle(o);
    return ResponseBody.fromString(jsonEncode(reply.body), reply.status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

(ApiClient, _RecordTokens, AuthEvents) client(_Adapter adapter, {_RecordTokens? storage}) {
  final tokens = storage ?? _RecordTokens();
  final events = AuthEvents();
  addTearDown(events.dispose);
  final dio = Dio(BaseOptions(baseUrl: 'https://audit.invalid/v1', contentType: Headers.jsonContentType))
    ..httpClientAdapter = adapter;
  return (ApiClient(baseUrl: 'https://audit.invalid', tokenStorage: tokens, authEvents: events, dio: dio), tokens, events);
}

Map<String, dynamic> question({int version = 1}) => {
  'questionId': 8, 'company': {'companyId': 10, 'companyName': '검토 기업'},
  'question': '검토 질문', 'evidence': [],
  'draft': {'text': '원래 답변', 'version': version},
  'usage': {'questionRemaining': 2, 'canSubmit': true},
};

const _user = AppUser(id: '1', nickname: '검토', loginMethod: LoginMethod.email, onboardingCompleted: true);
class _OwnedSession extends SessionController {
  @override
  SessionState build() => const SessionState(status: SessionStatus.ready, user: _user);
  void loginAgain() { state = const SessionState(status: SessionStatus.ready, user: _user); }
}
class _LogoutAuth extends Fake implements AuthRepository {
  @override
  Future<void> signOut() async {}
}
class _Profile extends Fake implements ProfileRepository {
  @override
  void clearCache() {}
}

void main() {
  test('비밀번호 길이 경계·Unicode 공백·제어문자', () {
    expect(AppPolicy.isValidPassword('Ab1234!x'), isTrue);
    expect(AppPolicy.isValidPassword('Aa1!${'b' * 16}'), isTrue);
    expect(AppPolicy.isValidPassword('Aa1!${'b' * 17}'), isFalse);
    for (final separator in [' ', '\u00a0', '\u200b', '\n', '\u0000']) {
      expect(AppPolicy.isValidPassword('Aa1234!${separator}x'), isFalse);
    }
  });

  test('동시 401은 한 번 갱신하고 원래 키·본문을 보존한다', () async {
    var refreshes = 0;
    final adapter = _Adapter((o) async {
      if (o.uri.path == '/v1/auth/refresh') {
        refreshes++;
        expect(o.headers['Authorization'], isNull);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return ok({'accessToken': 'a-new', 'refreshToken': 'r-new'});
      }
      if (o.headers['Authorization'] == 'Bearer a-old') return fail(401, 'UNAUTHENTICATED');
      return ok({'done': true});
    });
    final (api, tokens, _) = client(adapter);
    await tokens.save(accessToken: 'a-old', refreshToken: 'r-old');
    await Future.wait([
      api.post('/first', body: {'text': 'one'}, idempotencyKey: 'key-1'),
      api.post('/second', body: {'text': 'two'}, idempotencyKey: 'key-2'),
    ]);
    expect(refreshes, 1);
    for (final path in ['/v1/first', '/v1/second']) {
      final calls = adapter.calls.where((c) => c.path == path).toList();
      expect(calls.length, 2);
      expect(calls.first.headers['Idempotency-Key'], calls.last.headers['Idempotency-Key']);
      expect(calls.first.body, calls.last.body);
    }
    expect(await tokens.readAccessToken(), 'a-new');
    expect(await tokens.readRefreshToken(), 'r-new');
    expect((await tokens.readSession())?.refreshKey, isNull);
  });

  test('갱신 503 후 앱 재시작을 흉내 내도 같은 키·본문으로 복구한다', () async {
    var refreshes = 0;
    final adapter = _Adapter((o) {
      if (o.uri.path == '/v1/auth/refresh') {
        refreshes++;
        if (refreshes == 1) return fail(503, 'SERVICE_UNAVAILABLE');
        return ok({'accessToken': 'a-new', 'refreshToken': 'r-new'});
      }
      return o.headers['Authorization'] == 'Bearer a-new' ? ok({'done': true}) : fail(401, 'UNAUTHENTICATED');
    });
    final (api, tokens, _) = client(adapter);
    await tokens.save(accessToken: 'a-old', refreshToken: 'r-old');
    await expectLater(api.get('/protected'), throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.server)));
    expect(await tokens.readAccessToken(), 'a-old');
    final restarted = _RecordTokens(tokens.raw);
    final (again, _, _) = client(adapter, storage: restarted);
    await again.get('/protected');
    final requests = adapter.calls.where((c) => c.path == '/v1/auth/refresh').toList();
    expect(requests.length, 2);
    expect(requests[0].headers['Idempotency-Key'], requests[1].headers['Idempotency-Key']);
    expect(requests[0].body, requests[1].body);
    expect(await restarted.readAccessToken(), 'a-new');
  });

  test('갱신 토큰이 401로 거절되면 재귀 없이 로그아웃한다', () async {
    final adapter = _Adapter((_) => fail(401, 'UNAUTHENTICATED'));
    final (api, tokens, events) = client(adapter);
    var expired = 0;
    final subscription = events.onUnauthorized.listen((_) => expired++);
    addTearDown(subscription.cancel);
    await tokens.save(accessToken: 'a-old', refreshToken: 'r-old');
    await expectLater(api.get('/protected'), throwsA(isA<AppException>()));
    await Future<void>.delayed(Duration.zero);
    expect(await tokens.readAccessToken(), isNull);
    expect(expired, 1);
    expect(adapter.calls.length, 2);
  });

  test('탈퇴 비밀번호 오류 401은 유효한 로그인을 지우면 안 된다', () async {
    final adapter = _Adapter((o) => o.uri.path == '/v1/auth/refresh'
        ? ok({'accessToken': 'a-new', 'refreshToken': 'r-new'})
        : fail(401, 'REAUTHENTICATION_FAILED'));
    final (api, tokens, _) = client(adapter);
    await tokens.save(accessToken: 'a-valid', refreshToken: 'r-valid');
    await expectLater(api.delete('/users/me', body: {'confirm': true, 'password': 'wrong'}), throwsA(isA<AppException>()));
    // access 만료가 아닌 본인 인증 실패인데 현재 구현은 갱신 후 세션까지 지운다.
    expect(await tokens.readAccessToken(), isNotNull);
    expect(adapter.calls.where((c) => c.path == '/v1/auth/refresh'), isEmpty);
  });

  test('로그인 응답의 Refresh Token을 유지하고 가입·재설정 인증은 Bearer를 보내지 않는다', () async {
    final adapter = _Adapter((o) {
      if (o.uri.path == '/v1/auth/login') return ok({'accessToken': 'login-a', 'refreshToken': 'login-r', 'userId': 1, 'onboardingCompleted': true});
      if (o.uri.path == '/v1/users/me') return ok({'userId': 1, 'email': 'audit@example.test', 'nickname': '검토', 'onboardingCompleted': true});
      return ok({'verificationToken': 'verification'});
    });
    final (api, tokens, _) = client(adapter);
    await tokens.save(accessToken: 'a-stored', refreshToken: 'r-stored');
    final repo = RemoteAuthRepository(api);
    final session = await repo.signInWithEmail(email: 'audit@example.test', password: 'legacy');
    expect(session.refreshToken, 'login-r');
    await repo.verifyEmailCode(verificationId: 'signup-check', code: '123456');
    expect(adapter.calls.last.headers['Authorization'], isNull);
  });

  test('비밀번호 변경 인증 확인에는 저장된 Bearer를 전달한다', () async {
    final adapter = _Adapter((o) {
      if (o.uri.path == '/v1/users/me') return ok({'userId': 1, 'email': 'audit@example.test', 'nickname': '검토', 'onboardingCompleted': true});
      if (o.uri.path == '/v1/auth/email-verifications') return ok({'verificationId': 'password-check'});
      if (o.uri.path.endsWith('/verify')) return ok({'verificationToken': 'verification'});
      return ok(null);
    });
    final (api, tokens, _) = client(adapter);
    await tokens.save(accessToken: 'a-stored', refreshToken: 'r-stored');
    final repo = RemoteAuthRepository(api);
    await repo.sendPasswordCode();
    await repo.changePassword(code: '123456', newPassword: 'Ab1234!x');
    final verification = adapter.calls.firstWhere((c) => c.path.endsWith('/verify'));
    expect(verification.headers['Authorization'], 'Bearer a-stored');
  });

  test('면접 응답 유실·재시작 후에도 원 제출의 본문·키로만 복구한다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    var posts = 0;
    final adapter = _Adapter((o) {
      posts++;
      if (posts == 1) throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout);
      return ok({'attemptId': 77, 'attemptNumber': 1});
    });
    final (api, _, _) = client(adapter);
    final first = RemoteInterviewRepository(api, store: store, ownerId: () => '1');
    await expectLater(first.submitAnswerForEvaluation(questionId: '8', content: '원래 답변', inputType: AnswerInputType.text), throwsA(isA<AppException>()));
    final restarted = RemoteInterviewRepository(api, store: store, ownerId: () => '1');
    expect(await restarted.submitAnswerForEvaluation(questionId: '8', content: '새 답변', inputType: AnswerInputType.text), '77');
    expect(adapter.calls[0].headers['Idempotency-Key'], adapter.calls[1].headers['Idempotency-Key']);
    expect(adapter.calls[0].body, adapter.calls[1].body);
    expect(adapter.calls[1].body['text'], '원래 답변');
    await restarted.acknowledgeSubmission('8', '77');
    expect(restarted.pendingSubmission('8'), isNull);
  });

  test('로그아웃으로 로컬 데이터를 지우면 메모리의 제출 복구 상태도 사라져야 한다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final adapter = _Adapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout));
    final (api, _, _) = client(adapter);
    final repo = RemoteInterviewRepository(api, store: store, ownerId: () => '1');
    await expectLater(repo.submitAnswerForEvaluation(questionId: '8', content: '원래 답변', inputType: AnswerInputType.text), throwsA(isA<AppException>()));
    await store.clearUserData();
    // Repository provider가 계정 변경을 watch하지 않아 같은 인스턴스가 살아 있다.
    expect(repo.pendingSubmission('8'), isNull);
  });

  test('초안 버전 충돌 후 다음 제출은 최신 버전·새 키로 복구한다', () async {
    var serverVersion = 1;
    final adapter = _Adapter((o) {
      if (o.method == 'GET') return ok(question(version: serverVersion));
      final body = o.data is String ? jsonDecode(o.data as String) : o.data;
      return (body as Map)['draftVersion'] == serverVersion
          ? ok({'attemptId': 77, 'attemptNumber': 1}) : fail(409, 'VERSION_CONFLICT');
    });
    final (api, _, _) = client(adapter);
    final repo = RemoteInterviewRepository(api);
    await repo.fetchQuestion('8');
    serverVersion = 2;
    await expectLater(repo.submitAnswerForEvaluation(questionId: '8', content: '원래 답변', inputType: AnswerInputType.text),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'VERSION_CONFLICT')));
    expect(await repo.submitAnswerForEvaluation(questionId: '8', content: '수정한 답변', inputType: AnswerInputType.text), '77');
    final posts = adapter.calls.where((c) => c.method == 'POST').toList();
    expect(posts.map((c) => c.body['draftVersion']), [1, 2]);
    expect(posts.last.headers['Idempotency-Key'], isNot(posts.first.headers['Idempotency-Key']));
    expect(posts.last.body['text'], '수정한 답변');
  });

  test('완료된 실제 0점은 보존하고 대기·실패·조회 오류를 점수로 만들지 않는다', () async {
    for (final lookupFailure in [false, true]) {
      final adapter = _Adapter((o) {
        if (o.uri.path == '/v1/interview-questions/8') return ok(question());
        if (o.uri.path == '/v1/interview-questions/8/attempts') return ok({'content': [
          for (var i = 1; i <= 3; i++) {'attemptId': i, 'questionId': 8, 'attemptNumber': i, 'text': '답변 $i', 'submittedAt': '2026-11-11T12:00:00Z'},
        ]});
        if (o.uri.path == '/v1/interview-attempts/1/evaluation') return ok({'status': 'SUCCEEDED', 'result': {'scorePercent': 0, 'criteria': []}});
        if (o.uri.path == '/v1/interview-attempts/2/evaluation') return ok({'status': 'PROCESSING', 'result': null});
        return lookupFailure ? fail(503, 'SERVICE_UNAVAILABLE') : ok({'status': 'FAILED', 'result': null});
      });
      final (api, _, _) = client(adapter);
      final detail = await RemoteRecordsRepository(api).fetchInterviewRecord('8');
      expect(detail.attempts.length, 1);
      expect(detail.attempts.single.score, 0);
      expect(detail.evaluationEntries.map((e) => e.status), [EvaluationStatus.succeeded, EvaluationStatus.processing,
        lookupFailure ? EvaluationStatus.unknown : EvaluationStatus.failed]);
      expect(detail.evaluationEntries.skip(1).every((e) => e.feedback == null), isTrue);
    }
  });

  test('영문 예외·서버 메시지는 한글 공통 안내로 바꾼다', () {
    expect(const AppException(AppErrorKind.server, message: 'Internal Server Error').userMessage, contains('일시적인 오류'));
    expect(const AppException(AppErrorKind.server, message: 'DioException: 오류 원문').userMessage, contains('일시적인 오류'));
    expect(const AppException(AppErrorKind.validation, message: '이메일을 확인해 주세요.').userMessage, '이메일을 확인해 주세요.');
    expect(const AppException(AppErrorKind.conflict, code: 'QUESTION_LIMIT_EXCEEDED').userMessage, isNot(contains('내일')));
  });
  test('Access 만료 후 재시도에서 본인 인증이 실패해도 갱신된 로그인은 유지한다', () async {
    final adapter = _Adapter((o) {
      if (o.uri.path == '/v1/auth/refresh') return ok({'accessToken': 'a-new', 'refreshToken': 'r-new'});
      return o.headers['Authorization'] == 'Bearer a-old'
          ? fail(401, 'UNAUTHENTICATED') : fail(401, 'REAUTHENTICATION_FAILED');
    });
    final (api, tokens, _) = client(adapter);
    await tokens.save(accessToken: 'a-old', refreshToken: 'r-old');
    await expectLater(api.delete('/users/me', body: {'confirm': true, 'password': 'wrong'}),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'REAUTHENTICATION_FAILED')));
    expect(await tokens.readAccessToken(), 'a-new');
    expect(adapter.calls.where((c) => c.path == '/v1/auth/refresh').length, 1);
  });

  test('로그아웃 후 늦게 도착한 제출 응답은 복구 기록을 다시 저장하지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    final sent = Completer<void>();
    final response = Completer<_Reply>();
    final adapter = _Adapter((_) { sent.complete(); return response.future; });
    final (api, _, _) = client(adapter);
    final repo = RemoteInterviewRepository(api, store: store, ownerId: () => '1');
    final request = repo.submitAnswerForEvaluation(questionId: '8', content: '원래 답변', inputType: AnswerInputType.text);
    final checked = expectLater(request, throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.unauthorized)));
    await sent.future;
    repo.dispose();
    await store.clearUserData();
    response.complete(ok({'attemptId': 77, 'attemptNumber': 1}));
    await checked;
    expect(repo.pendingSubmission('8'), isNull);
    expect(prefs.getKeys().where((key) => key.startsWith(LocalStore.pendingInterviewPrefix)), isEmpty);
    final restarted = RemoteInterviewRepository(api, store: store, ownerId: () => '1');
    expect(restarted.pendingSubmission('8'), isNull);
  });

  test('SessionController 로그아웃·재로그인 시 실제 Repository provider도 새로 생성한다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final adapter = _Adapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout));
    final (api, tokens, _) = client(adapter);
    await tokens.save(accessToken: 'a-valid', refreshToken: 'r-valid');
    final session = _OwnedSession();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tokenStorageProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith(() => session),
      authRepositoryProvider.overrideWithValue(_LogoutAuth()),
      profileRepositoryProvider.overrideWithValue(_Profile()),
      socialAuthServiceProvider.overrideWithValue(const FakeSocialAuthService()),
      appConfigProvider.overrideWithValue(const AppConfig(useMock: false, apiBaseUrl: 'https://audit.invalid',
        privacyPolicyUrl: '', termsUrl: '', inquiryFormUrl: '', mockLatency: Duration.zero, kakaoNativeAppKey: '')),
    ]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    final before = container.read(interviewRepositoryProvider);
    await expectLater(before.submitAnswerForEvaluation(questionId: '8', content: '원래 답변', inputType: AnswerInputType.text),
      throwsA(isA<AppException>()));
    await session.signOut();
    expect(container.read(sessionProvider).status, SessionStatus.unauthenticated);
    expect(before.pendingSubmission('8'), isNull);
    session.loginAgain();
    final after = container.read(interviewRepositoryProvider);
    expect(identical(before, after), isFalse);
    expect(after.pendingSubmission('8'), isNull);
  });

}
