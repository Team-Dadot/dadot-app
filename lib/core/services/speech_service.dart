import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../config/app_policy.dart';

enum SpeechStatus {
  idle,
  initializing,

  /// 기기에 음성 인식 기능이 없음 (Android: Google 앱 꺼짐 등)
  unavailable,

  /// 마이크·음성 인식 권한 거부
  permissionDenied,
  listening,

  /// 녹음 끝 (사용자가 멈춤 또는 1분 도달)
  stopped,
}

/// 면접 답변 음성 입력 (S09). 확정 스펙: 음성은 1분 이내 답변만 지원.
///
/// 흐름: 기기 STT → 텍스트 → 사용자가 확인·수정 → 텍스트 답변 API 로 전송 (inputType: VOICE).
///
/// Android / iOS 차이:
/// - Android 는 말을 몇 초 멈추면 OS 가 인식을 끝낸다 → 1분 안이면 자동으로 다시 듣고 이어 붙인다.
/// - iOS 는 한 세션이 약 1분에서 끊긴다 → 앱 제한을 1분으로 둬서 그 안에서 끝나게 한다.
/// - 한국어 로케일 ID 가 Android "ko-KR", iOS "ko_KR" 이라 둘 다 찾는다.
///
/// 화면에서 쓰는 법: ListenableBuilder(listenable: speech, ...) 로 [text]·[status]·[remaining] 을 그린다.
class SpeechService extends ChangeNotifier {
  SpeechService({SpeechToText? engine, this.maxDuration = AppPolicy.voiceMaxDuration}) : _speech = engine ?? SpeechToText();

  final SpeechToText _speech;
  final Duration maxDuration;

  SpeechStatus _status = SpeechStatus.idle;
  SpeechStatus get status => _status;

  /// 1분이 지나 자동으로 멈췄는지 (화면에서 "1분이 지나 녹음을 마쳤어요" 안내)
  bool autoStopped = false;
  String? lastError;
  String? _localeId;
  bool _initialized = false;
  bool _wantListening = false;
  bool _disposed = false;

  String _committed = '';
  String _current = '';
  DateTime? _startedAt;
  Timer? _maxTimer;
  Timer? _ticker;

  bool get isListening => _status == SpeechStatus.listening;
  String get text => [_committed, _current].where((s) => s.isNotEmpty).join(' ');

  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  Duration get remaining {
    final r = maxDuration - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  Future<bool> initialize() async {
    if (_initialized) return _status != SpeechStatus.unavailable && _status != SpeechStatus.permissionDenied;
    _set(SpeechStatus.initializing);
    var available = false;
    try {
      available = await _speech.initialize(onStatus: _onStatus, onError: _onError, debugLogging: kDebugMode);
    } catch (e) {
      lastError = '$e';
    }
    _initialized = true;
    if (!available) {
      final hasPermission = await _speech.hasPermission;
      _set(hasPermission ? SpeechStatus.unavailable : SpeechStatus.permissionDenied);
      return false;
    }
    try {
      final locales = await _speech.locales();
      final ko = locales.map((l) => l.localeId).where((id) => id.toLowerCase().startsWith('ko')).toList();
      _localeId = ko.isNotEmpty ? ko.first : null;
    } catch (_) {
      _localeId = null;
    }
    _set(SpeechStatus.idle);
    return true;
  }

  /// 녹음 시작. [initialText] 가 있으면 그 뒤에 이어 붙인다.
  Future<void> start({String initialText = ''}) async {
    if (_wantListening) return;
    if (!await initialize()) return;
    _committed = initialText.trim();
    _current = '';
    lastError = null;
    autoStopped = false;
    _wantListening = true;
    _startedAt = DateTime.now();
    _maxTimer?.cancel();
    _maxTimer = Timer(maxDuration, () {
      autoStopped = true;
      stop();
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _notify());
    _set(SpeechStatus.listening);
    await _listenOnce();
  }

  Future<void> _listenOnce() async {
    final left = remaining;
    if (left < const Duration(seconds: 1)) return;
    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: _localeId,
        listenFor: left,
        pauseFor: const Duration(seconds: 5),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      lastError = '$e';
      await stop();
    }
  }

  Future<void> stop() async {
    if (!_wantListening) return;
    _wantListening = false;
    _maxTimer?.cancel();
    _ticker?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    _commitCurrent();
    _set(SpeechStatus.stopped);
  }

  Future<void> cancel() async {
    _wantListening = false;
    _maxTimer?.cancel();
    _ticker?.cancel();
    try {
      await _speech.cancel();
    } catch (_) {}
    _committed = '';
    _current = '';
    _set(SpeechStatus.idle);
  }

  void _onResult(SpeechRecognitionResult r) {
    _current = r.recognizedWords;
    _notify();
  }

  void _onStatus(String status) {
    final ended = status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus;
    if (ended && _wantListening) {
      _commitCurrent();
      // Android: 말 멈춤으로 끝난 세션 → 1분 안이면 이어서 듣기.
      // 바로 다시 시작하면 일부 기기에서 recognizer busy 오류가 나서 조금 늦춘다.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (_wantListening && !_disposed && !_speech.isListening) _listenOnce();
      });
    }
    _notify();
  }

  void _onError(SpeechRecognitionError e) {
    lastError = e.errorMsg;
    if (e.errorMsg.contains('permission')) {
      _wantListening = false;
      _maxTimer?.cancel();
      _ticker?.cancel();
      _set(SpeechStatus.permissionDenied);
      return;
    }
    // error_no_match / error_speech_timeout 는 말이 없었던 것 → onStatus 에서 다시 듣는다
    _notify();
  }

  void _commitCurrent() {
    final c = _current.trim();
    if (c.isNotEmpty) _committed = [_committed, c].where((s) => s.isNotEmpty).join(' ');
    _current = '';
  }

  void _set(SpeechStatus s) {
    _status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }


  @override
  void dispose() {
    _disposed = true;
    _wantListening = false;
    _maxTimer?.cancel();
    _ticker?.cancel();
    _speech.cancel();
    super.dispose();
  }
}
