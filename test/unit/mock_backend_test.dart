import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/core/config/app_policy.dart';
import 'package:swipe/core/error/app_exception.dart';
import 'package:swipe/data/mock/mock_backend.dart';
import 'package:swipe/data/mock/mock_data.dart';
import 'package:swipe/data/models/auth.dart';
import 'package:swipe/data/models/catalog.dart';
import 'package:swipe/data/models/interview.dart';
import 'package:swipe/data/models/quiz.dart';

void main() {
  late DateTime now;
  late MockBackend b;

  setUp(() {
    now = DateTime(2026, 10, 14, 9);
    b = MockBackend(latency: Duration.zero, now: () => now);
  });

  Future<void> onboard({DateTime? kiaInterview}) async {
    await b.run(() => b.signIn(const SocialCredential(provider: SocialProvider.kakao, token: 't')));
    await b.run(() => b.savePreparations([
          Preparation.fromCompany(MockData.company('kia')).copyWith(jobId: 'marketing', jobName: '마케팅', interviewDate: kiaInterview),
          Preparation.fromCompany(MockData.company('lg')).copyWith(jobId: 'marketing', jobName: '마케팅'),
        ]));
    await b.run(b.completeOnboarding);
  }

  /// 홀수 번째 정답, 짝수 번째 오답
  Future<QuizSet> solveTodayQuiz() async {
    final set = await b.run(() => b.todaySet('kia'));
    for (final q in set.questions) {
      final seed = MockData.quizBank('kia').firstWhere((s) => s.id == q.id);
      final answer = q.kind == QuizKind.choice
          ? (q.order.isOdd ? seed.correctChoiceId : q.choices.firstWhere((c) => c.id != seed.correctChoiceId).id)
          : (q.order.isOdd ? seed.keywords.first : '모르겠어요');
      await b.run(() => b.answerQuiz(setId: set.id, questionId: q.id, answer: answer));
    }
    return set;
  }

  test('신규 로그인 → 첫 설정 필요', () async {
    final s = await b.run(() => b.signIn(const SocialCredential(provider: SocialProvider.kakao, token: 't')));
    expect(s.isNewUser, isTrue);
    expect(s.user.onboardingCompleted, isFalse);
    expect(s.user.loginMethod, LoginMethod.kakao);
  });

  test('준비 기업은 최대 5개', () async {
    await b.run(() => b.signIn(const SocialCredential(provider: SocialProvider.kakao, token: 't')));
    final six = MockData.companies.take(6).map(Preparation.fromCompany).toList();
    expect(() => b.savePreparations(six), throwsA(isA<AppException>()));
  });

  test('퀴즈: 객관식 3 + 주관식 2, 정답률 · 복습 · 홈 진행률', () async {
    await onboard();
    final set = await solveTodayQuiz();
    expect(set.questions.where((q) => q.kind == QuizKind.choice).length, AppPolicy.quizChoiceCount);
    expect(set.questions.where((q) => q.kind == QuizKind.short).length, AppPolicy.quizShortCount);

    final result = await b.run(() => b.quizResult(set.id));
    expect(result.correctCount, 3);
    expect(result.accuracyAfter, 60);
    // 문제별 해설: 내 답 · 정답이 "C. 늘었다" 형태로 온다
    final choiceItem = result.items.firstWhere((i) => set.questions.any((q) => q.id == i.questionId && q.kind == QuizKind.choice));
    expect(choiceItem.myAnswer, matches(RegExp(r'^[A-D]\. ')));
    expect(choiceItem.correctAnswer, matches(RegExp(r'^[A-D]\. ')));
    expect(b.quizReview(companyId: 'kia').where((r) => r.wrong).length, 2);

    final kia = b.home().byId('kia')!;
    expect(kia.quiz.isDone, isTrue);
    expect(kia.accuracy, 60);
  });

  test('오답 다시 풀어 맞히면 누적 정답률에 반영', () async {
    await onboard();
    await solveTodayQuiz();
    final wrong = b.quizReview(companyId: 'kia').firstWhere((r) => r.wrong && r.question.kind == QuizKind.choice);
    final seed = MockData.quizBank('kia').firstWhere((s) => s.id == wrong.question.id);
    final r = await b.run(() => b.retryQuiz(wrong.id, seed.correctChoiceId));
    expect(r.correct, isTrue);
    expect(b.home().byId('kia')!.accuracy, 80);
  });

  test('면접일 3일 전이면 집중 모드 · D-day', () async {
    await onboard(kiaInterview: DateTime(2026, 10, 17));
    final kia = b.home().byId('kia')!;
    expect(kia.dday, 3);
    expect(kia.focusMode, isTrue);
    expect(b.home().byId('lg')!.focusMode, isFalse);
  });

  test('면접: 오늘 3개, 같은 질문 하루 3번까지, 다음 날 초기화', () async {
    await onboard();
    final today = await b.run(() => b.todayInterview('kia'));
    expect(today.questionIds.length, AppPolicy.interviewDailyCount);
    final qid = today.nextQuestionId!;
    const answer = '저는 기아가 전동화 전환을 빠르게 추진하는 점에 끌려 지원했습니다. 서포터즈로 6개월간 SNS를 운영하며 팔로워를 2배로 늘렸습니다.';
    for (var i = 0; i < AppPolicy.retryPerQuestionDaily; i++) {
      final f = await b.run(() => b.submitAnswer(questionId: qid, content: answer, inputType: AnswerInputType.text));
      expect(f.attempt, i + 1);
      expect(f.criteria.length, AppPolicy.criteriaCount);
      expect(f.criteria.every((c) => c.max == AppPolicy.criterionMaxScore), isTrue);
    }
    expect(
      () => b.submitAnswer(questionId: qid, content: answer, inputType: AnswerInputType.text),
      throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.feedbackQuotaExceeded)),
    );
    expect(b.home().byId('kia')!.interview.done, 1);

    now = now.add(const Duration(days: 1));
    await b.run(() {});
    expect(b.question(qid).retryRemaining, AppPolicy.retryPerQuestionDaily);
  });

  test('완성 기준: 4개 항목 중 3개 이상 충족 · 100점 만점', () async {
    await onboard();
    final qid = (await b.run(() => b.todayInterview('kia'))).nextQuestionId!;
    final f = await b.run(() => b.submitAnswer(
          questionId: qid,
          content: '저는 기아의 PBV 사업과 전동화 방향에 기여하고 싶어서 지원했습니다. 먼저 대학 서포터즈로 6개월간 SNS를 운영하며 '
              '콘텐츠 기획을 담당해 팔로워를 2배로 늘린 경험이 있습니다. 또한 전기차 고객 인터뷰 프로젝트를 맡아 30명의 의견을 정리했습니다. '
              '그래서 PBV 같은 새 모빌리티 사업을 고객 언어로 알리는 마케팅에 기여하겠습니다.',
          inputType: AnswerInputType.text,
        ));
    expect(f.status, f.metCount >= AppPolicy.completeMetCount ? AnswerStatus.complete : AnswerStatus.needsWork);
    expect(f.score, f.criteria.fold<int>(0, (s, c) => s + c.score));
    expect(f.score, lessThanOrEqualTo(100));
  });

  test('임시저장은 복습에 작성 중으로, 답하면 사라짐', () async {
    await onboard();
    final qid = (await b.run(() => b.todayInterview('kia'))).nextQuestionId!;
    await b.run(() => b.saveDraft(qid, '쓰는 중'));
    expect(b.interviewRecords(companyId: 'kia').single.status, AnswerStatus.draft);
    await b.run(() => b.submitAnswer(questionId: qid, content: '저는 기아의 전동화 방향에 공감해서 지원했습니다. 서포터즈 경험이 있습니다.', inputType: AnswerInputType.text));
    expect(b.draft(qid), isNull);
    expect(b.interviewRecords(companyId: 'kia').single.attempts, 1);
  });

  test('경험 나누기: 줄머리 기호로 나눈다', () async {
    await onboard();
    final drafts = b.splitExperiences('- 대학 서포터즈 SNS 6개월 운영, 팔로워 2배\n- 팀 프로젝트 주문 처리 API 문제 해결');
    expect(drafts.length, 2);
    expect(drafts.first.title, '대학 서포터즈 SNS 6개월 운영');
    b.addExperiences(drafts);
    expect(b.experiences().length, 2);
  });

  test('탈퇴하면 로그인 필요', () async {
    await onboard();
    await b.run(b.deleteAccount);
    expect(b.me, throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.unauthorized)));
  });
}
