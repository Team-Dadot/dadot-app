import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';

/// 실행:
///   Mock(백엔드 없이)  : flutter run
///   개발 서버 연결      : flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://dev-api.example.com
/// VS Code 에서는 .vscode/launch.json 의 구성을 고르면 된다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // 실패한 요청을 Riverpod 이 자동으로 다시 보내지 않게 한다 (재시도는 화면의 "다시 시도" 버튼으로)
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SwipeApp(),
    ),
  );
}
