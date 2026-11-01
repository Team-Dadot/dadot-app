/// 백엔드 API 경로. docs/API_CONTRACT.md 와 1:1 로 맞춘다.
/// 백엔드 경로가 달라지면 여기만 고치면 된다.
class ApiPaths {
  ApiPaths._();

  // 인증
  static const authSocial = '/auth/social';
  static const authEmailSignup = '/auth/email/signup';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';

  // 내 정보
  static const me = '/me';
  static const meProfile = '/me/profile';
  static const mePasswordCode = '/me/password/code';
  static const mePassword = '/me/password';
  static const mePreparations = '/me/preparations';
  static String mePreparation(String companyId) => '/me/preparations/$companyId';
  static const mePastPreparations = '/me/preparations/past';
  static const meExperiences = '/me/experiences';
  static const meExperiencesSplit = '/me/experiences/split';
  static String meExperience(String id) => '/me/experiences/$id';
  static const meOnboardingComplete = '/me/onboarding/complete';
  static const meNotificationSettings = '/me/notification-settings';
  static const mePushToken = '/me/push-token';

  // 카탈로그
  static const companies = '/companies';
  static const jobCatalog = '/jobs/catalog';

  // 홈
  static const home = '/home';

  // 퀴즈
  static const quizToday = '/quiz-sets/today';
  static String quizAnswer(String setId) => '/quiz-sets/$setId/answers';
  static String quizResult(String setId) => '/quiz-sets/$setId/result';
  static String quizReport(String questionId) => '/quiz-questions/$questionId/reports';

  // 면접
  static const interviewToday = '/interview-questions/today';
  static const interviewBonus = '/interview-questions/today/bonus';
  static String interviewQuestion(String id) => '/interview-questions/$id';
  static String interviewAnswers(String questionId) => '/interview-questions/$questionId/answers';
  static String interviewDraft(String questionId) => '/interview-questions/$questionId/draft';
  static String answerFeedback(String answerId) => '/interview-answers/$answerId';

  // 복습
  static const quizReview = '/review/quiz';
  static String quizReviewRetry(String itemId) => '/review/quiz/$itemId/retry';
  static const interviewReview = '/review/interview';
  static String interviewReviewItem(String questionId) => '/review/interview/$questionId';

  // 문의
  static const inquiries = '/inquiries';
}
