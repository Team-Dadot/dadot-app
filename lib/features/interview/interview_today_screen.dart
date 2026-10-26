import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 4-1 면접 질문 생성 중 → 오늘 아직 답하지 않은 질문(4-2)으로 이동
class InterviewTodayScreen extends ConsumerStatefulWidget {
  const InterviewTodayScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<InterviewTodayScreen> createState() => _InterviewTodayScreenState();
}

class _InterviewTodayScreenState extends ConsumerState<InterviewTodayScreen> {
  Object? _error;
  bool _allDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _allDone = false;
    });
    try {
      final today = await ref.read(interviewRepositoryProvider).fetchToday(widget.companyId);
      if (!mounted) return;
      final next = today.nextQuestionId;
      if (next == null) {
        setState(() => _allDone = true);
      } else {
        context.pushReplacement(Routes.interview(next));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_allDone) {
      body = EmptyView(
        title: '오늘 면접 질문을 모두 답했어요',
        description: '복습 탭에서 답변을 다시 다듬을 수 있어요.',
        actionLabel: '면접 복습으로 가기',
        onAction: () {
          ref.read(selectedCompanyIdProvider.notifier).select(widget.companyId);
          context.go(Routes.reviewTab('interview'));
        },
      );
    } else {
      body = const ProcessingView(title: '질문을 만들고 있어요', iconAsset: 'assets/images/icons/load_question.png');
    }
    // 피그마 4-1 로딩: 내비 바 없이 가운데 회색 원 + "질문을 만들고 있어요"
    final loading = _error == null && !_allDone;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: loading ? null : const AppNavBar(title: '면접 질문'),
      body: loading ? SafeArea(child: body) : body,
    );
  }
}
