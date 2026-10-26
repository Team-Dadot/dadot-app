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

enum _Mode { writing, voiceReady, recording, voiceReview, analyzing }

/// 피그마 4-3 답변 작성(텍스트) · 4-4 말로 답하기(녹음 전 → 녹음 중 → 텍스트 변환) · 4-5 답변 분석 중
/// - 쓰는 중인 답변은 기기에 자동 임시 저장, "임시저장" 을 누르면 서버에도 저장 (복습 탭 "작성 중")
/// - 말로 답하면 기기 STT 로 글자로 바꾼 뒤 직접 고쳐서 제출
class AnswerScreen extends ConsumerStatefulWidget {
  const AnswerScreen({super.key, required this.questionId, this.startWithVoice = false});

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

  @override
  void initState() {
    super.initState();
    _store = ref.read(localStoreProvider);
    _text = TextEditingController(text: _store.readDraft(widget.questionId) ?? '');
    _text.addListener(_scheduleDraftSave);
    if (_text.text.isEmpty) _loadServerDraft();
    if (widget.startWithVoice) _mode = _Mode.voiceReady;
  }

  Future<void> _loadServerDraft() async {
    try {
      final draft = await ref.read(interviewRepositoryProvider).fetchDraft(widget.questionId);
      if (mounted && draft != null && _text.text.isEmpty) setState(() => _text.text = draft);
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

  // ---------------------------------------------------------------- 말로 답하기

  Future<void> _startRecording({bool restart = false}) async {
    FocusScope.of(context).unfocus();
    final speech = _speech ??= SpeechService()..addListener(_onSpeech);
    if (restart) {
      await speech.cancel();
      // 다시 녹음: 방금 말로 바꾼 내용은 지우고 새로 녹음
      if (_mode == _Mode.voiceReview) _text.clear();
    }
    setState(() => _mode = _Mode.recording);
    await speech.start();
    if (!mounted) return;
    if (speech.status == SpeechStatus.permissionDenied) {
      setState(() => _mode = _Mode.voiceReady);
      showToast(context, '마이크 권한이 필요해요. 휴대폰 설정 > 앱 > Dadot에서 마이크·음성 인식을 켜 주세요.');
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
    setState(() {
      // 말한 내용이 있으면 "내 답변" 확인·수정 단계로
      _mode = spoken.isEmpty ? _Mode.voiceReady : _Mode.voiceReview;
      if (spoken.isNotEmpty) {
        _usedVoice = true;
        final joined = [_text.text.trim(), spoken].where((s) => s.isNotEmpty).join('\n');
        _text.value = TextEditingValue(text: joined, selection: TextSelection.collapsed(offset: joined.length));
      }
    });
    if (spoken.isEmpty) showToast(context, '말한 내용을 알아듣지 못했어요. 다시 녹음해 주세요.');
  }

  void _onSpeech() {
    final s = _speech;
    if (s == null || !mounted) return;
    if (s.status == SpeechStatus.stopped && s.autoStopped && _mode == _Mode.recording) {
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
      await ref.read(interviewRepositoryProvider).saveDraft(questionId: widget.questionId, content: _text.text);
      ref.invalidate(interviewRecordsProvider);
      if (!mounted) return;
      showToast(context, '임시저장했어요. 복습 탭에서 이어 쓸 수 있어요.');
      if (leave) {
        _leaving = true;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _submit() async {
    if (_length < AppPolicy.minAnswerLength) {
      showToast(context, '${AppPolicy.minAnswerLength}자 이상 써 주세요. (지금 $_length자)');
      return;
    }
    FocusScope.of(context).unfocus();
    _saveLocalDraft();
    setState(() => _mode = _Mode.analyzing);
    try {
      final feedback = await ref.read(interviewRepositoryProvider).submitAnswer(
            questionId: widget.questionId,
            content: _text.text.trim(),
            inputType: _usedVoice ? AnswerInputType.voice : AnswerInputType.text,
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _mode = _Mode.writing);
      final err = asAppException(e);
      showErrorToast(context, err);
      if (err.kind == AppErrorKind.feedbackQuotaExceeded) await _saveDraft();
    }
  }

  /// 4-E6 작성 중 나가기 확인 (피그마 프레임이 비어 있어 확인 팝업으로)
  Future<void> _confirmLeave() async {
    if (_mode == _Mode.recording) {
      await _stopRecording();
      return;
    }
    if (_mode == _Mode.analyzing) return;
    // 말로 답하기 화면에서 뒤로 → 답변 작성 화면 (질문 화면에서 바로 왔으면 그대로 나간다)
    if ((_mode == _Mode.voiceReady || _mode == _Mode.voiceReview) && !(widget.startWithVoice && _text.text.trim().isEmpty)) {
      setState(() => _mode = _Mode.writing);
      return;
    }
    if (_text.text.trim().isEmpty) {
      _leaving = true;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final save = await showConfirmDialog(
      context,
      title: '작성 중인 답변이 있어요',
      message: '임시저장하고 나가면 복습 탭에서 이어 쓸 수 있어요.',
      confirmLabel: '임시저장하고 나가기',
      cancelLabel: '계속 쓰기',
    );
    if (save && mounted) await _saveDraft(leave: true);
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(interviewQuestionProvider(widget.questionId));
    final voice = _mode == _Mode.voiceReady || _mode == _Mode.recording || _mode == _Mode.voiceReview;
    final title = voice ? '말로 답하기' : '답변 작성';

    Widget body;
    List<Widget>? bottom;
    if (_mode == _Mode.analyzing) {
      body = const ProcessingView(title: '답변을 분석하고 있어요', iconAsset: 'assets/images/icons/load_answer.png');
    } else {
      final header = q.when(
        loading: () => const SizedBox(height: 80, child: LoadingView()),
        error: (e, _) => ErrorView(error: e, compact: true, onRetry: () => ref.invalidate(interviewQuestionProvider(widget.questionId))),
        data: (q) => QuestionCard(question: q),
      );
      if (_mode == _Mode.voiceReady || _mode == _Mode.recording) {
        body = Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Center(
                  child: _VoicePanel(
                    speech: _speech,
                    recording: _mode == _Mode.recording,
                    onTap: () => _mode == _Mode.recording ? _stopRecording() : _startRecording(),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        );
      } else {
        body = ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xl),
          children: [
            header,
            const SizedBox(height: 28),
            if (_mode == _Mode.voiceReview) ..._voiceReviewPanel() else ..._writingPanel(),
          ],
        );
      }
      bottom = switch (_mode) {
        _Mode.voiceReady || _Mode.recording => null,
        _Mode.voiceReview => [
            AppButton(label: '다시 녹음하기', variant: AppButtonVariant.secondary, onPressed: () => _startRecording(restart: true)),
            AppButton(label: '답변 제출하기', onPressed: _length == 0 ? null : _submit),
          ],
        _ => _length == 0
            ? null
            : [
                AppButton(label: '임시 저장', variant: AppButtonVariant.secondary, loading: _savingDraft, onPressed: _saveDraft),
                AppButton(label: '제출하기', onPressed: _submit),
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
        appBar: _mode == _Mode.analyzing ? null : AppNavBar(title: title, onBack: _confirmLeave),
        body: _mode == _Mode.analyzing ? SafeArea(child: body) : body,
        bottomNavigationBar: bottom == null ? null : BottomCta(children: bottom),
      ),
    );
  }

  /// 4-4 텍스트 변환: "내 답변" + 흰 카드 (눌러서 고칠 수 있음)
  List<Widget> _voiceReviewPanel() => [
        Row(
          children: [
            Expanded(child: Text('내 답변', style: AppTypography.body2Medium.copyWith(color: AppColors.textPlaceholder))),
            Text('${formatClock(_speech?.elapsed ?? Duration.zero)} 녹음', style: AppTypography.caption),
          ],
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
        const SizedBox(height: AppSpacing.sm),
        Text('잘못 바뀐 글자는 눌러서 바로 고칠 수 있어요.', style: AppTypography.caption),
      ];

  /// 4-3 답변 작성: "말로 답하기" 카드 + 흰 입력 카드
  List<Widget> _writingPanel() => [
        Semantics(
          button: true,
          label: '말로 답하기. 실제 면접처럼 소리 내어 연습해요',
          excludeSemantics: true,
          child: Material(
            color: AppColors.fillSecondary,
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
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.mic_rounded, size: 22, color: AppColors.white),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('말로 답하기', style: AppTypography.body2Strong),
                          const SizedBox(height: 2),
                          Text('실제 면접처럼 소리내어 연습해요', style: AppTypography.micro.copyWith(color: AppColors.textPlaceholder)),
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
      ];
}

/// 4-4 말로 답하기 · 녹음 전 / 녹음 중: 큰 원 버튼 + 안내
class _VoicePanel extends StatelessWidget {
  const _VoicePanel({required this.speech, required this.recording, required this.onTap});

  final SpeechService? speech;
  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final elapsed = speech?.elapsed ?? Duration.zero;
    final starting = recording && (speech == null || speech!.status == SpeechStatus.initializing);
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
              width: AppSizes.micButton,
              height: AppSizes.micButton,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: const Color(0xFFDADADA), width: 2),
              ),
              child: Container(
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: recording ? const _Waveform() : const Icon(Icons.mic_rounded, size: 44, color: AppColors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (recording) ...[
          Semantics(liveRegion: true, child: Text(formatClock(elapsed), style: AppTypography.title2.copyWith(fontWeight: AppTypography.semibold))),
          const SizedBox(height: AppSpacing.xs),
          Text(starting ? '준비하고 있어요' : '녹음 중이에요', style: AppTypography.subheading),
          const SizedBox(height: AppSpacing.xxs),
          Text('다시 터치하면 녹음을 멈춰요', style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
        ] else
          Text('버튼을 눌러\n답변을 시작하세요', textAlign: TextAlign.center, style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium)),
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

class _WaveformState extends State<_Waveform> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

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
                  height: 10 + 26 * ([0.5, 0.9, 0.6, 1.0, 0.45][i] * (0.5 + 0.5 * (i.isEven ? _c.value : 1 - _c.value))),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(2)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
