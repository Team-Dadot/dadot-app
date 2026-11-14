import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../router/app_router.dart';
import 'analytics_service.dart';

/// 화면이 바뀔 때마다 Analytics 에 화면 이름을 보낸다 (탭 이동 · push · 뒤로가기 모두).
/// 이름에서 id 는 ':id' 로 가려서 화면별로 묶는다 (퀴즈 · 면접 단계별 이탈을 보기 위함).
final screenTrackingProvider = Provider<void>((ref) {
  final router = ref.watch(routerProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  String? last;
  void onChange() {
    final name = analyticsScreenName(router.state.uri.path);
    if (name == last) return;
    last = name;
    analytics.logScreen(name);
  }

  router.routerDelegate.addListener(onChange);
  ref.onDispose(() => router.routerDelegate.removeListener(onChange));
});
