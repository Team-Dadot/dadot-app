import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/catalog.dart';
import '../../design_system/design_system.dart';

/// 첫 설정 중인 준비 기업 목록. 서버에 저장된 값으로 시작해서 단계마다 저장한다.
final onboardingPrepsProvider =
    AsyncNotifierProvider<OnboardingPrepsController, List<Preparation>>(OnboardingPrepsController.new);

class OnboardingPrepsController extends AsyncNotifier<List<Preparation>> {
  @override
  Future<List<Preparation>> build() {
    ref.watch(currentUserIdProvider);
    return ref.read(profileRepositoryProvider).fetchPreparations();
  }

  List<Preparation> get current => state.asData?.value ?? const [];

  void setLocal(List<Preparation> items) => state = AsyncData(items);

  void replace(Preparation item) => setLocal([for (final p in current) p.companyId == item.companyId ? item : p]);

  Future<void> save() async {
    final saved = await ref.read(profileRepositoryProvider).savePreparations(current);
    state = AsyncData(saved);
  }
}

/// AI 가 나눈 경험 후보 (1-6 / 6-5 → 1-7 로 넘긴다)
final experienceDraftsProvider = NotifierProvider<ExperienceDraftsController, List<ExperienceDraft>>(ExperienceDraftsController.new);

class ExperienceDraftsController extends Notifier<List<ExperienceDraft>> {
  @override
  List<ExperienceDraft> build() => const [];

  void set(List<ExperienceDraft> items) => state = items;
}

/// 첫 설정 단계 화면 틀: "〈 첫 설정" + 단계 막대 + STEP n / 4 + 제목 + 설명 + 본문 + 하단 버튼
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.children,
    required this.bottom,
    this.onBack,
  });

  final int step;
  final String title;
  final String description;
  final List<Widget> children;
  final List<Widget> bottom;
  final VoidCallback? onBack;

  static const total = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppNavBar(title: '첫 설정', onBack: onBack),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          StepBar(current: step, total: total),
          const SizedBox(height: AppSpacing.gap),
          Text('STEP $step / $total', style: AppTypography.captionStrong.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.gap),
          PageTitle(title, description: description),
          const SizedBox(height: AppSpacing.gap),
          ...children,
        ],
      ),
      bottomNavigationBar: BottomCta(children: bottom),
    );
  }
}

/// 서버에서 준비 기업을 불러오는 동안·실패했을 때
class OnboardingLoadGate extends ConsumerWidget {
  const OnboardingLoadGate({super.key, required this.builder});

  final Widget Function(List<Preparation> preps) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preps = ref.watch(onboardingPrepsProvider);
    return preps.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: builder,
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: const AppNavBar(title: '첫 설정'),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(onboardingPrepsProvider)),
      ),
    );
  }
}
