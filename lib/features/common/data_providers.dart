/// 여러 화면이 같이 쓰는 서버 데이터.
/// 모두 currentUserIdProvider 를 watch 해서, 로그아웃·계정 변경 시 자동으로 비워진다.
/// 데이터를 바꾼 뒤에는 ref.invalidate(xxxProvider) 로 새로 불러온다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/catalog.dart';
import '../../data/models/home.dart';
import '../../data/models/interview.dart';
import '../../data/models/quiz.dart';
import '../../data/models/records.dart';
import '../../data/models/settings.dart';

/// 검색어별 기업 목록 (빈 문자열 = 추천)
final companiesProvider = FutureProvider.autoDispose.family<List<Company>, String>(
  (ref, query) => ref.watch(catalogRepositoryProvider).fetchCompanies(query: query.isEmpty ? null : query),
);

final jobCatalogProvider = FutureProvider<JobCatalog>((ref) => ref.watch(catalogRepositoryProvider).fetchJobCatalog());

final preparationsProvider = FutureProvider<List<Preparation>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).fetchPreparations();
});

final experiencesProvider = FutureProvider<List<Experience>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).fetchExperiences();
});

final homeProvider = FutureProvider<HomeSummary>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(homeRepositoryProvider).fetchHome();
});

final notificationSettingsProvider = FutureProvider<NotificationSettings>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).fetchNotificationSettings();
});

final inquiriesProvider = FutureProvider.autoDispose<List<Inquiry>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(inquiryRepositoryProvider).fetchHistory();
});

final quizResultProvider = FutureProvider.autoDispose.family<QuizResult, String>(
  (ref, setId) => ref.watch(quizRepositoryProvider).fetchResult(setId),
);

final interviewQuestionProvider = FutureProvider.autoDispose.family<InterviewQuestion, String>(
  (ref, id) => ref.watch(interviewRepositoryProvider).fetchQuestion(id),
);

final feedbackProvider = FutureProvider.autoDispose.family<AnswerFeedback, String>(
  (ref, answerId) => ref.watch(interviewRepositoryProvider).fetchFeedback(answerId),
);

final quizReviewProvider = FutureProvider.family<List<QuizReviewItem>, String>((ref, companyId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(recordsRepositoryProvider).fetchQuizReview(companyId: companyId);
});

final interviewRecordsProvider = FutureProvider.family<List<InterviewRecord>, String>((ref, companyId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(recordsRepositoryProvider).fetchInterviewRecords(companyId: companyId);
});

final interviewRecordProvider = FutureProvider.autoDispose.family<InterviewRecordDetail, String>(
  (ref, questionId) => ref.watch(recordsRepositoryProvider).fetchInterviewRecord(questionId),
);

/// 홈·복습 헤더에서 고른 준비 기업 (기기에 기억)
final selectedCompanyIdProvider = NotifierProvider<SelectedCompanyController, String?>(SelectedCompanyController.new);

class SelectedCompanyController extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(currentUserIdProvider);
    return ref.read(localStoreProvider).lastCompanyId;
  }

  void select(String companyId) {
    state = companyId;
    ref.read(localStoreProvider).setLastCompanyId(companyId);
  }
}

/// 고른 기업이 목록에 없으면(빠졌거나 처음) 첫 기업
CompanyHome? resolveSelected(HomeSummary home, String? selectedId) => home.byId(selectedId) ?? home.companies.firstOrNull;

/// 답변·퀴즈 등으로 기록이 바뀌었을 때 한 번에 새로고침
void invalidateProgress(WidgetRef ref) {
  ref.invalidate(homeProvider);
  ref.invalidate(quizReviewProvider);
  ref.invalidate(interviewRecordsProvider);
}
