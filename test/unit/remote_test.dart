// 다닷 서버 응답(명세 예시 모양)을 가짜 어댑터로 흉내 내서 Remote 저장소의 요청·변환을 확인한다.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/core/network/api_client.dart';
import 'package:swipe/core/storage/token_storage.dart';
import 'package:swipe/data/models/auth.dart';
import 'package:swipe/data/models/catalog.dart';
import 'package:swipe/data/models/interview.dart';
import 'package:swipe/data/remote/remote_repositories.dart';

class _MemTokens extends InMemoryTokenStorage {}

typedef _Handler = Object? Function(RequestOptions o);

/// "METHOD /path" → 응답 data (봉투로 감싼다). null 이면 204.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);
  final Map<String, _Handler> routes;
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(o);
    final key = '${o.method} ${o.uri.path}';
    final h = routes[key];
    if (h == null) {
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'data': null, 'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'no route $key'}}),
        404,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    final data = h(o);
    if (data == null) return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data, 'error': null}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiClient, _FakeAdapter, _MemTokens) _client(Map<String, _Handler> routes) {
  final adapter = _FakeAdapter(routes);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1', contentType: Headers.jsonContentType))..httpClientAdapter = adapter;
  final tokens = _MemTokens();
  return (ApiClient(baseUrl: 'https://api.test', tokenStorage: tokens, authEvents: AuthEvents(), dio: dio), adapter, tokens);
}

Map<String, dynamic> _body(RequestOptions o) => (o.data is String ? jsonDecode(o.data as String) : o.data) as Map<String, dynamic>;

void main() {
  test('이메일 로그인: 응답 토큰으로 내 정보를 바로 조회한다', () async {
    final (api, adapter, _) = _client({
      'POST /v1/auth/login': (_) => {'userId': 7, 'accessToken': 'tok-1', 'tokenType': 'Bearer', 'onboardingCompleted': true},
      'GET /v1/users/me': (_) => {'userId': 7, 'nickname': '지민', 'email': 'a@b.com', 'onboardingCompleted': true},
    });
    final s = await RemoteAuthRepository(api).signInWithEmail(email: 'a@b.com', password: 'abcd1234!');
    expect(s.accessToken, 'tok-1');
    expect(s.user.nickname, '지민');
    expect(s.user.loginMethod, LoginMethod.email);
    final me = adapter.calls.firstWhere((c) => c.uri.path == '/v1/users/me');
    expect(me.headers['Authorization'], 'Bearer tok-1');
    final login = adapter.calls.firstWhere((c) => c.uri.path == '/v1/auth/login');
    expect(login.headers['Authorization'], isNull);
  });

  test('카카오 신규 사용자 → SocialSignUpRequired, 약관 동의 후 가입', () async {
    final (api, adapter, _) = _client({
      'POST /v1/auth/social/kakao': (_) => {'status': 'SIGN_UP_REQUIRED', 'registrationToken': 'reg-1'},
      'POST /v1/auth/social/signup': (_) => {'userId': 1, 'accessToken': 'tok-2', 'onboardingCompleted': false},
      'GET /v1/users/me': (_) => {'userId': 1, 'nickname': '다닷1'},
      'GET /v1/users/me/onboarding': (_) => {'completed': false},
    });
    final repo = RemoteAuthRepository(api);
    Object? error;
    try {
      await repo.signInWithSocial(const SocialCredential(provider: SocialProvider.kakao, token: 'kakao-at'));
    } catch (e) {
      error = e;
    }
    expect(error, isA<SocialSignUpRequired>());
    expect(_body(adapter.calls.first), {'accessToken': 'kakao-at'});
    expect(adapter.calls.first.headers['Idempotency-Key'], isNotNull);

    final s = await repo.completeSocialSignup(registrationToken: 'reg-1', termIds: ['3', '4']);
    final signup = adapter.calls.firstWhere((c) => c.uri.path == '/v1/auth/social/signup');
    expect(_body(signup), {'registrationToken': 'reg-1', 'acceptedTermsIds': [3, 4]});
    expect(s.user.onboardingCompleted, isFalse);
    expect(s.user.loginMethod, LoginMethod.kakao);
  });

  test('앱 설정 약관 → acceptedTermsIds 로 쓸 id', () async {
    final (api, _, _) = _client({
      'GET /v1/app-config': (_) => {
            'termsUrl': 'https://t',
            'privacyPolicyUrl': 'https://p',
            'inquiryFormUrl': 'https://forms',
            'signupAvailable': true,
            'signupTerms': [
              {'termsId': 3, 'code': 'SERVICE', 'version': '1.0', 'title': '서비스 이용약관', 'url': 'https://t', 'required': true},
            ],
          },
    });
    final c = await RemoteAuthRepository(api).fetchAppConfig();
    expect(c.terms.single.id, '3');
    expect(c.terms.single.required, isTrue);
    expect(c.inquiryFormUrl, 'https://forms');
  });

  test('퀴즈: 한 문항씩 — 지금 문항만 내용이 있고 나머지는 자리', () async {
    final (api, adapter, _) = _client({
      'POST /v1/companies/10/quiz-sets/today': (_) => {'quizSetId': 55, 'submittedCount': 2, 'totalCount': 5, 'nextItemPosition': 3},
      'GET /v1/quiz-sets/55': (_) => {
            'quizSetId': 55,
            'submittedCount': 2,
            'totalCount': 5,
            'currentItem': {
              'itemId': 903,
              'questionId': 41,
              'position': 3,
              'question': '2025년 매출은?',
              'options': [
                {'optionId': 2, 'position': 2, 'text': '줄었다'},
                {'optionId': 1, 'position': 1, 'text': '늘었다'},
              ],
            },
          },
      'POST /v1/quiz-sets/55/answers': (_) => {'answerId': 1, 'submittedCount': 3, 'nextItemPosition': 4, 'status': 'IN_PROGRESS'},
    });
    final repo = RemoteQuizRepository(api);
    final set = await repo.fetchTodaySet('10');
    expect(set.questions.length, 5);
    expect(set.nextIndex, 2);
    expect(set.questions[2].id, '903');
    expect(set.questions[2].choices.map((c) => c.text), ['늘었다', '줄었다']);
    expect(set.questions[3].isPlaceholder, isTrue);

    await repo.submitAnswer(setId: set.id, questionId: '903', answer: '1');
    final answer = adapter.calls.last;
    expect(_body(answer), {'itemId': 903, 'selectedOptionId': 1});
  });

  test('면접 답변: 접수(attemptId) → 평가 조회 → 피드백', () async {
    var polls = 0;
    final (api, adapter, _) = _client({
      'POST /v1/interview-questions/8/attempts': (_) => {
            'taskId': 'u-1',
            'status': 'PENDING',
            'attemptId': 77,
            'attemptNumber': 2,
            'submittedAt': '2026-11-03T01:00:00Z',
            'usage': {'questionRemaining': 1, 'canSubmit': true},
          },
      'GET /v1/interview-attempts/77/evaluation': (_) => ++polls < 2
          ? {'status': 'PROCESSING', 'result': null}
          : {
              'status': 'SUCCEEDED',
              'result': {
                'scorePercent': 84,
                'readinessLabel': '준비 완료',
                'summaryFeedback': '경험을 잘 연결했어요',
                'overallFeedback': '총평',
                'criteria': [
                  // ERD v0.19 evaluation_criteria.code
                  {'code': 'COMPANY_UNDERSTANDING', 'name': '기업에 대한 이해', 'score': 22, 'maxScore': 25},
                  {'code': 'EXPERIENCE_SPECIFICITY', 'name': '경험의 구체성', 'score': 20, 'maxScore': 25},
                  {'code': 'ANSWER_LOGIC_STRUCTURE', 'name': '답변의 논리와 구성', 'score': 21, 'maxScore': 25},
                  {'code': 'EXPRESSION_CLARITY', 'name': '표현의 명확성', 'score': 21, 'maxScore': 25},
                ],
                'strengths': ['수치를 들었다'],
                'improvements': ['결론을 먼저'],
                'relatedMaterials': [
                  {'sourceType': 'EXPERIENCE', 'displayText': '동아리 회장', 'excerpt': '...', 'connectionReason': '리더십'},
                ],
              },
            },
    });
    final f = await RemoteInterviewRepository(api).submitAnswer(questionId: '8', content: '답변 내용', inputType: AnswerInputType.text);
    expect(_body(adapter.calls.first), {'text': '답변 내용'});
    expect(f.answerId, '77');
    expect(f.attempt, 2);
    expect(f.score, 84);
    expect(f.status, AnswerStatus.complete);
    expect(f.summary, '경험을 잘 연결했어요');
    expect(f.criteria.map((c) => c.key), [CriterionKey.companyInfo, CriterionKey.specificity, CriterionKey.logic, CriterionKey.clarity]);
    expect(f.retryRemaining, 1);
    expect(f.relatedExperience?.title, '동아리 회장');
  });

  test('홈: 준비 기업 + 기업별 대시보드 지표', () async {
    final (api, _, _) = _client({
      'GET /v1/users/me': (_) => {'userId': 1, 'nickname': '지민', 'onboardingCompleted': true},
      'GET /v1/users/me/companies': (_) => {
            'content': [
              {
                'company': {'companyId': 10, 'companyName': '기아', 'industry': '자동차'},
                'job': {'jobId': 3, 'jobName': '마케팅', 'isCustom': false},
                'interviewDate': '2026-11-05',
                'daysUntilInterview': 2,
                'learningMode': 'FOCUS',
                'version': 4,
                'quizToday': {'quizSetId': 55, 'submittedCount': 2, 'totalCount': 5, 'completed': false},
                'interviewToday': {'questionLimit': 3, 'questionUsed': 1},
              },
            ],
            'hasNext': false,
          },
      'GET /v1/users/me/dashboard': (o) => {
            'quizAccuracy': {'firstAnsweredCount': 10, 'firstCorrectCount': 7, 'percent': 70},
            'interviewEvaluationSummary': {'evaluatedQuestionCount': 2, 'averageScorePercent': 80},
          },
    });
    final h = await RemoteHomeRepository(api).fetchHome();
    final c = h.companies.single;
    expect(h.nickname, '지민');
    expect(c.companyName, '기아');
    expect(c.preparation.jobName, '마케팅');
    expect(c.dday, 2);
    expect(c.focusMode, isTrue);
    expect(c.quiz.done, 2);
    expect(c.interview.total, 3);
    expect(c.accuracy, 70);
    expect(c.completionRate, 80);
  });

  test('준비했던 기업: isActive 가 없어도 후보로 읽는다 (지금 준비 중인 기업은 isActive=true)', () async {
    final (api, _, _) = _client({
      'GET /v1/reviews/companies': (_) => {
            'content': [
              {'company': {'companyId': 10, 'name': '기아'}, 'quizQuestionCount': 30, 'interviewQuestionCount': 4},
              {'company': {'companyId': 11, 'name': 'LG생활건강'}, 'isActive': true, 'quizQuestionCount': 2, 'interviewQuestionCount': 0},
              {'company': {'companyId': 12, 'name': '농심'}, 'isActive': false, 'quizQuestionCount': 1, 'interviewQuestionCount': 1},
            ],
            'hasNext': false,
          },
    });
    final past = await RemoteProfileRepository(api).fetchPastPreparations();
    expect(past.map((p) => p.companyName), ['기아', '농심']);
    expect(past.first.quizCount, 30);
    expect(past.first.answerCount, 4);
  });

  test('204 로그아웃은 본문이 없다', () async {
    final (api, _, _) = _client({'POST /v1/auth/logout': (_) => null});
    await RemoteAuthRepository(api).signOut();
  });

  test('첫 설정: 기업 → 직무·면접일을 온보딩 단계로 저장하고 완료 때 남은 단계를 채운다', () async {
    var version = 1;
    final steps = <String>[];
    Map<String, dynamic> state() => {
          'version': version,
          'completedSteps': steps,
          'companyIds': [10],
          'assignments': [
            {
              'companyId': 10,
              'job': steps.contains('JOBS') ? {'jobId': 3, 'jobName': '마케팅', 'isCustom': false} : null,
              'interviewDate': steps.contains('DATES') ? '2026-12-01' : null,
            },
          ],
          'completed': false,
        };
    final (api, adapter, _) = _client({
      'GET /v1/users/me/onboarding': (_) => state(),
      'PATCH /v1/users/me/onboarding': (o) {
        final b = _body(o);
        expect(b['version'], version);
        steps.add(b['step'] as String);
        version++;
        return state();
      },
      'GET /v1/users/me/experiences': (_) => {'content': [{'experienceId': 5, 'title': 't', 'preview': 'p', 'version': 1}], 'hasNext': false},
      'POST /v1/users/me/onboarding/complete': (_) => {'completed': true, 'selectedCompanyId': 10},
      'GET /v1/users/me': (_) => {'userId': 1, 'nickname': '지민', 'provider': 'KAKAO', 'onboardingCompleted': true},
    });
    final repo = RemoteProfileRepository(api);
    var saved = await repo.savePreparations([const Preparation(companyId: '10', companyName: '기아')]);
    expect(steps, ['COMPANIES']);
    expect(saved.single.companyName, '기아');

    saved = await repo.savePreparations([
      Preparation(companyId: '10', companyName: '기아', jobId: '3', jobName: '마케팅', interviewDate: DateTime(2026, 12, 1)),
    ]);
    expect(steps, ['COMPANIES', 'JOBS', 'DATES']);
    final jobs = adapter.calls.where((c) => c.method == 'PATCH').map(_body).firstWhere((b) => b['step'] == 'JOBS');
    expect(jobs['payload'], {
      'assignments': [
        {'companyId': 10, 'job': {'jobId': 3}},
      ],
    });
    expect(saved.single.jobName, '마케팅');

    final user = await repo.completeOnboarding();
    expect(steps, ['COMPANIES', 'JOBS', 'DATES', 'EXPERIENCE', 'NOTIFICATION_GUIDANCE']);
    final exp = adapter.calls.where((c) => c.method == 'PATCH').map(_body).firstWhere((b) => b['step'] == 'EXPERIENCE');
    expect(exp['payload'], {'experienceIds': [5]});
    expect(adapter.calls.any((c) => c.uri.path == '/v1/users/me/onboarding/complete'), isTrue);
    expect(user.onboardingCompleted, isTrue);
    expect(user.loginMethod, LoginMethod.kakao);
  });

  test('면접 진입: WAIT_GENERATION 이면 새로 만들지 않고 작업을 기다린다', () async {
    var calls = 0;
    final (api, adapter, _) = _client({
      'GET /v1/companies/10/interview-entry': (o) => ++calls == 1
          ? {'companyId': 10, 'questionId': null, 'nextAction': 'WAIT_GENERATION', 'generationTask': {'taskId': 't-1', 'status': 'PROCESSING'}, 'dailyUsage': {'questionRemaining': 3}}
          : {'companyId': 10, 'questionId': 31, 'nextAction': 'ANSWER_QUESTION', 'generationTask': {'taskId': 't-1', 'status': 'SUCCEEDED', 'questionId': 31}, 'dailyUsage': {'questionRemaining': 3}},
    });
    final t = await RemoteInterviewRepository(api).fetchToday('10');
    expect(t.nextQuestionId, '31');
    expect(adapter.calls.any((c) => c.method == 'POST'), isFalse);
    expect(adapter.calls.last.uri.queryParameters['taskId'], 't-1');
  });

  test('면접 질문 상세 · 초안 저장 본문 {text, version}', () async {
    final (api, adapter, _) = _client({
      'GET /v1/interview-questions/8': (_) => {
            'questionId': 8,
            'company': {'companyId': 10, 'companyName': '기아'},
            'jobSnapshot': {'jobId': 3, 'jobName': '마케팅', 'isCustom': false},
            'question': '전기차 전략을 말해 보세요',
            'evidence': [
              {'reportTitle': '사업보고서', 'sectionTitle': '사업의 내용', 'quote': '전기차 판매 증가', 'sourceUrl': 'https://dart'},
            ],
            'draft': {'text': '초안', 'version': 4},
            'usage': {'questionRemaining': 2},
          },
      'PUT /v1/interview-questions/8/draft': (_) => {'questionId': 8, 'draft': {'text': '새 초안', 'version': 5}},
    });
    final repo = RemoteInterviewRepository(api);
    final q = await repo.fetchQuestion('8');
    expect(q.text, '전기차 전략을 말해 보세요');
    expect(q.tags, ['기아', '마케팅']);
    expect(q.evidence.single.excerpt, '전기차 판매 증가');
    expect(q.retryRemaining, 2);
    expect(await repo.fetchDraft('8'), '초안');
    await repo.saveDraft(questionId: '8', content: '새 초안');
    expect(_body(adapter.calls.last), {'text': '새 초안', 'version': 4});
  });

  test('면접 복습 목록: 최신 점수 · 완성 판정 · 작성 중', () async {
    final (api, _, _) = _client({
      'GET /v1/reviews/interviews': (o) {
        expect(o.uri.queryParameters.keys.toSet(), {'companyId', 'page', 'size'});
        return {
          'content': [
            {'questionId': 1, 'question': 'Q1', 'hasDraft': false, 'latestAttempt': {'attemptNumber': 2, 'submittedAt': '2026-11-03T01:00:00Z'}, 'latestScorePercent': 84, 'completionDecision': true, 'questionUsed': 2},
            {'questionId': 2, 'question': 'Q2', 'hasDraft': true, 'latestAttempt': null, 'latestScorePercent': null, 'completionDecision': null, 'questionUsed': 0},
          ],
          'hasNext': false,
        };
      },
    });
    final list = await RemoteRecordsRepository(api).fetchInterviewRecords(companyId: '10');
    expect(list[0].status, AnswerStatus.complete);
    expect(list[0].attempts, 2);
    expect(list[0].score, 84);
    expect(list[1].status, AnswerStatus.draft);
  });

  test('퀴즈 결과: company · 정답률 객체', () async {
    final (api, _, _) = _client({
      'GET /v1/quiz-sets/55/result': (_) => {
            'quizSetId': 55,
            'company': {'companyId': 10, 'companyName': '기아'},
            'correctCount': 4,
            'totalCount': 5,
            'accuracyBefore': {'firstAnsweredCount': 10, 'firstCorrectCount': 6, 'percent': 60},
            'accuracyAfter': {'firstAnsweredCount': 15, 'firstCorrectCount': 10, 'percent': 67},
            'items': [
              {
                'question': {
                  'itemId': 1,
                  'questionId': 41,
                  'position': 1,
                  'question': '매출은?',
                  'options': [
                    {'optionId': 1, 'position': 1, 'text': '늘었다'},
                    {'optionId': 2, 'position': 2, 'text': '줄었다'},
                  ],
                },
                'selectedOptionId': 2,
                'correctOptionId': 1,
                'isCorrect': false,
                'explanation': '늘었어요',
                'evidence': [],
              },
            ],
          },
    });
    final r = await RemoteQuizRepository(api).fetchResult('55');
    expect(r.companyName, '기아');
    expect(r.accuracyBefore, 60);
    expect(r.accuracyAfter, 67);
    expect(r.items.single.myAnswer, 'B. 줄었다');
    expect(r.items.single.correctAnswer, 'A. 늘었다');
  });

  test('탈퇴 본문: {confirm, password} / {confirm, socialCredential}', () async {
    final (api, adapter, _) = _client({'DELETE /v1/users/me': (_) => null});
    final repo = RemoteAuthRepository(api);
    await repo.deleteAccount(password: 'abcd1234!');
    expect(_body(adapter.calls.last), {'confirm': true, 'password': 'abcd1234!'});
    await repo.deleteAccount(credential: const SocialCredential(provider: SocialProvider.kakao, token: 'k'));
    expect(_body(adapter.calls.last), {'confirm': true, 'socialCredential': {'accessToken': 'k'}});
    expect(adapter.calls.last.headers['Idempotency-Key'], isNotNull);
  });
}
