import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import 'quiz_widgets.dart';

/// 3-1 오늘의 퀴즈 · 문제 풀이 (객관식 · 주관식)
/// 완성본 와이어프레임: 문제마다 정답을 보여주지 않고 "다음 문제로" 넘어간다. 정답·해설·공시 근거는 결과(3-1 결과)에서 본다.
/// 이미 푼 문항은 건너뛰고 이어서 푼다. 다 풀었으면 결과로.
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
  String? _selected;
  final _short = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _short.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final set = await ref.read(quizRepositoryProvider).fetchTodaySet(widget.companyId);
      if (!mounted) return;
      if (set.isCompleted) {
        context.pushReplacement(Routes.quizResult(set.id));
        return;
      }
      setState(() {
        _set = set;
        _index = set.nextIndex;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  QuizQuestion get _question => _set!.questions[_index];

  String? get _answer => _question.kind == QuizKind.choice ? _selected : (_short.text.trim().isEmpty ? null : _short.text.trim());

  /// 답을 제출(채점은 서버)하고 바로 다음 문제로. 마지막 문제면 결과로.
  Future<void> _submitAndNext() async {
    final answer = _answer;
    if (answer == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref.read(quizRepositoryProvider).submitAnswer(setId: _set!.id, questionId: _question.id, answer: answer);
      invalidateProgress(ref);
      if (!mounted) return;
      if (_index + 1 >= _set!.questions.length) {
        context.pushReplacement(Routes.quizResult(_set!.id));
        return;
      }
      setState(() {
        _index += 1;
        _selected = null;
        _short.clear();
      });
    } catch (e) {
      if (mounted) showErrorToast(context, e);
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
    } else if (set == null) {
      body = const LoadingView();
    } else {
      final q = _question;
      final last = _index + 1 >= set.questions.length;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
        children: [
          Row(
            children: [
              Expanded(child: Text(set.companyName, style: AppTypography.body2Strong.copyWith(color: AppColors.textBody))),
              Text('${_index + 1} / ${set.questions.length}', style: AppTypography.body2Strong),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          StepBar(current: _index + 1, total: set.questions.length, gap: AppSpacing.xxs),
          const SizedBox(height: AppSpacing.sm),
          QuizPrompt(question: q),
          const SizedBox(height: AppSpacing.sm),
          QuizAnswerArea(
            question: q,
            selectedChoiceId: _selected,
            onSelect: (id) => setState(() => _selected = id),
            shortController: _short,
            onShortChanged: (_) => setState(() {}),
            result: null,
          ),
        ],
      );
      bottom = BottomCta(children: [
        AppButton(label: last ? '결과 보기' : '다음 문제로', loading: _submitting, onPressed: _answer == null ? null : _submitAndNext),
      ]);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '기업 퀴즈'),
      body: body,
      bottomNavigationBar: bottom,
    );
  }
}
