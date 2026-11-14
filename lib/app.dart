import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/services/screen_tracking.dart';
import 'features/common/data_providers.dart';
import 'design_system/theme/app_theme.dart';

class SwipeApp extends ConsumerWidget {
  const SwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // 학습 알림 예약을 알림 설정과 맞춘다 (QA: 알림 예약 기능)
    ref.watch(reminderSyncProvider);
    ref.read(reminderServiceProvider).onOpen = () => router.go(Routes.home);
    ref.watch(screenTrackingProvider);
    return MaterialApp.router(
      title: 'Dadot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // 시스템 글자 크기를 너무 크게 키워도 화면이 깨지지 않도록 상한을 둔다
        final media = MediaQuery.of(context);
        // QA(1444:9396): 진한 화면(스플래시·피드백)에서 흰 상태바로 바뀐 뒤 밝은 화면에서도 흰 채로 남아
        // 시간·배터리가 안 보이던 문제 → 기본은 검은 글자 상태바. 진한 화면만 각자 흰 글자로 덮어쓴다.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Android: 검은 아이콘
            statusBarBrightness: Brightness.light, // iOS: 밝은 바탕 → 검은 글자
          ),
          child: MediaQuery(
            // QA: 폰 글자 크기를 키운 기기에서 피그마보다 15% 커져 카드가 넘쳤다 → 최대 1.1배까지만 따른다
            data: media.copyWith(textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.1)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
