import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../design_system/design_system.dart';

/// 스플래시를 최소한 이만큼은 보여 준다. 저장된 로그인 확인이 순식간에 끝나면 화면이 깜빡 지나가 버리기 때문.
const splashMinDuration = Duration(milliseconds: 1500);

/// 앱을 켠 뒤 [splashMinDuration] 이 지났는지. 지나기 전엔 라우터가 스플래시에 붙잡아 둔다.
final splashElapsedProvider = NotifierProvider<SplashElapsed, bool>(SplashElapsed.new);

class SplashElapsed extends Notifier<bool> {
  @override
  bool build() {
    final timer = Timer(splashMinDuration, () => state = true);
    ref.onDispose(timer.cancel);
    return false;
  }
}

/// 피그마 "스플래시" (1300:8087): 진한 바탕(#303137) · 흰 dadot 로고(라임 점) · 아래 라임 폴더.
/// 저장된 로그인 확인 중. 이동은 라우터 redirect 가 한다 (처음이면 튜토리얼, 아니면 로그인/홈).
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  static const _bg = Color(0xFF303137);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(sessionProvider.select((s) => s.bootstrapError));
    if (error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: ErrorView(error: error, onRetry: () => ref.read(sessionProvider.notifier).bootstrap())),
      );
    }
    final size = MediaQuery.sizeOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // 폴더: 피그마 402×874 화면 기준 470 부터 바닥까지 (가로에 맞춰 늘린다)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Image.asset(
                'assets/images/splash_folder.png',
                width: size.width,
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
                excludeFromSemantics: true,
              ),
            ),
            // 로고: 화면 높이 356/874 지점, 170×37
            Positioned(
              left: 0,
              right: 0,
              top: size.height * 356 / 874,
              child: Center(
                child: Image.asset('assets/images/dadot_wordmark_white.png', width: 170, semanticLabel: 'Dadot'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
