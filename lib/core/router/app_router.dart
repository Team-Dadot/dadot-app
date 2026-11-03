import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/email_login_screen.dart';
import '../../features/auth/email_signup_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/interview/answer_screen.dart';
import '../../features/interview/feedback_screen.dart';
import '../../features/interview/interview_today_screen.dart';
import '../../features/interview/question_screen.dart';
import '../../features/my/application_edit_screen.dart';
import '../../features/my/applications_screen.dart';
import '../../features/my/companies_screen.dart';
import '../../features/my/experience_add_screen.dart';
import '../../features/my/experience_edit_screen.dart';
import '../../features/my/experiences_screen.dart';
import '../../features/my/inquiry_screen.dart';
import '../../features/my/my_screen.dart';
import '../../features/my/notification_screen.dart';
import '../../features/my/password_screen.dart';
import '../../features/my/profile_screen.dart';
import '../../features/onboarding/experience_confirm_screen.dart';
import '../../features/onboarding/onboarding_companies_screen.dart';
import '../../features/onboarding/onboarding_dates_screen.dart';
import '../../features/onboarding/onboarding_experience_screen.dart';
import '../../features/onboarding/onboarding_finish_screens.dart';
import '../../features/onboarding/onboarding_jobs_screen.dart';
import '../../features/quiz/quiz_result_screen.dart';
import '../../features/quiz/quiz_screen.dart';
import '../../features/review/answer_view_screen.dart';
import '../../features/review/quiz_retry_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/shell/main_shell.dart';
import '../session/session_controller.dart';

/// 화면 경로. 주석의 번호는 피그마 "와이어프레임" 페이지 프레임 번호.
class Routes {
  Routes._();

  static const splash = '/splash';
  static const login = '/login'; // 1-1
  static const emailLogin = '/login/email'; // 이메일 로그인
  static const emailSignup = '/login/email/signup'; // 이메일로 가입 1~3

  // 첫 설정
  static const onboardingCompanies = '/onboarding/companies'; // 1-2
  static const onboardingJobs = '/onboarding/jobs'; // 1-3, 1-4
  static const onboardingDates = '/onboarding/dates'; // 1-5
  static const onboardingExperience = '/onboarding/experience'; // STEP 4/4 내 경험
  static const onboardingNotification = '/onboarding/notification'; // 알림 허용
  static const onboardingDone = '/onboarding/done'; // 완료 · 내 준비 정보

  // 하단 탭
  static const home = '/home'; // 2-1 ~ 2-4
  static const review = '/review'; // 5-1, 5-2
  static const my = '/my'; // 6-1

  static String reviewTab(String tab) => '/review?tab=$tab';

  // 퀴즈
  static String quiz(String companyId) => '/quiz/$companyId'; // 3-1 ~ 3-4
  static String quizResult(String setId) => '/quiz-result/$setId'; // 3-5

  // 면접
  static String todayInterview(String companyId) => '/interview/today/$companyId'; // 4-1
  static String interview(String questionId) => '/interview/$questionId'; // 4-2
  static String interviewAnswer(String questionId, {bool voice = false}) =>
      '/interview/$questionId/answer${voice ? '?voice=1' : ''}'; // 4-1 답변 작성 (텍스트 · 말로)
  static String feedback(String answerId) => '/feedback/$answerId'; // 4-6

  // 복습
  static String quizRetry(String itemId, String companyId) => '/review/quiz/$itemId?company=$companyId';
  static String answerView(String questionId) => '/review/interview/$questionId'; // 5-3

  // 마이
  static const myCompanies = '/my/companies'; // 6-2, 6-3
  static const myApplications = '/my/applications'; // 6-7
  static String myApplication(String companyId) => '/my/applications/$companyId'; // 6-8
  static const myExperiences = '/my/experiences'; // 6-4
  static const myExperienceNew = '/my/experiences/new'; // 6-5
  static const myExperienceConfirm = '/my/experiences/confirm'; // 1-7 재사용
  static String myExperience(String id) => '/my/experiences/$id'; // 6-6
  static const myNotifications = '/my/notifications'; // 6-9
  static const myInquiry = '/my/inquiry'; // 6-10
  static const myProfile = '/my/profile'; // 6-11
  static const myPassword = '/my/password'; // 6-12
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// 로그인·첫 설정 상태에 따라 갈 수 있는 화면을 정한다.
String? sessionRedirect(SessionState session, String location) {
  final atSplash = location == Routes.splash;
  final atLogin = location == Routes.login || location.startsWith('${Routes.login}/');
  final atOnboarding = location.startsWith('/onboarding');

  switch (session.status) {
    case SessionStatus.unknown:
      return atSplash ? null : Routes.splash;
    case SessionStatus.unauthenticated:
      return atLogin ? null : Routes.login;
    case SessionStatus.onboarding:
      // 첫 설정 화면들이 서버에 저장된 값을 불러와 이어서 진행한다
      return atOnboarding ? null : Routes.onboardingCompanies;
    case SessionStatus.ready:
      if (atSplash || atLogin || atOnboarding) return Routes.home;
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<SessionState>(ref.read(sessionProvider));
  ref.listen<SessionState>(sessionProvider, (_, next) => session.value = next);
  ref.onDispose(session.dispose);

  Page<void> fade(GoRouterState state, Widget child) => NoTransitionPage<void>(key: state.pageKey, child: child);
  GoRoute top(String path, Widget Function(GoRouterState s) build) =>
      GoRoute(path: path, parentNavigatorKey: rootNavigatorKey, builder: (_, s) => build(s));

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (context, state) => sessionRedirect(session.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, pageBuilder: (_, s) => fade(s, const SplashScreen())),
      GoRoute(
        path: Routes.login,
        pageBuilder: (_, s) => fade(s, const LoginScreen()),
        routes: [
          GoRoute(
            path: 'email',
            builder: (_, _) => const EmailLoginScreen(),
            routes: [GoRoute(path: 'signup', builder: (_, _) => const EmailSignupScreen())],
          ),
        ],
      ),
      GoRoute(path: Routes.onboardingCompanies, pageBuilder: (_, s) => fade(s, const OnboardingCompaniesScreen())),
      GoRoute(path: Routes.onboardingJobs, builder: (_, _) => const OnboardingJobsScreen()),
      GoRoute(path: Routes.onboardingDates, builder: (_, _) => const OnboardingDatesScreen()),
      GoRoute(path: Routes.onboardingExperience, builder: (_, _) => const OnboardingExperienceScreen()),
      GoRoute(path: Routes.onboardingNotification, builder: (_, _) => const OnboardingNotificationScreen()),
      GoRoute(path: Routes.onboardingDone, builder: (_, _) => const OnboardingDoneScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.review,
              builder: (_, s) => ReviewScreen(initialTab: s.uri.queryParameters['tab']),
              routes: [
                GoRoute(
                  path: 'quiz/:itemId',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => QuizRetryScreen(itemId: s.pathParameters['itemId']!, companyId: s.uri.queryParameters['company'] ?? ''),
                ),
                GoRoute(
                  path: 'interview/:questionId',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => AnswerViewScreen(questionId: s.pathParameters['questionId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.my,
              builder: (_, _) => const MyScreen(),
              routes: [
                top('companies', (_) => const CompaniesScreen()),
                top('applications', (_) => const ApplicationsScreen()),
                top('applications/:companyId', (s) => ApplicationEditScreen(companyId: s.pathParameters['companyId']!)),
                top('experiences', (_) => const ExperiencesScreen()),
                top('experiences/new', (s) => ExperienceAddScreen(initialText: s.extra as String?)),
                top('experiences/confirm', (_) => const ExperienceConfirmScreen(onboarding: false)),
                top('experiences/:id', (s) => ExperienceEditScreen(experienceId: s.pathParameters['id']!)),
                top('notifications', (_) => const NotificationScreen()),
                top('inquiry', (_) => const InquiryScreen()),
                top('profile', (_) => const ProfileScreen()),
                top('password', (_) => const PasswordScreen()),
              ],
            ),
          ]),
        ],
      ),

      // 탭 바 없이 전체 화면
      GoRoute(path: '/quiz/:companyId', builder: (_, s) => QuizScreen(companyId: s.pathParameters['companyId']!)),
      GoRoute(path: '/quiz-result/:setId', builder: (_, s) => QuizResultScreen(setId: s.pathParameters['setId']!)),
      GoRoute(
        path: '/interview/today/:companyId',
        builder: (_, s) => InterviewTodayScreen(companyId: s.pathParameters['companyId']!),
      ),
      GoRoute(
        path: '/interview/:questionId',
        builder: (_, s) => QuestionScreen(questionId: s.pathParameters['questionId']!),
        routes: [
          GoRoute(
            path: 'answer',
            builder: (_, s) => AnswerScreen(questionId: s.pathParameters['questionId']!, startWithVoice: s.uri.queryParameters['voice'] == '1'),
          ),
        ],
      ),
      GoRoute(path: '/feedback/:answerId', builder: (_, s) => FeedbackScreen(answerId: s.pathParameters['answerId']!)),
    ],
  );
});
