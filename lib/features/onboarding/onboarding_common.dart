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

/// 첫 설정 단계 화면 틀 (피그마 최종 1-2 ~ STEP 5): 라임 단계 막대 + "STEP n" + 제목 24 + 설명 + 본문 + 하단 버튼
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.step,
    required this.title,
    this.description,
    required this.children,
    required this.bottom,
    this.onBack,
  });

  final int step;
  final String title;
  final String? description;
  final List<Widget> children;
  final List<Widget> bottom;
  final VoidCallback? onBack;

  /// 기업 · 직무 · 면접일 · 경험 · 알림
  static const total = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppNavBar(title: '', onBack: onBack),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.xl),
        children: [
          StepBar(current: step, total: total, gap: 0),
          const SizedBox(height: AppSpacing.xxl),
          ExcludeSemantics(child: Text('STEP $step', style: AppTypography.number(18, weight: FontWeight.w700))),
          const SizedBox(height: AppSpacing.xxs),
          Semantics(header: true, child: Text(title, style: AppTypography.title1.copyWith(color: AppColors.ink))),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(description!, style: AppTypography.body2.copyWith(color: AppColors.textCaption)),
          ],
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
      bottomNavigationBar: BottomCta(children: bottom),
    );
  }
}

/// 단계 안 작은 이름 ("기업별 직무 고르기" · "추가한 내 경험")
class OnboardingLabel extends StatelessWidget {
  const OnboardingLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTypography.body2.copyWith(color: AppColors.textCaption)),
      );
}

/// 기업 카드 오른쪽 "선택 ›" / "2026.10.29"
class TileValue extends StatelessWidget {
  const TileValue(this.text, {super.key, this.filled = false});

  final String text;

  /// 값이 들어가면 진한 글자, 화살표 없음
  final bool filled;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: AppTypography.caption.copyWith(color: filled ? AppColors.ink : AppColors.textCaption)),
          if (!filled) const Chevron(),
        ],
      );
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
