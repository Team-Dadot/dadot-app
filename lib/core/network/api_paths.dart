/// 다닷 서버 API 경로 (Swagger: https://api.dadot.store/swagger-ui/index.html).
/// 모두 `/v1` 뒤 부분만 적는다 (baseUrl 에 /v1 이 붙어 있다). 경로가 바뀌면 여기만 고친다.
class ApiPaths {
  ApiPaths._();

  /// 모든 경로 앞에 붙는 버전 (baseUrl 뒤)
  static const basePath = '/v1';

  // 앱 설정 · 약관
  static const appConfig = '/app-config';

  // 인증
  static const emailVerifications = '/auth/email-verifications';
  static String emailVerify(String verificationId) => '/auth/email-verifications/$verificationId/verify';
  static const signup = '/auth/signup';
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const passwordReset = '/auth/password/reset';
  static const socialKakao = '/auth/social/kakao';
  static const socialApple = '/auth/social/apple';
  static const socialAppleChallenge = '/auth/social/apple/challenges';
  static const socialSignup = '/auth/social/signup';

  // 내 정보
  static const me = '/users/me';
  static const meProfile = '/users/me/profile';
  static const mePassword = '/users/me/password';
  static const mePreferences = '/users/me/preferences';
  static const meDashboard = '/users/me/dashboard';
  static const meCompanies = '/users/me/companies';
  static String meCompany(String companyId) => '/users/me/companies/$companyId';
  static const meExperiences = '/users/me/experiences';
  static String meExperience(String id) => '/users/me/experiences/$id';
  static const meOnboarding = '/users/me/onboarding';
  static const meOnboardingComplete = '/users/me/onboarding/complete';
  static const meNotificationSettings = '/users/me/notification-settings';

  // 카탈로그
  static const companies = '/companies';
  static const jobs = '/jobs';

  // 퀴즈
  static String quizToday(String companyId) => '/companies/$companyId/quiz-sets/today';
  static String quizSet(String setId) => '/quiz-sets/$setId';
  static String quizAnswers(String setId) => '/quiz-sets/$setId/answers';
  static String quizResult(String setId) => '/quiz-sets/$setId/result';

  // 면접
  static String interviewEntry(String companyId) => '/companies/$companyId/interview-entry';
  static String interviewQuestionTasks(String companyId) => '/companies/$companyId/interview-question-tasks';
  static String interviewQuestion(String id) => '/interview-questions/$id';
  static String interviewAttempts(String questionId) => '/interview-questions/$questionId/attempts';
  static String interviewDraft(String questionId) => '/interview-questions/$questionId/draft';
  static String attempt(String attemptId) => '/interview-attempts/$attemptId';
  static String attemptEvaluation(String attemptId) => '/interview-attempts/$attemptId/evaluation';
  static String attemptEvaluationTasks(String attemptId) => '/interview-attempts/$attemptId/evaluation-tasks';

  // 복습
  static const reviewCompanies = '/reviews/companies';
  static const reviewQuizzes = '/reviews/quizzes';
  static String reviewQuiz(String questionId) => '/reviews/quizzes/$questionId';
  static const reviewInterviews = '/reviews/interviews';
}
