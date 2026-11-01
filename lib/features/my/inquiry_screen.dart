import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/app_info.dart';
import '../../design_system/design_system.dart';

/// 6-10 서비스 문의·오류 제보 — 앱 안 입력 대신 구글폼으로 접수한다.
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
    // 피그마 최종 6-10 "구글폼으로" (763:15362): 제목 + "서비스 문의 및 오류제보 ›" 한 줄
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '문의하기'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.xl),
        children: [
          Semantics(
            header: true,
            child: Text('앱을 쓰시다 불편한 점이\n있으시다면 문의해주세요.', style: AppTypography.title2.copyWith(color: AppColors.ink)),
          ),
          const SizedBox(height: AppSpacing.xl),
          MenuGroup(children: [
            MenuRow(
              title: '서비스 문의 및 오류제보',
              onTap: _opening ? null : _open,
              showChevron: !_opening,
              value: _opening ? '여는 중' : null,
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxs),
            child: Text('앱 버전 ${AppInfo.version} (${AppInfo.platform})', style: AppTypography.caption.copyWith(color: AppColors.textGuide)),
          ),
        ],
      ),
    );
  }
}
