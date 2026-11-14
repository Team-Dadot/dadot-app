import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/error/app_exception.dart';
import '../../core/router/app_router.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'quiz_widgets.dart';

/// 3-1 오늘의 퀴즈 · 문제 풀이 (모두 객관식)
/// 완성본 와이어프레임: 문제마다 정답을 보여주지 않고 "다음 문제로" 넘어간다. 정답·해설·공시 근거는 결과(3-1 결과)에서 본다.
/// 이미 푼 문항은 건너뛰고 이어서 푼다. 다 풀었으면 결과로.
/// 피그마 최종 3-1: 흰 바탕, 제목 없는 내비(‹) + 라임 진행 막대 + "Q1." + 문제 26 + 보기 64 + 하단 "다음".
/// 3-E6: 풀다가 뒤로 가면 "퀴즈를 그만두시나요?" 팝업 (나가기 / 진행하기).
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  QuizSet? _set;
  Object? _error;
  int _index = 0;

  /// 화면을 열었을 때 시작한 문항 (이어 풀기면 0 이 아님)
  int _startIndex = 0;
  String? _selected;
  bool _submitting = false;
  bool _loading = false;
  bool _submissionAccepted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    final previousSet = _set;
    final previousQuestionId = previousSet != null && _index < previousSet.questions.length
        ? previousSet.questions[_index].id : null;
    setState(() { _loading = true; _error = null; });
    try {
      final set = await ref.read(quizRepositoryProvider).fetchTodaySet(widget.companyId);
      if (!mounted) return;
      if (set.isCompleted) {
        _submissionAccepted = false;
        context.pushReplacement(Routes.quizResult(set.id));
        return;
      }
      if (_submissionAccepted && set.id == previousSet?.id &&
          set.nextIndex < set.questions.length && set.questions[set.nextIndex].id == previousQuestionId) {
        throw const AppException(AppErrorKind.server, message: '제출은 완료됐어요. 진행 상태를 다시 불러와 주세요.');
      }
      setState(() {
        _set = set;
        _index = set.nextIndex;
        if (previousSet == null) _startIndex = set.nextIndex;
        _selected = null;
        _submissionAccepted = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  QuizQuestion get _question => _set!.questions[_index];

  String? get _answer => _selected;

  /// 답을 제출(채점은 서버)하고 바로 다음 문제로. 마지막 문제면 결과로.
  Future<void> _submitAndNext() async {
    if (_submitting || _loading) return;
    if (_submissionAccepted) {
      await _load();
      return;
    }
    final answer = _answer;
    if (answer == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref.read(quizRepositoryProvider).submitAnswer(
        setId: _set!.id,
        questionId: _question.id,
        answer: answer,
      );
      _submissionAccepted = true;
      unawaited(ref.read(analyticsServiceProvider).logEvent('quiz_answer_submit'));
      invalidateProgress(ref);
      if (!mounted) return;
      // 이후 조회 실패는 제출을 반복하지 않고 서버의 현재 위치를 다시 불러온다.
      await _load();
    } catch (e) {
      if (!mounted) return;
      final err = asAppException(e);
      if (err.code == 'ANSWER_ALREADY_SUBMITTED') {
        _submissionAccepted = true;
        invalidateProgress(ref);
        await _load();
      } else if (err.kind == AppErrorKind.network || err.kind == AppErrorKind.timeout ||
                 err.kind == AppErrorKind.server || err.kind == AppErrorKind.unknown) {
        // 응답 유실 시에도 현재 세트를 먼저 확인한다.
        setState(() => _error = e);
      } else {
        showErrorToast(context, err);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;
    Widget body;
    Widget? bottom;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (set == null || _loading) {
      body = const LoadingView();
    } else {
      final q = _question;
      final last = _index + 1 >= set.questions.length;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.xl,
        ),
        children: [
          Semantics(
            label:
                '${set.companyName} 퀴즈 ${set.questions.length}문제 중 ${_index + 1}번째',
            child: StepBar(
              current: _index + 1,
              total: set.questions.length,
              gap: 0,
            ),
          ),
          const SizedBox(height: 36),
          QuizPrompt(question: q, number: _index + 1),
          const SizedBox(height: AppSpacing.xl),
          QuizAnswerArea(
            question: q,
            selectedChoiceId: _selected,
            onSelect: (id) => setState(() => _selected = id),
            result: null,
          ),
        ],
      );
      bottom = BottomCta(
        color: AppColors.surface,
        children: [
          AppButton(
            label: last ? '결과보기' : '다음',
            loading: _submitting,
            onPressed: _answer == null || _submitting ? null : _submitAndNext,
          ),
        ],
      );
    }

    // 한 문제라도 고르거나 풀었으면 나갈 때 확인
    final dirty = set != null && (_index > _startIndex || _answer != null);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final keepGoing = await showChoiceDialog(
          context,
          title: '퀴즈를 그만두시나요?',
          // 피그마 3-E6 (1332:7710)
          message: '이어서 풀 수 있어요',
          cancelLabel: '나가기',
          confirmLabel: '진행하기',
          warning: true,
        );
        if (keepGoing == false && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppNavBar(title: '', color: AppColors.surface),
        body: body,
        bottomNavigationBar: bottom,
      ),
    );
  }
}
