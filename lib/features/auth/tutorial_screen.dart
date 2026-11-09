import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../design_system/design_system.dart';

/// 첫 실행 튜토리얼을 봤는지 (기기에 저장). 다 보면 true 가 되고 라우터가 로그인으로 보낸다.
final tutorialSeenProvider = NotifierProvider<TutorialSeen, bool>(TutorialSeen.new);

class TutorialSeen extends Notifier<bool> {
  /// 개발용: --dart-define=ALWAYS_TUTORIAL=true 면 본 적 있어도 매번 보여 준다 (로그아웃 상태일 때)
  static const _always = bool.fromEnvironment('ALWAYS_TUTORIAL');

  @override
  bool build() => !_always && ref.read(localStoreProvider).tutorialSeen;

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

/// 피그마 "튜토리얼" (1468:9585 · 1468:9451 · 1468:9484) — 스플래시 다음, 로그인 전에 한 번만.
/// 3장을 넘기며(스와이프 또는 "다음") 보고, 마지막 장의 "다음" 에서 로그인으로.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  // 피그마 1468:9585 · 1468:9451 · 1468:9484. 글자가 그림 위에 겹쳐 있어 글자까지 함께 이미지로 넣고, 읽어 주기는 문구로 한다.
  static const _pages = [
    _Page(eyebrow: '복잡한 기업 분석을 한 번에', title: 'DART 기반 공시정보를\n퀴즈로 빠르게 학습', image: 'assets/images/tutorial_1.png'),
    _Page(eyebrow: '퀴즈 다음은 면접까지', title: '기업 맞춤 면접 질문과\n피드백까지 한 번에', image: 'assets/images/tutorial_2.png'),
    _Page(eyebrow: '면접이 가까워지면', title: '약한 부분만 골라\n다시 한번 점검', image: 'assets/images/tutorial_3.png'),
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
            // 피그마: 점(722) 아래 버튼(782)까지
            const SizedBox(height: 48),
          ],
        ),
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '다음', onPressed: _next),
      ]),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    // 피그마 화면(402×874)에서 상태바 아래(62)부터 점 위(715)까지를 그대로 그린 그림 (402×653)
    return Semantics(
      label: '${page.eyebrow}. ${page.title.replaceAll('\n', ' ')}',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: Image.asset(page.image, width: double.infinity, fit: BoxFit.contain, alignment: Alignment.topCenter),
      ),
    );
  }
}
