import '../models/auth.dart';
import '../models/catalog.dart';
import '../models/home.dart';
import '../models/interview.dart';
import '../models/quiz.dart';
import '../models/records.dart';
import '../models/settings.dart';
import '../repositories/repositories.dart';
import 'mock_backend.dart';

/// MockBackend 를 Repository 인터페이스로 감싼 것. 화면 입장에서는 Remote 와 똑같다.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._b);
  final MockBackend _b;

  @override
  Future<AuthSession> signInWithSocial(SocialCredential credential) => _b.run(() => _b.signIn(credential));
  @override
  Future<AuthSession> signUpWithEmail({required String email, required String password}) =>
      _b.run(() => _b.signUpEmail(email: email, password: password));
  @override
  Future<AppUser> fetchMe() => _b.run(_b.me);
  @override
  Future<AppUser> updateProfile({required String nickname, required int avatarIndex}) =>
      _b.run(() => _b.updateProfile(nickname: nickname, avatarIndex: avatarIndex));
  @override
  Future<void> sendPasswordCode() => _b.run(_b.sendPasswordCode);
  @override
  Future<void> changePassword({required String code, required String newPassword}) =>
      _b.run(() => _b.changePassword(code: code, newPassword: newPassword));
  @override
  Future<void> signOut() => _b.run(_b.signOut);
  @override
  Future<void> deleteAccount() => _b.run(_b.deleteAccount);
}

class MockCatalogRepository implements CatalogRepository {
  MockCatalogRepository(this._b);
  final MockBackend _b;

  @override
  Future<List<Company>> fetchCompanies({String? query}) => _b.run(() => _b.companies(query: query));
  @override
  Future<JobCatalog> fetchJobCatalog() => _b.run(_b.jobCatalog);
}

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._b);
  final MockBackend _b;

  @override
  Future<List<Preparation>> fetchPreparations() => _b.run(_b.preparations);
  @override
  Future<List<Preparation>> savePreparations(List<Preparation> items) => _b.run(() => _b.savePreparations(items));
  @override
  Future<List<Preparation>> addPreparation(Preparation item) => _b.run(() => _b.addPreparation(item));
  @override
  Future<List<Preparation>> updatePreparation(Preparation item) => _b.run(() => _b.updatePreparation(item));
  @override
  Future<List<Preparation>> removePreparation(String companyId) => _b.run(() => _b.removePreparation(companyId));
  @override
  Future<List<PastPreparation>> fetchPastPreparations() => _b.run(_b.pastPreparations);
  @override
  Future<List<Experience>> fetchExperiences() => _b.run(_b.experiences);
  @override
  Future<List<ExperienceDraft>> splitExperiences(String text) =>
      // AI 처리는 오래 걸리니 조금 더 기다리게 한다 (로딩 화면 확인용)
      _b.run(() => _b.splitExperiences(text)).then((v) async {
        if (_b.latency > Duration.zero) await Future<void>.delayed(_b.latency * 2);
        return v;
      });
  @override
  Future<List<Experience>> addExperiences(List<ExperienceDraft> items) => _b.run(() => _b.addExperiences(items));
  @override
  Future<Experience> updateExperience(Experience item) => _b.run(() => _b.updateExperience(item));
  @override
  Future<void> deleteExperience(String id) => _b.run(() => _b.deleteExperience(id));
  @override
  Future<AppUser> completeOnboarding() => _b.run(_b.completeOnboarding);
  @override
  Future<NotificationSettings> fetchNotificationSettings() => _b.run(_b.notificationSettings);
  @override
  Future<NotificationSettings> updateNotificationSettings(NotificationSettings settings) =>
      _b.run(() => _b.updateNotificationSettings(settings));
  @override
  Future<void> registerPushToken({required String token, required String platform}) => _b.run(() {});
}

class MockHomeRepository implements HomeRepository {
  MockHomeRepository(this._b);
  final MockBackend _b;

  @override
  Future<HomeSummary> fetchHome() => _b.run(_b.home);
}

class MockQuizRepository implements QuizRepository {
  MockQuizRepository(this._b);
  final MockBackend _b;

  @override
  Future<QuizSet> fetchTodaySet(String companyId) => _b.run(() => _b.todaySet(companyId));
  @override
  Future<QuizAnswerResult> submitAnswer({required String setId, required String questionId, required String answer}) =>
      _b.run(() => _b.answerQuiz(setId: setId, questionId: questionId, answer: answer));
  @override
  Future<QuizResult> fetchResult(String setId) => _b.run(() => _b.quizResult(setId));
  @override
  Future<void> reportQuestion({required String questionId, required String reason}) =>
      _b.run(() => _b.reportQuestion(questionId, reason));
}

class MockInterviewRepository implements InterviewRepository {
  MockInterviewRepository(this._b);
  final MockBackend _b;

  Future<T> _slow<T>(Future<T> f) => f.then((v) async {
        if (_b.latency > Duration.zero) await Future<void>.delayed(_b.latency * 3);
        return v;
      });

  @override
  Future<TodayInterview> fetchToday(String companyId) => _slow(_b.run(() => _b.todayInterview(companyId)));
  @override
  Future<InterviewQuestion> fetchQuestion(String questionId) => _b.run(() => _b.question(questionId));
  @override
  Future<AnswerFeedback> submitAnswer({
    required String questionId,
    required String content,
    required AnswerInputType inputType,
  }) =>
      _slow(_b.run(() => _b.submitAnswer(questionId: questionId, content: content, inputType: inputType)));
  @override
  Future<AnswerFeedback> fetchFeedback(String answerId) => _b.run(() => _b.feedback(answerId));
  @override
  Future<void> saveDraft({required String questionId, required String content}) => _b.run(() => _b.saveDraft(questionId, content));
  @override
  Future<String?> fetchDraft(String questionId) => _b.run(() => _b.draft(questionId));
  @override
  Future<void> unlockBonusQuestion(String companyId) => _b.run(() => _b.unlockBonusQuestion(companyId));
}

class MockRecordsRepository implements RecordsRepository {
  MockRecordsRepository(this._b);
  final MockBackend _b;

  @override
  Future<List<QuizReviewItem>> fetchQuizReview({required String companyId}) => _b.run(() => _b.quizReview(companyId: companyId));
  @override
  Future<QuizAnswerResult> retryQuiz({required String itemId, required String answer}) => _b.run(() => _b.retryQuiz(itemId, answer));
  @override
  Future<List<InterviewRecord>> fetchInterviewRecords({required String companyId}) =>
      _b.run(() => _b.interviewRecords(companyId: companyId));
  @override
  Future<InterviewRecordDetail> fetchInterviewRecord(String questionId) => _b.run(() => _b.interviewRecord(questionId));
  @override
  Future<void> deleteInterviewRecord(String questionId) => _b.run(() => _b.deleteInterviewRecord(questionId));
  @override
  Future<void> deleteAttempt(String answerId) => _b.run(() => _b.deleteAttempt(answerId));
}

class MockInquiryRepository implements InquiryRepository {
  MockInquiryRepository(this._b);
  final MockBackend _b;

  @override
  Future<void> submit({
    required InquiryType type,
    required String content,
    required String appVersion,
    required String platform,
    String? companyId,
  }) =>
      _b.run(() => _b.submitInquiry(type: type, content: content));
  @override
  Future<List<Inquiry>> fetchHistory() => _b.run(_b.inquiries);
}
