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

  /// 말로 답하기를 시작하기 전 글 (다시 녹음하면 여기로 되돌린다)
  String _beforeVoice = '';

  /// 멈췄다 이어 녹음한 시간 합
  Duration _priorElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _store = ref.read(localStoreProvider);
    _text = TextEditingController(
      text: _store.readDraft(widget.questionId) ?? '',
    );
    _text.addListener(_scheduleDraftSave);
    if (_text.text.isEmpty) _loadServerDraft();
    if (widget.startWithVoice) _mode = _Mode.voiceReady;
  }

  Future<void> _loadServerDraft() async {
    try {
      final draft = await ref
          .read(interviewRepositoryProvider)
          .fetchDraft(widget.questionId);
      if (mounted && draft != null && _text.text.isEmpty) {
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
    _draftTimer = Timer(const Duration(milliseconds: 800), _saveLocalDraft);
  }

  void _saveLocalDraft() => _store.saveDraft(widget.questionId, _text.text);

  int get _length => _text.text.trim().characters.length;

  bool get _canSubmit => _length >= AppPolicy.minAnswerLength;

  // ---------------------------------------------------------------- 말로 답하기

  Future<void> _startRecording({bool restart = false}) async {
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
    setState(() {});
  }

  // ---------------------------------------------------------------- 저장 · 제출

  Future<void> _saveDraft({bool leave = false}) async {
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
  Future<void> _leaveBlocked(String message) async {
    await _store.clearDraft(widget.questionId);
    ref.invalidate(interviewQuestionProvider(widget.questionId));
    ref.invalidate(interviewRecordsProvider);
    invalidateProgress(ref);
    if (!mounted) return;
    await showNoticeDialog(context, title: message, message: '내일 다시 도전해보세요!', buttonLabel: '확인');
    if (!mounted) return;
    _leaving = true;
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    final question = ref.read(interviewQuestionProvider(widget.questionId)).asData?.value;
    if (question != null && question.blocked) {
      await _leaveBlocked(question.blockedMessage);
      return;
    }
    if (_length < AppPolicy.minAnswerLength) {
      showToast(
        context,
        '${AppPolicy.minAnswerLength}자 이상 써 주세요. (지금 $_length자)',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _saveLocalDraft();
    setState(() => _mode = _Mode.analyzing);
    try {
      final feedback = await ref
          .read(interviewRepositoryProvider)
          .submitAnswer(
            questionId: widget.questionId,
            content: _text.text.trim(),
            inputType: _usedVoice
                ? AnswerInputType.voice
                : AnswerInputType.text,
          );
      await _store.clearDraft(widget.questionId);
      _text.removeListener(_scheduleDraftSave);
      _text.clear();
      invalidateProgress(ref);
      ref.invalidate(interviewQuestionProvider(widget.questionId));
      if (mounted) {
        _leaving = true;
        context.pushReplacement(Routes.feedback(feedback.answerId));
      }
    } on EvaluationFailed catch (e) {
      // 답변은 제출됐고 평가만 실패 → 결과 화면에서 "다시 시도하기" (피그마 4-E4)
      await _store.clearDraft(widget.questionId);
      invalidateProgress(ref);
      if (mounted) {
        _leaving = true;
        context.pushReplacement(Routes.feedback(e.answerId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _mode = _Mode.writing);
      final err = asAppException(e);
      if (err.kind == AppErrorKind.feedbackQuotaExceeded) {
        await _leaveBlocked('이 질문의 답변 기회를 모두 사용했어요');
        return;
      }
      showErrorToast(context, err);
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
        iconAsset: 'assets/images/icons/load_answer.png',
      );
    } else if (_mode == _Mode.converting) {
      body = const ProcessingView(
        title: '답변을 텍스트로 변환 중이에요',
        iconAsset: 'assets/images/icons/load_answer.png',
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
        body = Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 28),
              const _VoiceTip(),
              // QA: 녹음 전·중·멈춤·다시 녹음 어느 상태에서도 마이크 버튼이 같은 자리에 있도록
              // 가운데 정렬 대신 위에서부터 고정 간격으로 둔다 (아래 버튼이 생겨도 움직이지 않게)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40),
                  child: _VoicePanel(
                    speech: _speech,
                    priorElapsed: _priorElapsed,
                    state: switch (_mode) {
                      _Mode.recording => _VoiceState.recording,
                      _Mode.voiceStopped => _VoiceState.stopped,
                      _ => _VoiceState.ready,
                    },
                    onTap: () => _mode == _Mode.recording
                        ? _stopRecording()
                        : _startRecording(),
                  ),
                ),
              ),
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
        _Mode.voiceReady || _Mode.recording => null,
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
            : AppNavBar(title: title, onBack: _confirmLeave),
        // 피그마 4-3 작성 완료 (763:19912): 임시 저장 / 제출하기 버튼은 키보드가 내려간 전체 화면일 때만 보인다.
        // 글을 쓰는 동안(키보드가 올라와 있을 때)은 버튼을 숨기고, 입력칸 밖을 누르거나 쓸어내리면 키보드가 내려가며 버튼이 나온다.
        body: _mode == _Mode.analyzing || _mode == _Mode.converting
            ? SafeArea(child: body)
            : GestureDetector(
                // 입력칸 밖을 누르면 키보드를 내린다
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Column(
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
    AppTextField(
      controller: _text,
      minLines: 7,
      maxLines: 16,
      maxLength: AppPolicy.maxAnswerLength,
      showLimitInCounter: false,
      onChanged: (_) => setState(() {}),
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
    AppTextField(
      controller: _text,
      hint: '질문에 대한 내 생각을 적어 주세요.\n기업 근거와 내 역할·행동을 연결하면 좋아요.',
      minLines: 6,
      maxLines: 16,
      maxLength: AppPolicy.maxAnswerLength,
      showLimitInCounter: false,
      onChanged: (_) => setState(() {}),
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
    return OutlinedBox(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.cardDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              size: 20,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '답변은 최대 ${AppPolicy.voiceMaxDuration.inMinutes}분 정도를 추천해요',
                  style: AppTypography.body2Strong.copyWith(
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '간결하고 핵심만 담아서 말하기',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textCaption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    final elapsed = priorElapsed + (speech?.elapsed ?? Duration.zero);
    final starting =
        recording &&
        (speech == null || speech!.status == SpeechStatus.initializing);
    final sub = AppTypography.body2.copyWith(color: AppColors.textCaption);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: recording ? '녹음 멈추기' : '녹음 시작하기',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: starting ? null : onTap,
            child: Container(
              width: 140,
              height: 140,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.fillMuted, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: recording ? AppColors.point : AppColors.cardDark,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: recording
                    ? const _Waveform()
                    : const Icon(
                        Icons.mic_rounded,
                        size: 40,
                        color: AppColors.white,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (state == _VoiceState.ready)
          Text(
            '버튼을 눌러\n답변을 시작하세요',
            textAlign: TextAlign.center,
            style: AppTypography.heading.copyWith(
              fontSize: 18,
              fontWeight: AppTypography.medium,
              color: AppColors.textStrong,
            ),
          )
        else ...[
          Semantics(
            liveRegion: true,
            child: Text(formatClock(elapsed), style: AppTypography.number(22)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recording ? (starting ? '준비하고 있어요' : '녹음 중이에요') : '녹음을 멈췄어요',
            style: AppTypography.heading.copyWith(
              fontSize: 18,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(recording ? '다시 터치하면 녹음을 멈춰요' : '다시 터치하면 녹음을 시작해요', style: sub),
        ],
      ],
    );
  }
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
    return ExcludeSemantics(
      child: SizedBox(
        height: 40,
        width: 56,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  width: 3,
                  height:
                      10 +
                      26 *
                          ([0.5, 0.9, 0.6, 1.0, 0.45][i] *
                              (0.5 +
                                  0.5 * (i.isEven ? _c.value : 1 - _c.value))),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
