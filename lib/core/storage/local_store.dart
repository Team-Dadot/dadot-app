import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../error/app_exception.dart';

/// 기기에만 남겨도 되는 값 (서버에 안 보내는 것).
/// - 작성 중인 답변 임시 저장 (S09)
/// - 홈에서 마지막으로 본 기업 (S05)
/// - 알림 권한을 이미 물어봤는지 (S07)
/// - Mock 모드 데이터
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;
  Future<void> _submissionWrites = Future<void>.value();

  /// 제출 기록 쓰기와 로그아웃 삭제가 역전되지 않도록 순서를 유지한다.
  Future<T> _serializeSubmissionWrite<T>(Future<T> Function() action) async {
    final previous = _submissionWrites;
    final done = Completer<void>();
    _submissionWrites = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  static const _draftPrefix = 'draft.answer.';
  static const pendingInterviewPrefix = 'submission.interview.';
  static const _lastCompanyKey = 'home.lastCompanyId';
  static const _askedPushKey = 'push.askedPermission';
  static const _onboardingStepKey = 'onboarding.lastStep';
  static const _tutorialSeenKey = 'tutorial.seen';

  // ---- 답변 임시 저장 ----
  String? readDraft(String questionId) => _prefs.getString('$_draftPrefix$questionId');

  Future<void> saveDraft(String questionId, String text) async {
    if (text.trim().isEmpty) {
      await _prefs.remove('$_draftPrefix$questionId');
    } else {
      await _prefs.setString('$_draftPrefix$questionId', text);
    }
  }

  Future<void> clearDraft(String questionId) => _prefs.remove('$_draftPrefix$questionId');

  /// 네트워크 전송 전에 제출 상태를 기기에 기록한다.
  Future<void> savePendingSubmission(String key, Map<String, dynamic> value) => _serializeSubmissionWrite(() async {
    final saved = await _prefs.setString(key, jsonEncode(value));
    if (!saved) {
      throw const AppException(AppErrorKind.unknown, message: '제출 상태를 기기에 저장하지 못했어요. 다시 시도해 주세요.');
    }
  });

  // ---- 홈 기본 기업 ----
  String? get lastCompanyId => _prefs.getString(_lastCompanyKey);
  Future<void> setLastCompanyId(String id) => _prefs.setString(_lastCompanyKey, id);

  // ---- 첫 실행 튜토리얼 (한 번 보면 다시 안 보여 준다) ----
  bool get tutorialSeen => _prefs.getBool(_tutorialSeenKey) ?? false;
  Future<void> markTutorialSeen() => _prefs.setBool(_tutorialSeenKey, true);

  // ---- 알림 권한 요청 여부 ----
  bool get hasAskedPushPermission => _prefs.getBool(_askedPushKey) ?? false;
  Future<void> markAskedPushPermission() => _prefs.setBool(_askedPushKey, true);

  // ---- 온보딩 마지막 단계 (이어하기) ----
  String? get lastOnboardingStep => _prefs.getString(_onboardingStepKey);
  Future<void> setLastOnboardingStep(String step) => _prefs.setString(_onboardingStepKey, step);

  // ---- 범용 JSON (Mock 서버 저장용) ----
  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) => _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _serializeSubmissionWrite(() async {
    final removed = await _prefs.remove(key);
    if (!removed) {
      throw const AppException(AppErrorKind.unknown, message: '제출 상태 정리를 완료하지 못했어요. 다시 확인해 주세요.');
    }
  });

  /// 로그아웃·탈퇴 시 기기에 남은 개인 데이터 삭제
  Future<void> clearUserData() => _serializeSubmissionWrite(() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_draftPrefix) || k.startsWith(pendingInterviewPrefix) || k == _lastCompanyKey || k == _onboardingStepKey);
    for (final k in keys.toList()) {
      await _prefs.remove(k);
    }
  });
}
