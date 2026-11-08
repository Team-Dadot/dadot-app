import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../design_system/design_system.dart';

/// 첫 실행 튜토리얼을 봤는지 (기기에 저장). 다 보면 true 가 되고 라우터가 로그인으로 보낸다.
final tutorialSeenProvider = NotifierProvider<TutorialSeen, bool>(TutorialSeen.new);

class TutorialSeen extends Notifier<bool> {
  @override
  bool build() => ref.read(localStoreProvider).tutorialSeen;

  Future<void> markSeen() async {
    await ref.read(localStoreProvider).markTutorialSeen();
    state = true;
  }
}

/// 튜토리얼 한 장: 위 작은 글(14 SemiBold) · 제목(22 Bold) · 가운데 그림
class _Page {
  const _Page({required this.eyebrow, required this.title, required this.image});

  final String eyebrow;
  final String title;
  final String image;
}

/// 피그마 "튜토리얼" (1300:8056 · 1313:7382 · 1313:7424) — 스플래시 다음, 로그인 전에 한 번만.
/// 3장을 넘기며(스와이프 또는 "다음") 보고, 마지막 장에서 로그인으로.
/// 피그마 섹션이 "그래픽 필요함" 상태라 세 장 모두 같은 문구·그림이다. 확정되면 [_pages] 만 바꾸면 된다.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  static const _pages = [
    _Page(eyebrow: '복잡한 기업 분석을 한 번에', title: 'DART 기반 공시정보를\n퀴즈로 빠르게 학습해요', image: 'assets/images/tutorial_1.png'),
    _Page(eyebrow: '복잡한 기업 분석을 한 번에', title: 'DART 기반 공시정보를\n퀴즈로 빠르게 학습해요', image: 'assets/images/tutorial_1.png'),
    _Page(eyebrow: '복잡한 기업 분석을 한 번에', title: 'DART 기반 공시정보를\n퀴즈로 빠르게 학습해요', image: 'assets/images/tutorial_1.png'),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _index == _pages.length - 1;

  void _next() {
    if (_last) {
      ref.read(tutorialSeenProvider.notifier).markSeen(); // 라우터가 로그인으로 보낸다
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _PageView(page: _pages[i]),
              ),
            ),
            // 점 3개 (9×9, 간격 10): 지금 장 #55565A, 나머지 #DCE0E7
            Semantics(
              label: '${_pages.length}장 중 ${_index + 1}번째',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.textSub : AppColors.fillMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 피그마: 점(633) 아래로 버튼(782)까지 비어 있다
            const SizedBox(height: 134),
          ],
        ),
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: _last ? '시작하기' : '다음', onPressed: _next),
      ]),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        children: [
          // 피그마: 위 글 159 (내비 아래), 그림 325~556
          const SizedBox(height: 97),
          Text(
            page.eyebrow,
            textAlign: TextAlign.center,
            style: AppTypography.body2Strong.copyWith(color: const Color(0xFF4A4A4A), height: 1.4),
          ),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: AppTypography.title1.copyWith(fontSize: 22, fontWeight: AppTypography.bold, color: AppColors.textStrong, height: 1.3),
            ),
          ),
          const Spacer(),
          Image.asset(page.image, width: 202, height: 231, excludeFromSemantics: true),
          const Spacer(),
        ],
      ),
    );
  }
}
