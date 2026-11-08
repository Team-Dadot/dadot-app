/// 화면(상태)이 의존하는 데이터 창구.
/// 구현은 두 가지:
///  - data/remote : 실제 백엔드 (dio)
///  - data/mock   : 앱 안의 가짜 서버 (백엔드 없이 개발·QA)
/// 어느 쪽을 쓸지는 core/providers.dart 에서 AppConfig.useMock 으로 고른다.
library;

import '../models/auth.dart';
import '../models/catalog.dart';
import '../models/home.dart';
import '../models/interview.dart';
import '../models/quiz.dart';
import '../models/records.dart';
import '../models/settings.dart';

abstract interface class AuthRepository {
  /// 앱 설정: 가입 약관 목록(acceptedTermsIds 로 보낼 id) · 문서 링크 · 문의 구글폼
  Future<ServerAppConfig> fetchAppConfig();

  /// 소셜 로그인 준비. Apple 은 서버가 준 nonce 를 SDK 에 넘겨야 한다 (카카오는 null).
  Future<String?> prepareSocial(SocialProvider provider);

  /// 소셜 SDK 토큰을 우리 서비스 토큰으로 교환 (1-1).
  /// 처음 온 사용자면 [SocialSignUpRequired] 를 던진다 → 약관 동의 후 [completeSocialSignup].
  Future<AuthSession> signInWithSocial(SocialCredential credential);
  Future<AuthSession> completeSocialSignup({required String registrationToken, required List<String> termIds});

  /// 이메일 인증번호 보내기 → verificationId
  Future<String> sendEmailCode({required String email, required EmailCodePurpose purpose});

  /// 인증번호 확인 → verificationToken (가입 · 비밀번호 변경에 쓴다)
  Future<String> verifyEmailCode({required String verificationId, required String code});

  /// 이메일로 가입 (피그마 이메일로 가입 1~3). 인증·필수 약관 동의가 끝난 뒤 부른다.
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    required String verificationToken,
    required List<String> termIds,
  });

  Future<AuthSession> signInWithEmail({required String email, required String password});

  /// 비밀번호 찾기: PASSWORD_RESET 인증을 마친 verificationToken 으로 새 비밀번호 설정 (로그인 전)
  Future<void> resetPassword({required String verificationToken, required String newPassword});

  /// 저장된 토큰으로 내 정보 조회 (앱 시작 시)
  Future<AppUser> fetchMe();

  /// 회원정보 수정 (6-11). 서버는 닉네임만 바꾼다.
  Future<AppUser> updateProfile({required String nickname, required int avatarIndex});

  /// 비밀번호 변경 (6-12). 이메일·비밀번호 회원만. 가입한 이메일로 인증번호를 보내고, 받은 번호로 바꾼다.
  Future<void> sendPasswordCode();
  Future<void> changePassword({required String code, required String newPassword});

  Future<void> signOut();

  /// 회원 탈퇴 (스토어 정책상 앱 안에서 가능해야 함). 이메일 회원은 [password], 소셜 회원은 새로 받은 [credential] 로 본인 확인.
  Future<void> deleteAccount({String? password, SocialCredential? credential});
}

abstract interface class CatalogRepository {
  /// 기업명 또는 업종으로 검색 (빈 값 = 추천 목록)
  Future<List<Company>> fetchCompanies({String? query});

  /// 직무 선택 시트 (자주 찾는 직무 + 전체 직무 분류)
  Future<JobCatalog> fetchJobCatalog();
}

abstract interface class ProfileRepository {
  /// 준비 기업 · 지원 정보 (직무, 면접일)
  Future<List<Preparation>> fetchPreparations();

  /// 온보딩에서 한 번에 저장 (1-2 ~ 1-5)
  Future<List<Preparation>> savePreparations(List<Preparation> items);
  Future<List<Preparation>> addPreparation(Preparation item);
  Future<List<Preparation>> updatePreparation(Preparation item);
  Future<List<Preparation>> removePreparation(String companyId);

  /// 6-2 "준비했던 기업" (뺀 기업과 그동안의 기록 수)
  Future<List<PastPreparation>> fetchPastPreparations();

  /// 내 경험
  Future<List<Experience>> fetchExperiences();

  /// 자유롭게 쓴 글을 AI 가 경험별로 나눔 (1-6 → 1-7, 6-5)
  Future<List<ExperienceDraft>> splitExperiences(String text);
  Future<List<Experience>> addExperiences(List<ExperienceDraft> items);
  Future<Experience> updateExperience(Experience item);
  Future<void> deleteExperience(String id);

  Future<AppUser> completeOnboarding();

  Future<NotificationSettings> fetchNotificationSettings();
  Future<NotificationSettings> updateNotificationSettings(NotificationSettings settings);

  /// FCM/APNs 토큰 등록. platform: ANDROID | IOS
  Future<void> registerPushToken({required String token, required String platform});
}

abstract interface class HomeRepository {
  Future<HomeSummary> fetchHome();
}

abstract interface class QuizRepository {
  /// 오늘 세트. 이미 푼 문항은 answers 에 들어 있다 (이어하기).
  Future<QuizSet> fetchTodaySet(String companyId);

  /// 문항 하나 제출 → 서버 채점 결과. [answer] 는 고른 보기 choiceId.
  Future<QuizAnswerResult> submitAnswer({required String setId, required String questionId, required String answer});

  Future<QuizResult> fetchResult(String setId);

  /// 공시 근거 시트 "오류 제보하기"
  Future<void> reportQuestion({required String questionId, required String reason});
}

abstract interface class InterviewRepository {
  /// 오늘의 면접 질문 (기업별 3개). 처음 부르면 서버가 질문을 만든다 (4-1).
  Future<TodayInterview> fetchToday(String companyId);
  Future<InterviewQuestion> fetchQuestion(String questionId);

  /// 답변 제출 → AI 피드백 (4-5 → 4-6). 오늘 재도전 횟수를 다 쓰면 AppErrorKind.feedbackQuotaExceeded
  Future<AnswerFeedback> submitAnswer({
    required String questionId,
    required String content,
    required AnswerInputType inputType,
  });

  /// 평가가 실패했으면 [EvaluationFailed] 를 던진다.
  Future<AnswerFeedback> fetchFeedback(String answerId);

  /// 실패한 평가 다시 요청 (제출 횟수는 줄지 않는다)
  Future<void> retryEvaluation(String answerId);

  /// 임시저장 (4-3). 복습 탭에 "작성 중" 으로 보인다.
  Future<void> saveDraft({required String questionId, required String content});
  Future<String?> fetchDraft(String questionId);

  /// 광고 보고 면접 질문 1개 더 (2-4)
  Future<void> unlockBonusQuestion(String companyId);
}

abstract interface class RecordsRepository {
  Future<List<QuizReviewItem>> fetchQuizReview({required String companyId});

  /// 이 문제 다시 풀기 → 맞히면 누적 정답률에 최근 결과로 반영
  Future<QuizAnswerResult> retryQuiz({required String itemId, required String answer});

  Future<List<InterviewRecord>> fetchInterviewRecords({required String companyId});
  Future<InterviewRecordDetail> fetchInterviewRecord(String questionId);

  /// 질문과 답변 전체 삭제 (5-2 삭제)
  Future<void> deleteInterviewRecord(String questionId);

  /// 시도 하나 삭제 (5-3 이 답변 삭제)
  Future<void> deleteAttempt(String answerId);
}

abstract interface class InquiryRepository {
  Future<void> submit({
    required InquiryType type,
    required String content,
    required String appVersion,
    required String platform,
    String? companyId,
  });

  Future<List<Inquiry>> fetchHistory();
}
