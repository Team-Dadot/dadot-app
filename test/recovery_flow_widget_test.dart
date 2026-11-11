// 검토용 UI 재현 테스트. 가짜 저장소만 사용한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/core/error/app_exception.dart';
import 'package:swipe/core/providers.dart';
import 'package:swipe/data/models/interview.dart';
import 'package:swipe/data/models/quiz.dart';
import 'package:swipe/data/models/records.dart';
import 'package:swipe/data/repositories/repositories.dart';
import 'package:swipe/features/quiz/quiz_screen.dart';
import 'package:swipe/features/quiz/quiz_widgets.dart';
import 'package:swipe/features/review/answer_view_screen.dart';
import 'package:swipe/features/interview/feedback_screen.dart';

QuizQuestion q(String id, int order) => QuizQuestion(id: id, order: order, tags: const [],
  prompt: '검토 질문 $order', title: '검토 질문 $order', choices: const [
    QuizChoice(id: '1', text: '선택지 하나'), QuizChoice(id: '2', text: '선택지 둘'),
  ]);

class _Quiz extends Fake implements QuizRepository {
  int loads = 0;
  int submits = 0;
  @override
  Future<QuizSet> fetchTodaySet(String companyId) async {
    loads++;
    if (loads == 2) throw const AppException(AppErrorKind.network);
    return QuizSet(id: '55', companyId: companyId, companyName: '검토 기업', questions: [q('1', 1), q('2', 2)],
      answers: submits == 0 ? [] : [const QuizAnswerResult(questionId: '1', answer: '1', correct: false, explanation: '')]);
  }
  @override
  Future<QuizAnswerResult> submitAnswer({required String setId, required String questionId, required String answer}) async {
    submits++;
    return QuizAnswerResult(questionId: questionId, answer: answer, correct: true, explanation: '검토');
  }
}

class _Records extends Fake implements RecordsRepository {
  _Records(this.detail);
  final InterviewRecordDetail detail;
  @override
  Future<InterviewRecordDetail> fetchInterviewRecord(String questionId) async => detail;
}

class _Cancelled extends Fake implements InterviewRepository {
  int reads = 0;
  int retries = 0;
  @override
  Future<AnswerFeedback> fetchFeedback(String answerId) async {
    reads++;
    throw EvaluationFailed(answerId: answerId, status: EvaluationStatus.cancelled);
  }
  @override
  Future<void> retryEvaluation(String answerId) async { retries++; }
}

void main() {
  testWidgets('퀴즈: 제출 후 다음 조회 실패에서 재시도해도 제출은 1번만 발생', (tester) async {
    final repo = _Quiz();
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null,
      overrides: [quizRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: QuizScreen(companyId: '10'))));
    await tester.pumpAndSettle();
    expect(tester.widget<QuizPrompt>(find.byType(QuizPrompt)).question.id, '1');
    await tester.tap(find.text('선택지 하나'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repo.submits, 1);
    expect(find.text('연결이 원활하지 않아요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(repo.submits, 1);
    expect(tester.widget<QuizPrompt>(find.byType(QuizPrompt)).question.id, '2');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('복습: 처리 중에는 점수를 숨기고 이전 완료 평가를 선택할 수 있다', (tester) async {
    final feedback = AnswerFeedback(answerId: '1', questionId: '8', content: '검토 답변',
      inputType: AnswerInputType.text, attempt: 1, submittedAt: DateTime(2026, 11, 11),
      score: 84, criteria: const [], metCount: 4, status: AnswerStatus.complete,
      goodPoint: '검토 강점', improvement: '', retryRemaining: 1);
    final detail = InterviewRecordDetail(question: const InterviewQuestion(id: '8', companyId: '10',
      companyName: '검토 기업', tags: [], text: '검토 질문', evidence: [],
      canSubmit: false, blockedReason: 'TASK_PROCESSING', retryRemaining: 1),
      attempts: [feedback], evaluations: [
        InterviewAttemptEvaluation(answerId: '1', attempt: 1, status: EvaluationStatus.succeeded, feedback: feedback),
        const InterviewAttemptEvaluation(answerId: '2', attempt: 2, status: EvaluationStatus.processing),
      ]);
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null,
      overrides: [recordsRepositoryProvider.overrideWithValue(_Records(detail))],
      child: const MaterialApp(home: AnswerViewScreen(questionId: '8'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('답변을 평가하고 있어요.'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('84%'), findsNothing);
    await tester.tap(find.text('시도 1'));
    await tester.pumpAndSettle();
    expect(find.text('84%'), findsOneWidget);
    expect(find.text('검토 강점'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('취소된 평가의 다시 시도는 조회만 하며 재평가 POST를 하지 않는다', (tester) async {
    final repo = _Cancelled();
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null,
      overrides: [interviewRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: FeedbackScreen(answerId: '77'))));
    await tester.pumpAndSettle();
    expect(find.text('평가가 취소됐어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(repo.retries, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
