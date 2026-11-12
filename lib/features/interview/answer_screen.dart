import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/error/app_exception.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/speech_service.dart';
import '../../core/storage/local_store.dart';
import '../../data/models/interview.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';
import '../common/format.dart';
import 'interview_widgets.dart';

enum _Mode {
  writing,
  voiceReady,
  recording,
  voiceStopped,
  converting,
  voiceReview,
  analyzing,
}

/// 피그마 최종 4-3 답변 작성 · 4-4 말로 답하기(녹음 전 → 녹음 중 → 녹음 완료 → 텍스트 변환 중 → 내 답변) · 4-5 답변 분석 중
/// - 쓰는 중인 답변은 기기에 자동 임시 저장, "임시저장" 을 누르면 서버에도 저장 (복습 탭 "작성 중")
/// - 말로 답하면 기기 STT 로 글자로 바꾼 뒤 직접 고쳐서 제출
class AnswerScreen extends ConsumerStatefulWidget {
  const AnswerScreen({
    super.key,
    required this.questionId,
    this.startWithVoice = false,
  });

  final String questionId;

  /// 질문 화면 "음성으로 답변하기" 로 들어오면 바로 녹음을 시작한다
  final bool startWithVoice;

  @override
  ConsumerState<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends ConsumerState<AnswerScreen> {
  late final TextEditingController _text;
  late final LocalStore _store;
  SpeechService? _speech;
  Timer? _draftTimer;
  _Mode _mode = _Mode.writing;
  bool _usedVoice = false;
  bool _savingDraft = false;
  bool _leaving = false;
  bool _hasSubmissionRequest = false;
  bool _answerAccepted = false;
  Future<void> _draftSave = Future<void>.value();

  /// 말로 답하기를 시작하기 전 글 (다시 녹음하면 여기로 되돌린다)
  String _beforeVoice = '';

  /// 멈췄다 이어 녹음한 시간 합
  Duration _priorElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _store = ref.read(localStoreProvider);
    final pending = ref.read(interviewRepositoryProvider).pendingSubmission(widget.questionId);
    _hasSubmissionRequest = pending != null;
    _answerAccepted = pending?.attemptId != null;
    _text = TextEditingController(
      text: pending?.text ?? _store.readDraft(widget.questionId) ?? '',
    );
    _text.addListener(_scheduleDraftSave);
    if (_text.text.isEmpty && pending == null) _loadServerDraft();
    if (pending?.attemptId != null) {
      _mode = _Mode.analyzing;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFeedback(pending!.attemptId!);
      });
    } else if (widget.startWithVoice && pending == null) {
      _mode = _Mode.voiceReady;
    }
  }

  Future<void> _loadServerDraft() async {
    try {
      final draft = await ref
          .read(interviewRepositoryProvider)
          .fetchDraft(widget.questionId);
      if (mounted && !_hasSubmissionRequest && draft != null && _text.text.isEmpty) {
        setState(() => _text.text = draft);
      }
    } catch (_) {
      // 서버 임시저장을 못 불러와도 새로 쓰면 된다
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _saveLocalDraft();
    _text.dispose();
    _speech?.dispose();
    super.dispose();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    if (_hasSubmissionRequest || _answerAccepted) return;
    _draftTimer = Timer(const Duration(milliseconds: 800), _saveLocalDraft);
  }

  void _saveLocalDraft() {
    if (_hasSubmissionRequest || _answerAccepted) return;
    final text = _text.text;
    _draftSave = _draftSave.then((_) async {
      if (!_answerAccepted) await _store.saveDraft(widget.questionId, text);
    }).catchError((Object _) {});
  }

  Future<void> _openFeedback(String attemptId) async {
    _answerAccepted = true;
    _hasSubmissionRequest = true;
    _draftTimer?.cancel();
    _text.removeListener(_scheduleDraftSave);
    try {
      // 이미 시작한 저장까지 끝낸 뒤 삭제해 임시 답변 재생성을 막는다.
      await _draftSave;
      await _store.clearDraft(widget.questionId);
      if (!mounted) return;
      await ref.read(interviewRepositoryProvider).acknowledgeSubmission(widget.questionId, attemptId);
    } catch (_) {
      // 정리 실패 시 접수 기록을 유지한다. 재진입해도 같은 attemptId로 복구한다.
    }
    if (!mounted) return;
    _text.clear();
    invalidateProgress(ref);
    ref.invalidate(interviewQuestionProvider(widget.questionId));
    _leaving = true;
    context.pushReplacement(Routes.feedback(attemptId));
  }

  int get _length => _text.text.trim().characters.length;

  bool get _canSubmit => _length >= AppPolicy.minAnswerLength && !_savingDraft;

  // ---------------------------------------------------------------- 말로 답하기

  Future<void> _startRecording({bool restart = false}) async {
    if (_hasSubmissionRequest) {
      showToast(context, '접수 여부를 확인 중이에요. 기존 제출을 먼저 확인해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    final speech = _speech ??= SpeechService()..addListener(_onSpeech);
    if (restart) {
      await speech.cancel();
      // 다시 녹음: 말로 바꾼 내용은 지우고 처음부터
      _text.text = _beforeVoice;
      _priorElapsed = Duration.zero;
    } else if (_mode == _Mode.voiceReady) {
      _beforeVoice = _text.text;
      _priorElapsed = Duration.zero;
    } else if (_mode == _Mode.voiceStopped) {
      _priorElapsed += speech.elapsed;
    }
    setState(() => _mode = _Mode.recording);
    await speech.start();
    if (!mounted) return;
    if (speech.status == SpeechStatus.permissionDenied) {
      setState(() => _mode = _Mode.voiceReady);
      await _askMicPermission();
    } else if (speech.status == SpeechStatus.unavailable) {
      setState(() => _mode = _Mode.writing);
      showToast(context, '이 기기에서는 음성 인식을 쓸 수 없어요. 텍스트로 작성해 주세요.');
    }
  }

  Future<void> _stopRecording() async {
    final speech = _speech;
    if (speech == null) return;
    await speech.stop();
    if (!mounted) return;
    final spoken = speech.text.trim();
    final hadVoice = _text.text.trim() != _beforeVoice.trim();
    setState(() {
      // 말한 내용이 있으면 "녹음을 멈췄어요" → 다시 녹음하기 / 답변을 완료했어요
      _mode = spoken.isEmpty && !hadVoice
          ? _Mode.voiceReady
          : _Mode.voiceStopped;
      if (spoken.isNotEmpty) {
        _usedVoice = true;
        final joined = [
          _text.text.trim(),
          spoken,
        ].where((s) => s.isNotEmpty).join('\n');
        _text.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      }
    });
    if (spoken.isEmpty && !hadVoice) {
      showToast(context, '말한 내용을 알아듣지 못했어요. 다시 녹음해 주세요.');
    }
  }

  /// "답변을 완료했어요" → 4-4 텍스트 변환 중 → 내 답변 확인·수정
  Future<void> _finishVoice() async {
    setState(() => _mode = _Mode.converting);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted && _mode == _Mode.converting) {
      setState(() => _mode = _Mode.voiceReview);
    }
  }

  /// 피그마 4-4 마이크 허용: "마이크 권한이 필요해요" → 취소 / 설정으로 이동
  Future<void> _askMicPermission() async {
    final go = await showConfirmDialog(
      context,
      title: '마이크 권한이 필요해요',
      message: '답변 녹음을 위해\n마이크 권한을 활성화해 주세요.',
      cancelLabel: '취소',
      confirmLabel: '설정으로 이동',
    );
    if (!go || !mounted) return;
    final opened = await ref.read(linkServiceProvider).openAppSettings();
    if (!opened && mounted) {
      showToast(context, '휴대폰 설정 > 앱 > Dadot에서 마이크·음성 인식을 켜 주세요.');
    }
  }

  void _onSpeech() {
    final s = _speech;
    if (s == null || !mounted) return;
    if (s.status == SpeechStatus.stopped &&
        s.autoStopped &&
        _mode == _Mode.recording) {
      s.autoStopped = false;
      _stopRecording();
      showToast(context, '3분이 지나 녹음을 마쳤어요.');
      return;
    }
    // 녹음을 누른 뒤에 기기가 못 듣겠다고 알려 오는 경우 (iOS 시뮬레이터 등):
    // 녹음 중 화면에 갇히지 않게 바로 빠져나온다
    if (_mode == _Mode.recording) {
      if (s.status == SpeechStatus.unavailable) {
        setState(() => _mode = _Mode.writing);
        showToast(context, '이 기기에서는 음성 인식을 쓸 수 없어요. 텍스트로 작성해 주세요.');
        return;
      }
      if (s.status == SpeechStatus.permissionDenied) {
        setState(() => _mode = _Mode.voiceReady);
        _askMicPermission();
        return;
      }
      // 서비스가 스스로 듣기를 멈춘 경우 (실패가 이어져 포기) → 멈춤 화면으로
      if (s.status == SpeechStatus.stopped) {
        _stopRecording();
        return;
      }
    }
    setState(() {});
  }

  // ---------------------------------------------------------------- 저장 · 제출

  Future<void> _saveDraft({bool leave = false}) async {
    if (_hasSubmissionRequest || _answerAccepted) {
      if (leave) {
        _leaving = true;
        if (mounted) Navigator.of(context).pop();
      } else {
        showToast(context, '제출한 답변의 접수 여부를 먼저 확인해 주세요.');
      }
      return;
    }
    setState(() => _savingDraft = true);
    _saveLocalDraft();
    try {
      await ref
          .read(interviewRepositoryProvider)
          .saveDraft(questionId: widget.questionId, content: _text.text);
      ref.invalidate(interviewRecordsProvider);
      if (!mounted) return;
      showToast(context, '임시저장했어요. 복습 탭에서 이어 쓸 수 있어요.');
      if (leave) {
        _leaving = true;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      if (leave) {
        // 서버 저장이 막혀도(기회 소진 등) 나가기는 된다. 글은 기기에 저장돼 있다.
        _leaving = true;
        Navigator.of(context).pop();
      } else {
        showErrorToast(context, e);
      }
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  /// 기회를 다 쓴 질문: 안내만 띄우고 질문 화면(또는 복습)으로 돌려보낸다. 화면에 갇히지 않게.
  Future<void> _leaveBlocked(String message, {String? reason}) async {
    _hasSubmissionRequest = true;
    _draftTimer?.cancel();
    await _draftSave;
    await _store.clearDraft(widget.questionId);
    ref.invalidate(interviewQuestionProvider(widget.questionId));
    ref.invalidate(interviewRecordsProvider);
    invalidateProgress(ref);
    if (!mounted) return;
    await showNoticeDialog(context, title: message, message: AppException.submissionHelp(reason), buttonLabel: '확인');
    if (!mounted) return;
    _leaving = true;
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    if (_mode == _Mode.analyzing || _savingDraft || _answerAccepted) return;
    final repository = ref.read(interviewRepositoryProvider);
    final pending = repository.pendingSubmission(widget.questionId);
    final question = ref.read(interviewQuestionProvider(widget.questionId)).asData?.value;
    // 응답 유실 복구는 새 제출이 아니다. 소진·처리 중이어도 같은 키로 결과를 확인한다.
    if (pending == null && question != null && question.blocked) {
      await _leaveBlocked(question.blockedMessage, reason: question.effectiveBlockedReason);
      return;
    }
    if (_length < AppPolicy.minAnswerLength) {
      showToast(context, '${AppPolicy.minAnswerLength}자 이상 써 주세요. (지금 $_length자)');
      return;
    }
    FocusScope.of(context).unfocus();
    _saveLocalDraft();
    _draftTimer?.cancel();
    _hasSubmissionRequest = true;
    setState(() => _mode = _Mode.analyzing);
    try {
      await _draftSave;
      final attemptId = await repository.submitAnswerForEvaluation(
        questionId: widget.questionId,
        content: _text.text.trim(),
        inputType: _usedVoice ? AnswerInputType.voice : AnswerInputType.text,
      );
      if (mounted) await _openFeedback(attemptId);
    } catch (e) {
      if (!mounted) return;
      final current = repository.pendingSubmission(widget.questionId);
      if (current?.attemptId != null) {
        await _openFeedback(current!.attemptId!);
        return;
      }
      _hasSubmissionRequest = current != null;
      setState(() => _mode = _Mode.writing);
      final err = asAppException(e);
      if (current != null) {
        showToast(context, AppException.submissionMessage(err.code) ??
            '접수 여부를 확인하지 못했어요. 다시 제출하면 기존 요청으로 확인해요.');
      } else if (err.kind == AppErrorKind.feedbackQuotaExceeded) {
        await _leaveBlocked(err.userMessage, reason: err.code);
      } else {
        showErrorToast(context, err);
      }
    }
  }

  /// 4-E6 작성 중 나가기 확인 (피그마 프레임이 비어 있어 확인 팝업으로)
  /// 피그마 1074:11423 "답변을 그만할까요? / 지금까지 작성한 내용은 임시 저장돼요" → 계속 진행하기 / 나가기
  Future<void> _confirmLeave() async {
    if (_mode == _Mode.recording) {
      await _stopRecording();
      return;
    }
    if (_mode == _Mode.analyzing || _mode == _Mode.converting) return;
    if (_hasSubmissionRequest || _answerAccepted) {
      _leaving = true;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_text.text.trim().isEmpty) {
      // 아직 쓴 게 없으면 묻지 않는다. 말로 답하기에서 뒤로 → 답변 작성 (질문 화면에서 바로 왔으면 나간다)
      if (_mode != _Mode.writing && !widget.startWithVoice) {
        setState(() => _mode = _Mode.writing);
        return;
      }
      _leaving = true;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final leave = await showConfirmDialog(
      context,
      warning: true,
      title: '답변을 그만할까요?',
      message: '지금까지 작성한 내용은 임시 저장돼요',
      cancelLabel: '계속 진행하기',
      confirmLabel: '나가기',
    );
    if (leave && mounted) await _saveDraft(leave: true);
  }

  /// ✕: 면접 흐름을 닫고 홈으로. 녹음 중이면 먼저 멈추고, 쓴 글이 있으면 같은 확인을 거친다.
  Future<void> _closeFlow() async {
    if (_mode == _Mode.recording) await _stopRecording();
    if (!mounted) return;
    if (_hasSubmissionRequest || _answerAccepted || _text.text.trim().isEmpty) {
      _leaving = true;
      context.go(Routes.home);
      return;
    }
    final leave = await showConfirmDialog(
      context,
      warning: true,
      title: '답변을 그만할까요?',
      message: '지금까지 작성한 내용은 임시 저장돼요',
      cancelLabel: '계속 진행하기',
      confirmLabel: '나가기',
    );
    if (leave && mounted) {
      await _saveDraft(leave: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(interviewQuestionProvider(widget.questionId));
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final voice =
        _mode == _Mode.voiceReady ||
        _mode == _Mode.recording ||
        _mode == _Mode.voiceStopped ||
        _mode == _Mode.voiceReview;
    final title = voice ? '말로 답하기' : '답변 작성';

    Widget body;
    List<Widget>? bottom;
    if (_mode == _Mode.analyzing) {
      body = const ProcessingView(
        title: '답변을 분석하고 있어요',
        graphic: StateGraphic.analyze,
      );
    } else if (_mode == _Mode.converting) {
      body = const ProcessingView(
        title: '답변을 텍스트로 변환 중이에요',
        graphic: StateGraphic.convert,
      );
    } else {
      final header = q.when(
        loading: () => const SizedBox(height: 80, child: LoadingView()),
        error: (e, _) => ErrorView(
          error: e,
          compact: true,
          onRetry: () =>
              ref.invalidate(interviewQuestionProvider(widget.questionId)),
        ),
        data: (q) => QuestionCard(question: q),
      );
      if (_mode == _Mode.voiceReady ||
          _mode == _Mode.recording ||
          _mode == _Mode.voiceStopped) {
        // 피그마 1540:11882 · 1540:11963 · 1540:11748: 내비 아래 23 에 질문(26 Bold),
        // 16 아래 "답변은 최대 3분" 카드, 그 아래 90 에 녹음 버튼
        body = SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            23,
            AppSpacing.screenH,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 피그마: 녹음 영역은 질문 길이와 상관없이 내비 아래 289 에서 시작 (위 여백 23 + 266)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 266),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    q.when(
                      loading: () => const SizedBox(height: 80, child: LoadingView()),
                      error: (e, _) => ErrorView(
                        error: e,
                        compact: true,
                        onRetry: () => ref.invalidate(interviewQuestionProvider(widget.questionId)),
                      ),
                      data: (q) => QuestionHeadline(q.text),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _VoiceTip(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
              _VoicePanel(
                speech: _speech,
                priorElapsed: _priorElapsed,
                state: switch (_mode) {
                  _Mode.recording => _VoiceState.recording,
                  _Mode.voiceStopped => _VoiceState.stopped,
                  _ => _VoiceState.ready,
                },
                onTap: () => _mode == _Mode.recording ? _stopRecording() : _startRecording(),
              ),
              // 멈춤 상태에서 아래 버튼 뒤 흰 그라데이션에 가려지지 않게 여유
              const SizedBox(height: 120),
            ],
          ),
        );
      } else {
        body = ListView(
          // 아래로 쓸어내리면 키보드가 내려간다 (여러 줄 입력이라 키보드 '완료' 키가 없음)
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xl,
          ),
          children: [
            header,
            const SizedBox(height: 28),
            if (_mode == _Mode.voiceReview)
              ..._voiceReviewPanel()
            else
              ..._writingPanel(),
          ],
        );
      }
      bottom = switch (_mode) {
        // 피그마 1540:11882: 녹음 전에는 눌리지 않는 "제출하기" 만 / 녹음 중에는 버튼 없음
        _Mode.voiceReady => [const AppButton(label: '제출하기', onPressed: null)],
        _Mode.recording => null,
        _Mode.voiceStopped => [
          AppButton(
            label: '다시 녹음하기',
            variant: AppButtonVariant.secondary,
            onPressed: () => _startRecording(restart: true),
          ),
          AppButton(label: '답변을 완료했어요', onPressed: _finishVoice),
        ],
        _Mode.voiceReview => [
          AppButton(
            label: '다시 녹음하기',
            variant: AppButtonVariant.secondary,
            onPressed: () => _startRecording(restart: true),
          ),
          AppButton(label: '답변 제출하기', onPressed: _canSubmit ? _submit : null),
        ],
        // 답변 작성: 글자를 쓰기 시작하면 버튼이 보이고, 최소 글자 수를 넘기면 제출할 수 있다
        _ =>
          _length == 0
              ? null
              : [
                  AppButton(
                    label: '임시 저장',
                    variant: AppButtonVariant.secondary,
                    loading: _savingDraft,
                    onPressed: _saveDraft,
                  ),
                  AppButton(
                    label: '제출하기',
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ],
      };
    }

    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _mode == _Mode.analyzing || _mode == _Mode.converting
            ? null
            : AppNavBar(
                title: title,
                onBack: _confirmLeave,
                // 피그마 1540: 말로 답하기 오른쪽 위 ✕
                onClose: voice ? _closeFlow : null,
              ),
        // 피그마 4-3 작성 완료 (763:19912): 임시 저장 / 제출하기 버튼은 키보드가 내려간 전체 화면일 때만 보인다.
        // 글을 쓰는 동안(키보드가 올라와 있을 때)은 버튼을 숨기고, 입력칸 밖을 누르거나 쓸어내리면 키보드가 내려가며 버튼이 나온다.
        body: _mode == _Mode.analyzing || _mode == _Mode.converting
            ? SafeArea(child: body)
            : GestureDetector(
                // 입력칸 밖을 누르면 키보드를 내린다
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: _mode == _Mode.voiceStopped && bottom != null
                    // 피그마 1540:11651: 버튼 뒤로 위쪽이 투명한 흰 그라데이션 (본문이 그 아래로 지나간다)
                    ? Stack(
                        children: [
                          Positioned.fill(child: body),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00FFFFFF), Colors.white],
                                  stops: [0.0954, 0.368],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 60),
                                child: BottomCta(color: Colors.transparent, children: bottom),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: body),
                          if (bottom != null && !keyboardOpen)
                            BottomCta(children: bottom),
                        ],
                      ),
              ),
      ),
    );
  }

  /// 4-4 텍스트 변환: "내 답변" + 흰 카드 (눌러서 고칠 수 있음)
  List<Widget> _voiceReviewPanel() => [
    Text(
      '내 답변',
      style: AppTypography.body2Medium.copyWith(
        color: AppColors.textPlaceholder,
      ),
    ),
    const SizedBox(height: AppSpacing.sm),
    AbsorbPointer(
      absorbing: _hasSubmissionRequest,
      child: AppTextField(
        controller: _text,
        minLines: 7,
        maxLines: 16,
        maxLength: AppPolicy.maxAnswerLength,
        showLimitInCounter: false,
        onChanged: (_) => setState(() {}),
      ),
    ),
    const SizedBox(height: AppSpacing.xs),
    _LengthHint(length: _length),
    const SizedBox(height: AppSpacing.xxs),
    Text('잘못 바뀐 글자는 눌러서 바로 고칠 수 있어요.', style: AppTypography.caption),
  ];

  /// 4-3 답변 작성: "말로 답하기" 카드 + 흰 입력 카드
  List<Widget> _writingPanel() => [
    Semantics(
      button: true,
      label: '말로 답하기. 실제 면접처럼 소리 내어 연습해요',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: () {
            if (_hasSubmissionRequest) {
              showToast(context, '제출한 답변의 접수 여부를 먼저 확인해 주세요.');
              return;
            }
            FocusScope.of(context).unfocus();
            setState(() => _mode = _Mode.voiceReady);
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.cardDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    size: 22,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('말로 답하기', style: AppTypography.body2Strong),
                      const SizedBox(height: 2),
                      Text(
                        '실제 면접처럼 소리내어 연습해요',
                        style: AppTypography.micro.copyWith(
                          color: AppColors.textPlaceholder,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    const SizedBox(height: AppSpacing.lg),
    AbsorbPointer(
      absorbing: _hasSubmissionRequest,
      child: AppTextField(
        controller: _text,
        hint: '질문에 대한 내 생각을 적어 주세요.\n기업 근거와 내 역할·행동을 연결하면 좋아요.',
        minLines: 6,
        maxLines: 16,
        maxLength: AppPolicy.maxAnswerLength,
        showLimitInCounter: false,
        onChanged: (_) => setState(() {}),
      ),
    ),
    if (_length > 0) ...[
      const SizedBox(height: AppSpacing.xs),
      _LengthHint(length: _length),
    ],
  ];
}

/// 입력칸 아래 "30자 이상 쓰면 제출할 수 있어요 (지금 12자)" — 넘기면 사라진다
class _LengthHint extends StatelessWidget {
  const _LengthHint({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    if (length >= AppPolicy.minAnswerLength) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Text(
        '${AppPolicy.minAnswerLength}자 이상 쓰면 제출할 수 있어요 (지금 $length자)',
        style: AppTypography.caption.copyWith(color: AppColors.textCaption),
      ),
    );
  }
}

/// 4-4 "답변은 최대 3분 정도를 추천해요 / 간결하고 핵심만 담아서 말하기" 흰 카드
class _VoiceTip extends StatelessWidget {
  const _VoiceTip();

  @override
  Widget build(BuildContext context) {
    // 피그마 1541:12746: 흰 카드 · 모서리 16 · 안쪽 4 · 44 아이콘 칸(타이머 20) + 16 Medium #303137 한 줄
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          const SizedBox(width: 44, height: 44, child: Center(child: TimerIcon())),
          Expanded(
            child: Text(
              '답변은 최대 ${AppPolicy.voiceMaxDuration.inMinutes}분 정도를 추천해요',
              style: AppTypography.rowTitle.copyWith(color: const Color(0xFF303137)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 피그마 icon/timer (20×20, #27282C)
class TimerIcon extends StatelessWidget {
  const TimerIcon({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(width: 20, height: 20, child: CustomPaint(painter: _TimerPainter())),
  );
}

class _TimerPainter extends CustomPainter {
  const _TimerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFF27282C);
    // 원본 16.25×18.875 를 20×20 칸 가운데에 둔다
    canvas.translate((size.width - 16.25) / 2, (size.height - 18.875) / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(6.458, 0.75), const Offset(9.792, 0.75), stroke);
    canvas.drawLine(const Offset(8.125, 0.75), const Offset(8.125, 3.25), stroke);
    canvas.drawLine(const Offset(13.542, 4.917), const Offset(13.958, 4.5), stroke);
    // 시계 몸통 (가운데 바늘은 비워 둔다)
    canvas.drawCircle(const Offset(8.125, 10.75), 8.125, Paint()..color = color);
    canvas.drawLine(
      const Offset(8.125, 10.75),
      const Offset(10.625, 8.25),
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TimerPainter old) => false;
}

enum _VoiceState { ready, recording, stopped }

/// 4-4 말로 답하기: 녹음 전(진한 원 + 마이크) / 녹음 중(라임 원 + 파형 · 시간) / 녹음 완료(진한 원 · 시간)
class _VoicePanel extends StatelessWidget {
  const _VoicePanel({
    required this.speech,
    required this.state,
    required this.onTap,
    this.priorElapsed = Duration.zero,
  });

  final SpeechService? speech;
  final _VoiceState state;
  final VoidCallback onTap;
  final Duration priorElapsed;

  @override
  Widget build(BuildContext context) {
    final recording = state == _VoiceState.recording;
    final ready = state == _VoiceState.ready;
    final elapsed = priorElapsed + (speech?.elapsed ?? Duration.zero);
    final starting =
        recording &&
        (speech == null || speech!.status == SpeechStatus.initializing);
    // 피그마 1540:12125 · 12018 · 11651: 링은 박스 밖으로 선이 그려진다
    // 바깥 지름 녹음 전 141.6 (선 2.4 #DCE0E7) / 녹음 중 123.9 (선 2.1 #BCBFC5) / 멈춤 124.5 (선 2.4 #DCE0E7)
    final box = ready ? 136.8 : 119.7;
    final stroke = ready ? 2.4 : (recording ? 2.1 : 2.4);
    final ringColor = recording ? const Color(0xFFBCBFC5) : AppColors.fillMuted;
    final outer = box + 2 * stroke;
    final inner = ready ? 125.6 : 109.9;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: recording ? '녹음 멈추기' : '녹음 시작하기',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: starting ? null : onTap,
            child: SizedBox(
              width: outer,
              height: outer,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: outer,
                    height: outer,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: stroke),
                    ),
                  ),
                  Container(
                    width: inner,
                    height: inner,
                    decoration: BoxDecoration(
                      color: recording ? AppColors.point : const Color(0xFF27282C),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: recording ? const _Waveform() : const _MicIcon(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (ready)
          Text(
            '버튼을 눌러\n답변을 시작하세요',
            textAlign: TextAlign.center,
            // 피그마 1541:12599: 20 SemiBold · 줄 140% · #15171B
            style: AppTypography.title4.copyWith(color: AppColors.textSub, height: 1.4, letterSpacing: -0.6),
          )
        else ...[
          Semantics(
            liveRegion: true,
            child: Text(
              formatClock(elapsed),
              // 피그마 1540:11773: 24 SemiBold · 줄 145% · 자간 -0.72
              style: AppTypography.title1.copyWith(
                fontSize: 24,
                fontWeight: AppTypography.semibold,
                color: AppColors.ink,
                height: 1.45,
                letterSpacing: -0.72,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recording ? (starting ? '준비하고 있어요' : '녹음 중이에요') : '녹음을 멈췄어요',
            textAlign: TextAlign.center,
            style: AppTypography.title4.copyWith(color: AppColors.ink, height: 1.4, letterSpacing: -0.6),
          ),
          const SizedBox(height: 2),
          Text(
            recording ? '다시 터치하면 녹음을 멈춰요' : '다시 터치하면 녹음을 시작해요',
            textAlign: TextAlign.center,
            style: AppTypography.rowTitle.copyWith(color: AppColors.textCaption),
          ),
        ],
      ],
    );
  }
}

/// 녹음 버튼 안 마이크 (피그마 1540:11771 — 흰 선 2, 32×39.5)
class _MicIcon extends StatelessWidget {
  const _MicIcon();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(width: 32, height: 39.5, child: CustomPaint(painter: _MicPainter())),
  );
}

class _MicPainter extends CustomPainter {
  const _MicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // 마이크 몸통 (둥근 알약, 채움)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8.5, 1, 15, 24.375), const Radius.circular(7.5)),
      Paint()..color = AppColors.white,
    );
    // 아래 반원 + 받침대
    canvas.drawArc(Rect.fromCircle(center: const Offset(16, 18.8125), radius: 15), 0, 3.14159265, false, white);
    canvas.drawLine(const Offset(16, 38.5), const Offset(16, 34.75), white);
  }

  @override
  bool shouldRepaint(_MicPainter old) => false;
}

/// 녹음 중 원 안의 파형 (피그마 4-4 녹음 중). 막대가 천천히 움직인다.
class _Waveform extends StatefulWidget {
  const _Waveform();

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 피그마 Burger: 막대 5개 · 두께 3 · 둥근 끝 · #27282C, 높이 [18.4, 12.6, 26.5, 18.4, 12.6] 가운데 정렬
    const base = [18.435, 12.555, 26.52, 18.435, 12.555];
    return ExcludeSemantics(
      child: SizedBox(
        height: 38.28,
        width: 38.28,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: 3,
                  height: base[i] * (0.65 + 0.35 * (i.isEven ? _c.value : 1 - _c.value)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27282C),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
