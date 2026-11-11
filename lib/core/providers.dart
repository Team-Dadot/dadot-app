/// 의존성 연결 (DI). 앱 전체에서 무엇을 쓸지 여기서만 정한다.
/// - Mock ↔ Remote 전환: AppConfig.useMock (--dart-define=USE_MOCK=false)
/// - 실제 SDK 로 바꾸기: socialAuthServiceProvider, pushServiceProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock/mock_backend.dart';
import '../data/mock/mock_repositories.dart';
import '../data/remote/remote_repositories.dart';
import '../data/repositories/repositories.dart';
import 'config/app_config.dart';
import 'network/api_client.dart';
import 'services/link_service.dart';
import 'services/push_service.dart';
import 'services/reminder_service.dart';
import 'services/real_social_auth_service.dart';
import 'services/social_auth_service.dart';
import 'storage/local_store.dart';
import 'session/session_controller.dart';
import 'storage/token_storage.dart';

// ---------------------------------------------------------------- 기반

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

/// main() 에서 SharedPreferences.getInstance() 결과로 override 한다.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main.dart 에서 sharedPreferencesProvider 를 override 해야 합니다.'),
);

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPreferencesProvider)));

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final authEventsProvider = Provider<AuthEvents>((ref) {
  final events = AuthEvents();
  ref.onDispose(events.dispose);
  return events;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
    authEvents: ref.watch(authEventsProvider),
  );
});

final mockBackendProvider = Provider<MockBackend>((ref) {
  final config = ref.watch(appConfigProvider);
  return MockBackend(store: ref.watch(localStoreProvider), latency: config.mockLatency);
});

bool _mock(Ref ref) => ref.watch(appConfigProvider).useMock;

// ---------------------------------------------------------------- Repository

final authRepositoryProvider = Provider<AuthRepository>((ref) => _mock(ref)
    ? MockAuthRepository(ref.watch(mockBackendProvider), ref.watch(appConfigProvider))
    : RemoteAuthRepository(ref.watch(apiClientProvider)));

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => _mock(ref)
    ? MockCatalogRepository(ref.watch(mockBackendProvider))
    : RemoteCatalogRepository(ref.watch(apiClientProvider)));

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => _mock(ref)
    ? MockProfileRepository(ref.watch(mockBackendProvider))
    : RemoteProfileRepository(ref.watch(apiClientProvider)));

final homeRepositoryProvider = Provider<HomeRepository>((ref) => _mock(ref)
    ? MockHomeRepository(ref.watch(mockBackendProvider))
    : RemoteHomeRepository(ref.watch(apiClientProvider)));

final quizRepositoryProvider = Provider<QuizRepository>((ref) => _mock(ref)
    ? MockQuizRepository(ref.watch(mockBackendProvider))
    : RemoteQuizRepository(ref.watch(apiClientProvider)));

final interviewRepositoryProvider = Provider<InterviewRepository>((ref) => _mock(ref)
    ? MockInterviewRepository(ref.watch(mockBackendProvider))
    : RemoteInterviewRepository(
        ref.watch(apiClientProvider),
        store: ref.watch(localStoreProvider),
        ownerId: () => ref.read(sessionProvider).user?.id,
      ));

final recordsRepositoryProvider = Provider<RecordsRepository>((ref) => _mock(ref)
    ? MockRecordsRepository(ref.watch(mockBackendProvider))
    : RemoteRecordsRepository(ref.watch(apiClientProvider)));

final inquiryRepositoryProvider = Provider<InquiryRepository>((ref) => _mock(ref)
    ? MockInquiryRepository(ref.watch(mockBackendProvider))
    : RemoteInquiryRepository(ref.watch(apiClientProvider)));

// ---------------------------------------------------------------- 외부 SDK

/// Mock 모드는 가짜 로그인, 실제 서버 모드는 카카오 · Apple SDK
final socialAuthServiceProvider = Provider<SocialAuthService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) return const FakeSocialAuthService();
  return RealSocialAuthService(kakaoReady: config.kakaoNativeAppKey.isNotEmpty, expectedKakaoAppId: config.kakaoAppId);
});

/// 학습 알림: 기기 로컬 알림으로 매일 예약 (서버 푸시가 생기기 전까지)
final reminderServiceProvider = Provider<ReminderService>((ref) => ReminderService());

/// 서버 푸시(FCM)는 아직 없음. 알림 권한 요청만 로컬 알림 플러그인으로 한다.
final pushServiceProvider = Provider<PushService>(
  (ref) => NoopPushService(permission: ref.watch(reminderServiceProvider).requestPermission),
);

final linkServiceProvider = Provider<LinkService>((ref) => const LinkService());
