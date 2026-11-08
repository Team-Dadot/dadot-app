import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 기기에만 남겨도 되는 값 (서버에 안 보내는 것).
/// - 작성 중인 답변 임시 저장 (S09)
/// - 홈에서 마지막으로 본 기업 (S05)
/// - 알림 권한을 이미 물어봤는지 (S07)
/// - Mock 모드 데이터
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _draftPrefix = 'draft.answer.';
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

  Future<void> remove(String key) => _prefs.remove(key);

  /// 로그아웃·탈퇴 시 기기에 남은 개인 데이터 삭제
  Future<void> clearUserData() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_draftPrefix) || k == _lastCompanyKey || k == _onboardingStepKey);
    for (final k in keys.toList()) {
      await _prefs.remove(k);
    }
  }
}
