/// 실제 백엔드 구현. 요청·응답 형식은 docs/API_CONTRACT.md.
/// 백엔드 응답 키가 달라지면 models 의 fromJson 과 이 파일만 고치면 된다.
library;

import '../../core/network/api_client.dart';
import '../../core/network/api_paths.dart';
import '../models/auth.dart';
import '../models/catalog.dart';
import '../models/home.dart';
import '../models/interview.dart';
import '../models/quiz.dart';
import '../models/records.dart';
import '../models/settings.dart';
import '../repositories/repositories.dart';

Map<String, dynamic> _obj(dynamic data) => (data as Map).cast<String, dynamic>();

/// 목록 응답은 [..] 또는 {"items": [..]} 둘 다 받아준다.
List<Map<String, dynamic>> _items(dynamic data) {
  final list = data is List ? data : (data as Map)['items'] as List<dynamic>? ?? const [];
  return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api);
  final ApiClient _api;

  @override
  Future<AuthSession> signInWithSocial(SocialCredential credential) async =>
      AuthSession.fromJson(_obj(await _api.post(ApiPaths.authSocial, body: credential.toJson(), auth: false)));

  @override
  Future<AppUser> fetchMe() async => AppUser.fromJson(_obj(await _api.get(ApiPaths.me)));

  @override
  Future<AppUser> updateProfile({required String nickname, required int avatarIndex}) async =>
      AppUser.fromJson(_obj(await _api.put(ApiPaths.meProfile, body: {'nickname': nickname, 'avatarIndex': avatarIndex})));

  @override
  Future<void> sendPasswordCode() async {
    await _api.post(ApiPaths.mePasswordCode);
  }

  @override
  Future<void> changePassword({required String code, required String newPassword}) async {
    await _api.put(ApiPaths.mePassword, body: {'code': code, 'newPassword': newPassword});
  }

  @override
  Future<void> signOut() async {
    await _api.post(ApiPaths.authLogout);
  }

  @override
  Future<void> deleteAccount() async {
    await _api.delete(ApiPaths.me);
  }
}

class RemoteCatalogRepository implements CatalogRepository {
  RemoteCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Company>> fetchCompanies({String? query}) async =>
      _items(await _api.get(ApiPaths.companies, query: {'q': query})).map(Company.fromJson).toList();

  @override
  Future<JobCatalog> fetchJobCatalog() async => JobCatalog.fromJson(_obj(await _api.get(ApiPaths.jobCatalog)));
}

class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository(this._api);
  final ApiClient _api;

  List<Preparation> _preps(dynamic data) => _items(data).map(Preparation.fromJson).toList();

  @override
  Future<List<Preparation>> fetchPreparations() async => _preps(await _api.get(ApiPaths.mePreparations));

  @override
  Future<List<Preparation>> savePreparations(List<Preparation> items) async =>
      _preps(await _api.put(ApiPaths.mePreparations, body: {'items': items.map((p) => p.toJson()).toList()}));

  @override
  Future<List<Preparation>> addPreparation(Preparation item) async =>
      _preps(await _api.post(ApiPaths.mePreparations, body: item.toJson()));

  @override
  Future<List<Preparation>> updatePreparation(Preparation item) async =>
      _preps(await _api.put(ApiPaths.mePreparation(item.companyId), body: item.toJson()));

  @override
  Future<List<Preparation>> removePreparation(String companyId) async =>
      _preps(await _api.delete(ApiPaths.mePreparation(companyId)));

  @override
  Future<List<Experience>> fetchExperiences() async =>
      _items(await _api.get(ApiPaths.meExperiences)).map(Experience.fromJson).toList();

  @override
  Future<List<ExperienceDraft>> splitExperiences(String text) async =>
      _items(await _api.post(ApiPaths.meExperiencesSplit, body: {'text': text})).map(ExperienceDraft.fromJson).toList();

  @override
  Future<List<Experience>> addExperiences(List<ExperienceDraft> items) async => _items(
        await _api.post(ApiPaths.meExperiences, body: {'items': items.map((e) => e.toJson()).toList()}),
      ).map(Experience.fromJson).toList();

  @override
  Future<Experience> updateExperience(Experience item) async =>
      Experience.fromJson(_obj(await _api.put(ApiPaths.meExperience(item.id), body: item.toJson())));

  @override
  Future<void> deleteExperience(String id) async {
    await _api.delete(ApiPaths.meExperience(id));
  }

  @override
  Future<AppUser> completeOnboarding() async => AppUser.fromJson(_obj(await _api.post(ApiPaths.meOnboardingComplete)));

  @override
  Future<NotificationSettings> fetchNotificationSettings() async =>
      NotificationSettings.fromJson(_obj(await _api.get(ApiPaths.meNotificationSettings)));

  @override
  Future<NotificationSettings> updateNotificationSettings(NotificationSettings settings) async =>
      NotificationSettings.fromJson(_obj(await _api.put(ApiPaths.meNotificationSettings, body: settings.toJson())));

  @override
  Future<void> registerPushToken({required String token, required String platform}) async {
    await _api.put(ApiPaths.mePushToken, body: {'token': token, 'platform': platform});
  }
}

class RemoteHomeRepository implements HomeRepository {
  RemoteHomeRepository(this._api);
  final ApiClient _api;

  @override
  Future<HomeSummary> fetchHome() async => HomeSummary.fromJson(_obj(await _api.get(ApiPaths.home)));
}

class RemoteQuizRepository implements QuizRepository {
  RemoteQuizRepository(this._api);
  final ApiClient _api;

  @override
  Future<QuizSet> fetchTodaySet(String companyId) async =>
      QuizSet.fromJson(_obj(await _api.get(ApiPaths.quizToday, query: {'companyId': companyId})));

  @override
  Future<QuizAnswerResult> submitAnswer({required String setId, required String questionId, required String answer}) async =>
      QuizAnswerResult.fromJson(
        _obj(await _api.post(ApiPaths.quizAnswer(setId), body: {'questionId': questionId, 'answer': answer})),
      );

  @override
  Future<QuizResult> fetchResult(String setId) async => QuizResult.fromJson(_obj(await _api.get(ApiPaths.quizResult(setId))));

  @override
  Future<void> reportQuestion({required String questionId, required String reason}) async {
    await _api.post(ApiPaths.quizReport(questionId), body: {'reason': reason});
  }
}

class RemoteInterviewRepository implements InterviewRepository {
  RemoteInterviewRepository(this._api);
  final ApiClient _api;

  @override
  Future<TodayInterview> fetchToday(String companyId) async =>
      TodayInterview.fromJson(_obj(await _api.get(ApiPaths.interviewToday, query: {'companyId': companyId})));

  @override
  Future<InterviewQuestion> fetchQuestion(String questionId) async =>
      InterviewQuestion.fromJson(_obj(await _api.get(ApiPaths.interviewQuestion(questionId))));

  @override
  Future<AnswerFeedback> submitAnswer({
    required String questionId,
    required String content,
    required AnswerInputType inputType,
  }) async =>
      AnswerFeedback.fromJson(_obj(await _api.post(
        ApiPaths.interviewAnswers(questionId),
        body: {'content': content, 'inputType': inputType.wire},
      )));

  @override
  Future<AnswerFeedback> fetchFeedback(String answerId) async =>
      AnswerFeedback.fromJson(_obj(await _api.get(ApiPaths.answerFeedback(answerId))));

  @override
  Future<void> saveDraft({required String questionId, required String content}) async {
    await _api.put(ApiPaths.interviewDraft(questionId), body: {'content': content});
  }

  @override
  Future<String?> fetchDraft(String questionId) async {
    final data = await _api.get(ApiPaths.interviewDraft(questionId));
    return data is Map ? data['content'] as String? : null;
  }

  @override
  Future<void> unlockBonusQuestion(String companyId) async {
    await _api.post(ApiPaths.interviewBonus, body: {'companyId': companyId});
  }
}

class RemoteRecordsRepository implements RecordsRepository {
  RemoteRecordsRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<QuizReviewItem>> fetchQuizReview({required String companyId}) async =>
      _items(await _api.get(ApiPaths.quizReview, query: {'companyId': companyId})).map(QuizReviewItem.fromJson).toList();

  @override
  Future<QuizAnswerResult> retryQuiz({required String itemId, required String answer}) async =>
      QuizAnswerResult.fromJson(_obj(await _api.post(ApiPaths.quizReviewRetry(itemId), body: {'answer': answer})));

  @override
  Future<List<InterviewRecord>> fetchInterviewRecords({required String companyId}) async =>
      _items(await _api.get(ApiPaths.interviewReview, query: {'companyId': companyId})).map(InterviewRecord.fromJson).toList();

  @override
  Future<InterviewRecordDetail> fetchInterviewRecord(String questionId) async =>
      InterviewRecordDetail.fromJson(_obj(await _api.get(ApiPaths.interviewReviewItem(questionId))));

  @override
  Future<void> deleteInterviewRecord(String questionId) async {
    await _api.delete(ApiPaths.interviewReviewItem(questionId));
  }

  @override
  Future<void> deleteAttempt(String answerId) async {
    await _api.delete(ApiPaths.answerFeedback(answerId));
  }
}

class RemoteInquiryRepository implements InquiryRepository {
  RemoteInquiryRepository(this._api);
  final ApiClient _api;

  @override
  Future<void> submit({
    required InquiryType type,
    required String content,
    required String appVersion,
    required String platform,
    String? companyId,
  }) async {
    await _api.post(ApiPaths.inquiries, body: {
      'type': type.wire,
      'content': content,
      'appVersion': appVersion,
      'platform': platform,
      'companyId': companyId,
    });
  }

  @override
  Future<List<Inquiry>> fetchHistory() async => _items(await _api.get(ApiPaths.inquiries)).map(Inquiry.fromJson).toList();
}
