import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/app_info.dart';
import '../../design_system/design_system.dart';

/// 6-4 서비스 문의·오류 제보 — 완성본 와이어프레임: 앱 안 입력 대신 구글폼으로 접수한다.
/// (서버 문의 API · InquiryRepository 는 나중에 다시 쓸 수 있게 남겨 둠)
class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    final url = ref.read(appConfigProvider).inquiryFormUrl;
    final ok = await ref.read(linkServiceProvider).open(url);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!ok) showToast(context, '문의 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '문의'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const PageTitle('어떤 점이\n궁금하거나 불편했나요?', description: '문의·오류 제보는 구글폼으로 받아요. 확인 후 답변 드릴게요.'),
          const SizedBox(height: AppSpacing.lg),
          InfoBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('적어 주시면 빨리 확인할 수 있어요', style: AppTypography.body2Strong),
                const SizedBox(height: AppSpacing.xs),
                Text('· 어떤 화면에서 무엇을 하다가 생긴 일인지\n· 앱 버전 ${AppInfo.version} (${AppInfo.platform})', style: AppTypography.body2),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomCta(children: [
        AppButton(label: '문의 접수하기', loading: _opening, onPressed: _opening ? null : _open),
      ]),
    );
  }
}
