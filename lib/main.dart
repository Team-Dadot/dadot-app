import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';
import 'core/services/analytics_service.dart';
import 'core/services/firebase_analytics_service.dart';
import 'firebase_options.dart';

/// 실행:
///   Mock(백엔드 없이)  : flutter run
///   개발 서버 연결      : flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://dev-api.example.com
/// VS Code 에서는 .vscode/launch.json 의 구성을 고르면 된다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final kakaoKey = AppConfig.fromEnvironment().kakaoNativeAppKey;
  if (kakaoKey.isNotEmpty) KakaoSdk.init(nativeAppKey: kakaoKey);

  final analytics = await _initFirebase();

  runApp(
    ProviderScope(
      // 실패한 요청을 Riverpod 이 자동으로 다시 보내지 않게 한다 (재시도는 화면의 "다시 시도" 버튼으로)
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
      child: const SwipeApp(),
    ),
  );
}

/// Firebase(Analytics · Crashlytics) 시작. 실패해도 앱은 그대로 뜨고 지표만 꺼진다.
/// 디버그 실행은 지표·오류를 보내지 않아 운영 데이터가 섞이지 않는다.
Future<AnalyticsService> _initFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      crashlytics.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    return kDebugMode ? const NoopAnalyticsService() : FirebaseAnalyticsService();
  } catch (_) {
    return const NoopAnalyticsService();
  }
}
