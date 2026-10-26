import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../design_system/design_system.dart';

/// 1-1 시작 (로고 + "기업의 이야기, 나의 답변으로."): 저장된 로그인 확인 중. 이동은 라우터 redirect 가 한다.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(sessionProvider.select((s) => s.bootstrapError));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(AppHeader.logoAsset, height: 40, semanticLabel: 'Dadot'),
                    const SizedBox(height: AppSpacing.introGap),
                    Text('기업의 이야기,\n나의 답변으로.', textAlign: TextAlign.center, style: AppTypography.display),
                  ],
                )
              : ErrorView(error: error, onRetry: () => ref.read(sessionProvider.notifier).bootstrap()),
        ),
      ),
    );
  }
}
