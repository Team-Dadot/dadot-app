/// 다닷 서버(https://api.dadot.store /v1) 구현. 경로는 core/network/api_paths.dart, 공통 계약은 api_client.dart.
///
/// 요청·응답 모양은 서버 코드(dadot-server, 2026-11-03)의 DTO 와 controller 검증 규칙으로 맞췄다.
/// (Swagger 는 springdoc 스키마 이름이 겹쳐 몇몇 응답이 다른 DTO 로 보인다 → 서버 코드가 기준)
/// 서버는 본문 필드·query 이름을 엄격하게 검사한다: 모르는 필드/쿼리를 보내면 400 INVALID_INPUT.
library;

import 'dart:async';

import 'package:flutter/widgets.dart' show StringCharacters;

import '../../core/config/app_policy.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_paths.dart';
import '../models/auth.dart';
import '../models/catalog.dart';
import '../models/home.dart';
import '../models/interview.dart';
import '../models/quiz.dart';
import '../models/records.dart';
import '../models/settings.dart';
import '../repositories/repositories.dart';

// ---------------------------------------------------------------- 읽기 도우미

Map<String, dynamic> _obj(dynamic data) => data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

Map<String, dynamic>? _map(dynamic v) => v is Map ? v.cast<String, dynamic>() : null;

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList() : const [];

/// 목록 응답: 페이지 {content:[..]} · {items:[..]} · [..]
List<Map<String, dynamic>> _content(dynamic data) {
  if (data is List) return _list(data);
  final m = _map(data);
  return _list(m?['content'] ?? m?['items']);
}

String? _str(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v == null || v is Map || v is List) continue;
    final s = v.toString();
    if (s.isNotEmpty) return s;
  }
  return null;
}

int? _int(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.round();
    if (v is String) {
      final n = num.tryParse(v);
      if (n != null) return n.round();
    }
  }
  return null;
}

bool? _bool(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v is bool) return v;
  }
  return null;
}

/// 정답률: 숫자 또는 {percent} / {correct,total} (ERD quiz_sets.accuracy_before_correct/_total). 분모 0 이면 null.
int? _percent(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.round();
    final o = _map(v);
    if (o == null) continue;
    final p = _int(o, ['percent']);
    if (p != null) return p;
    final total = _int(o, ['total', 'answeredCount', 'firstAnsweredCount']);
    final correct = _int(o, ['correct', 'correctCount', 'firstCorrectCount']);
    if (total != null && correct != null) return total == 0 ? null : (correct * 100 / total).round();
  }
  return null;
}

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// "2026-11-20" → 날짜만 (시간대 영향 없이)
DateTime? _day(dynamic v) {
  if (v is! String || v.length < 10) return null;
  final d = DateTime.tryParse(v.substring(0, 10));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// 서버 ID 는 JSON 정수. 앱은 문자열로 들고 있다가 보낼 때 정수로 바꾼다.
int _id(String id) {
  final n = int.tryParse(id);
  if (n == null) throw AppException(AppErrorKind.validation, message: '잘못된 항목이에요. 새로 고친 뒤 다시 시도해 주세요.', code: 'BAD_ID:$id');
  return n;
}

String _idem() => ApiClient.newIdempotencyKey();

List<String> _texts(dynamic v) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is String && e.trim().isNotEmpty)
        e.trim()
      else if (e is Map)
        ?_str(e.cast<String, dynamic>(), ['text', 'content', 'description', 'feedback', 'title']),
  ];
}

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

/// 평가 상태: SUCCEEDED 이고 점수가 있는 결과가 있을 때만 [EvaluationState.done]
EvaluationState _evaluationState(Map<String, dynamic> evaluation, [Map<String, dynamic>? attempt]) {
  final status = (_str(evaluation, ['status', 'evaluationStatus']) ??
          _str(_map(evaluation['task']), ['status']) ??
          _str(attempt, ['evaluationStatus']) ??
          '')
      .toUpperCase();
  final result = _map(evaluation['result']);
  final scored = result != null && _int(result, ['scorePercent', 'totalScore', 'score']) != null;
  if (_isFailed(status)) return EvaluationState.failed;
  if (scored && (status.isEmpty || status.contains('SUCCE') || status.contains('DONE') || status.contains('COMPLET'))) {
    return EvaluationState.done;
  }
  return EvaluationState.processing;
}

bool _isFailed(String status) => status.contains('FAIL') || status.contains('CANCEL') || status.contains('ERROR');

bool _isRunning(String status) =>
    status.contains('PENDING') || status.contains('QUEUE') || status.contains('PROCESS') || status.contains('RUNNING') ||
    status.contains('PROGRESS') || status.contains('ACCEPT') || status.contains('REQUEST');

/// 기업 이름 (퀴즈·면접 응답에는 기업 이름이 없을 수 있어 준비 기업 목록에서 채워 둔다)
final Map<String, String> _companyNames = {};

/// 마지막으로 로그인한 방식 (내 정보 응답에 로그인 방식이 없을 때 쓴다)
LoginMethod? _lastLoginMethod;

// ---------------------------------------------------------------- 모델 변환

Company _company(Map<String, dynamic> j) {
  final id = _str(j, ['companyId', 'id']) ?? '';
  final name = _str(j, ['companyName', 'name']) ?? '';
  if (id.isNotEmpty && name.isNotEmpty) _companyNames[id] = name;
  return Company(id: id, name: name, industry: _str(j, ['industry']));
}

/// 준비 기업 Item {company, job, interviewDate, version, quizToday, interviewToday, ...}
Preparation _preparation(Map<String, dynamic> j, [Map<String, int>? versions]) {
  final c = _company(_map(j['company']) ?? j);
  final job = _map(j['job']);
  final custom = job?['isCustom'] == true;
  final version = _int(j, ['version']);
  if (versions != null && version != null) versions[c.id] = version;
  return Preparation(
    companyId: c.id,
    companyName: c.name,
    industry: c.industry,
    jobId: job == null || custom ? null : _str(job, ['jobId', 'id']),
    jobName: _str(job, ['jobName', 'name', 'customName']),
    interviewDate: _day(j['interviewDate']),
  );
}

LoginMethod _loginMethodOf(Map<String, dynamic> j) {
  final raw = _str(j, ['loginProvider', 'provider', 'loginMethod', 'loginType', 'socialProvider', 'authProvider', 'signupType'])?.toUpperCase();
  if (raw != null) {
    if (raw.contains('KAKAO')) return LoginMethod.kakao;
    if (raw.contains('APPLE')) return LoginMethod.apple;
    if (raw.contains('GOOGLE')) return LoginMethod.google;
    if (raw.contains('EMAIL') || raw.contains('PASSWORD') || raw.contains('LOCAL')) return LoginMethod.email;
  }
  return _lastLoginMethod ?? LoginMethod.email;
}

/// GET /users/me (+ 필요하면 온보딩 완료 여부)
Future<AppUser> _fetchUser(ApiClient api, {String? bearer, bool? onboardingCompleted}) async {
  final raw = _obj(await api.get(ApiPaths.me, bearer: bearer));
  final j = {...raw, ...?_map(raw['user']), ...?_map(raw['profile'])};
  var done = _bool(j, ['onboardingCompleted']) ?? _bool(_map(raw['onboarding']), ['completed']) ?? onboardingCompleted;
  if (done == null) {
    try {
      done = _bool(_obj(await api.get(ApiPaths.meOnboarding, bearer: bearer)), ['completed']);
    } on AppException catch (e) {
      if (e.kind == AppErrorKind.unauthorized) rethrow;
    }
  }
  return AppUser(
    id: _str(j, ['userId', 'id']) ?? '',
    nickname: _str(j, ['nickname', 'name']) ?? '',
    email: _str(j, ['email']),
    loginMethod: _loginMethodOf(j),
    onboardingCompleted: done ?? false,
  );
}

Evidence _evidence(Map<String, dynamic> j) => Evidence(
      title: [_str(j, ['reportTitle', 'title']), _str(j, ['sectionTitle'])].whereType<String>().join(' · '),
      excerpt: _str(j, ['quote', 'quotation', 'excerpt', 'content']) ?? '',
      publishedAt: _str(j, ['publishedAt', 'disclosedAt', 'receiptDate']),
      period: _str(j, ['period']),
      url: _str(j, ['sourceUrl', 'url']),
      interpretation: _str(j, ['interpretation']),
    );

Evidence? _firstEvidence(dynamic v) {
  final list = v is Map ? [v.cast<String, dynamic>()] : _list(v);
  return list.isEmpty ? null : _evidence(list.first);
}

/// 퀴즈 문항 {itemId, questionId, position, question, options[{optionId, position, text}]}
QuizQuestion _quizQuestion(Map<String, dynamic> j, {String? id}) {
  final options = _list(j['options'])..sort((a, b) => (_int(a, ['position']) ?? 0).compareTo(_int(b, ['position']) ?? 0));
  final prompt = _str(j, ['question', 'prompt', 'text']) ?? '';
  return QuizQuestion(
    id: id ?? _str(j, ['itemId', 'id', 'questionId']) ?? '',
    order: _int(j, ['position', 'order']) ?? 1,
    tags: const [],
    prompt: prompt,
    title: prompt,
    choices: [
      for (final o in options) QuizChoice(id: _str(o, ['optionId', 'id']) ?? '', text: _str(o, ['text', 'content']) ?? ''),
    ],
  );
}

/// 아직 서버가 보여주지 않은 문항 자리 (퀴즈는 한 문항씩 내려온다)
QuizQuestion _placeholder(int order) => QuizQuestion(id: '', order: order, tags: const [], prompt: '', title: '', choices: const []);

CriterionKey _criterionKey(String raw) {
  final s = raw.toUpperCase();
  if (s.contains('COMPANY') || s.contains('기업')) return CriterionKey.companyInfo;
  if (s.contains('SPECIFIC') || s.contains('EXPERIENCE') || s.contains('구체') || s.contains('경험')) return CriterionKey.specificity;
  if (s.contains('LOGIC') || s.contains('STRUCT') || s.contains('논리') || s.contains('구성')) return CriterionKey.logic;
  if (s.contains('RESPON') || s.contains('응답')) return CriterionKey.responsiveness;
  return CriterionKey.clarity;
}

CriterionScore _criterion(Map<String, dynamic> j) => CriterionScore(
      key: _criterionKey(_str(j, ['code', 'key', 'criterion', 'criterionCode', 'name', 'label', 'title']) ?? ''),
      score: _int(j, ['score', 'points', 'value']) ?? 0,
      max: _int(j, ['maxScore', 'max', 'fullScore']) ?? 25,
    );

/// 평가 결과 (INT-08) → 피드백 화면 모델. [attempt] 는 시도 정보 (text, attemptNumber, submittedAt).
AnswerFeedback _feedback({
  required String attemptId,
  required Map<String, dynamic> evaluation,
  Map<String, dynamic>? attempt,
  Map<String, dynamic>? usage,
  String? questionId,
  String? text,
}) {
  final a = attempt ?? _map(evaluation['attempt']) ?? const <String, dynamic>{};
  final r = _map(evaluation['result']) ?? evaluation;
  final score = _int(r, ['scorePercent', 'totalScore', 'score']) ?? 0;
  final criteria = _list(r['criteria']).map(_criterion).toList();
  final met = criteria.where((c) => c.max > 0 && c.score * 100 / c.max >= 80).length;
  final complete = _bool(r, ['completionDecision']) ?? score >= AppPolicy.completeScore;
  final material = _list(r['relatedMaterials']).firstOrNull;
  final u = usage ?? _map(evaluation['usage']);
  return AnswerFeedback(
    answerId: attemptId,
    questionId: questionId ?? _str(a, ['questionId']) ?? _str(evaluation, ['questionId']) ?? '',
    content: text ?? _str(a, ['text', 'content']) ?? _str(evaluation, ['text', 'answerText']) ?? '',
    inputType: AnswerInputType.text,
    attempt: _int(a, ['attemptNumber']) ?? _int(evaluation, ['attemptNumber']) ?? 1,
    submittedAt: _date(a['submittedAt']) ?? _date(evaluation['submittedAt']) ?? DateTime.now(),
    score: score,
    criteria: criteria,
    metCount: met,
    status: complete ? AnswerStatus.complete : AnswerStatus.needsWork,
    goodPoint: _texts(r['strengths']).join('\n'),
    improvement: _texts(r['improvements']).join('\n'),
    retryRemaining: _int(u, ['questionRemaining']) ?? 0,
    relatedExperience: material == null
        ? null
        : RelatedExperience(
            title: _str(material, ['displayText', 'title']) ?? '',
            content: _str(material, ['excerpt']) ?? '',
            tip: _str(material, ['connectionReason']) ?? '',
          ),
    summary: _str(r, ['summaryFeedback']),
    overall: _str(r, ['overallFeedback']),
  );
}

// ---------------------------------------------------------------- 인증

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api);
  final ApiClient _api;

  /// 비밀번호 변경용 이메일 인증 (sendPasswordCode → changePassword)
  String? _passwordVerificationId;

  /// SIGN_UP_REQUIRED 로 온 소셜 가입의 제공자
  SocialProvider? _pendingProvider;

  @override
  Future<ServerAppConfig> fetchAppConfig() async => ServerAppConfig.fromJson(_obj(await _api.get(ApiPaths.appConfig)));

  @override
  Future<String?> prepareSocial(SocialProvider provider) async {
    if (provider != SocialProvider.apple) return null;
    return _str(_obj(await _api.post(ApiPaths.socialAppleChallenge, auth: false)), ['nonce']);
  }

  @override
  Future<AuthSession> signInWithSocial(SocialCredential credential) async {
    final path = switch (credential.provider) {
      SocialProvider.kakao => ApiPaths.socialKakao,
      SocialProvider.apple => ApiPaths.socialApple,
      SocialProvider.google => throw const AppException(AppErrorKind.validation, message: 'Google 로그인은 지원하지 않아요.'),
    };
    final data = _obj(await _api.post(path, body: credential.toJson(), auth: false, idempotencyKey: _idem()));
    if (_str(data, ['status']) == 'SIGN_UP_REQUIRED') {
      _pendingProvider = credential.provider;
      throw SocialSignUpRequired(registrationToken: _str(data, ['registrationToken']) ?? '', provider: credential.provider);
    }
    _lastLoginMethod = LoginMethod.fromWire(credential.provider.wire);
    return _session(data);
  }

  @override
  Future<AuthSession> completeSocialSignup({required String registrationToken, required List<String> termIds}) async {
    final data = _obj(await _api.post(
      ApiPaths.socialSignup,
      body: {'registrationToken': registrationToken, 'acceptedTermsIds': termIds.map(_id).toList()},
      auth: false,
      idempotencyKey: _idem(),
    ));
    if (_pendingProvider != null) _lastLoginMethod = LoginMethod.fromWire(_pendingProvider!.wire);
    return _session(data);
  }

  @override
  Future<String> sendEmailCode({required String email, required EmailCodePurpose purpose}) async {
    final data = _obj(await _api.post(
      ApiPaths.emailVerifications,
      body: {'email': email.trim(), 'purpose': purpose.wire},
      auth: purpose == EmailCodePurpose.passwordChange,
      idempotencyKey: _idem(),
    ));
    final id = _str(data, ['verificationId']);
    if (id == null) throw const AppException(AppErrorKind.server);
    return id;
  }

  @override
  Future<String> verifyEmailCode({required String verificationId, required String code}) async {
    final data = _obj(await _api.post(ApiPaths.emailVerify(verificationId), body: {'code': code.trim()}, auth: false, idempotencyKey: _idem()));
    final token = _str(data, ['verificationToken']);
    if (token == null) throw const AppException(AppErrorKind.server);
    return token;
  }

  @override
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    required String verificationToken,
    required List<String> termIds,
  }) async {
    final data = _obj(await _api.post(
      ApiPaths.signup,
      body: {
        'email': email.trim(),
        'password': password,
        'verificationToken': verificationToken,
        'acceptedTermsIds': termIds.map(_id).toList(),
      },
      auth: false,
      idempotencyKey: _idem(),
    ));
    _lastLoginMethod = LoginMethod.email;
    return _session(data);
  }

  @override
  Future<AuthSession> signInWithEmail({required String email, required String password}) async {
    final data = _obj(await _api.post(ApiPaths.login, body: {'email': email.trim(), 'password': password}, auth: false));
    _lastLoginMethod = LoginMethod.email;
    return _session(data);
  }

  @override
  Future<void> resetPassword({required String verificationToken, required String newPassword}) async {
    await _api.post(
      ApiPaths.passwordReset,
      body: {'verificationToken': verificationToken, 'newPassword': newPassword},
      auth: false,
      idempotencyKey: _idem(),
    );
  }

  /// 로그인 응답에는 사용자 정보가 없다 → 받은 토큰으로 내 정보를 바로 조회
  Future<AuthSession> _session(Map<String, dynamic> data) async {
    final token = _str(data, ['accessToken']);
    if (token == null) throw const AppException(AppErrorKind.server);
    final onboarded = _bool(data, ['onboardingCompleted']);
    AppUser user;
    try {
      user = await _fetchUser(_api, bearer: token, onboardingCompleted: onboarded);
    } on AppException catch (e) {
      if (e.kind == AppErrorKind.unauthorized) rethrow;
      user = AppUser(
        id: _str(data, ['userId']) ?? '',
        nickname: '',
        loginMethod: _lastLoginMethod ?? LoginMethod.email,
        onboardingCompleted: onboarded ?? false,
      );
    }
    return AuthSession(accessToken: token, refreshToken: null, user: user, isNewUser: !user.onboardingCompleted);
  }

  @override
  Future<AppUser> fetchMe() => _fetchUser(_api);

  @override
  Future<AppUser> updateProfile({required String nickname, required int avatarIndex}) async {
    await _api.patch(ApiPaths.meProfile, body: {'nickname': nickname.trim()});
    return _fetchUser(_api);
  }

  @override
  Future<void> sendPasswordCode() async {
    final me = await _fetchUser(_api);
    final email = me.email;
    if (email == null || email.isEmpty) {
      throw const AppException(AppErrorKind.validation, message: '이메일로 가입한 회원만 비밀번호를 바꿀 수 있어요.');
    }
    _passwordVerificationId = await sendEmailCode(email: email, purpose: EmailCodePurpose.passwordChange);
  }

  @override
  Future<void> changePassword({required String code, required String newPassword}) async {
    final id = _passwordVerificationId;
    if (id == null) throw const AppException(AppErrorKind.validation, message: '먼저 본인 확인 코드를 받아 주세요.');
    final token = await verifyEmailCode(verificationId: id, code: code);
    await _api.patch(ApiPaths.mePassword, body: {'verificationToken': token, 'newPassword': newPassword}, idempotencyKey: _idem());
    _passwordVerificationId = null;
  }

  @override
  Future<void> signOut() async {
    await _api.post(ApiPaths.logout);
  }

  @override
  Future<void> deleteAccount({String? password, SocialCredential? credential}) async {
    // Member.Delete.parse: {confirm:true, password} 또는 {confirm:true, socialCredential:{카카오 accessToken | Apple identityToken·authorizationCode·nonce}}
    final body = <String, dynamic>{
      'confirm': true,
      if (password != null) 'password': password else if (credential != null) 'socialCredential': credential.toJson(),
    };
    await _api.delete(ApiPaths.me, body: body, idempotencyKey: _idem());
    _lastLoginMethod = null;
  }
}

// ---------------------------------------------------------------- 카탈로그

class RemoteCatalogRepository implements CatalogRepository {
  RemoteCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Company>> fetchCompanies({String? query}) async {
    final q = query?.trim();
    final data = await _api.get(ApiPaths.companies, query: {'query': (q?.isEmpty ?? true) ? null : q, 'page': 0, 'size': 50});
    return _content(data).map(_company).where((c) => c.id.isNotEmpty).toList();
  }

  /// 직무 전체 (페이지 100개씩) → 자주 찾는 직무 + 분류별
  @override
  Future<JobCatalog> fetchJobCatalog() async {
    final jobs = <Map<String, dynamic>>[];
    var categories = <Map<String, dynamic>>[];
    for (var page = 0; page < 20; page++) {
      final data = _obj(await _api.get(ApiPaths.jobs, query: {'page': page, 'size': 100}));
      jobs.addAll(_content(data));
      if (page == 0) categories = _list(data['categories']);
      if (data['hasNext'] != true) break;
    }
    Job job(Map<String, dynamic> j) => Job(id: _str(j, ['jobId', 'id']) ?? '', name: _str(j, ['jobName', 'name']) ?? '');
    final cats = <String, String>{
      for (final c in categories) (_str(c, ['categoryId', 'id']) ?? ''): _str(c, ['categoryName', 'name']) ?? '',
    };
    for (final j in jobs) {
      cats.putIfAbsent(_str(j, ['categoryId']) ?? '', () => _str(j, ['categoryName']) ?? '기타');
    }
    return JobCatalog(
      popular: jobs.where((j) => j['popular'] == true).map(job).toList(),
      categories: [
        for (final e in cats.entries)
          if (jobs.any((j) => (_str(j, ['categoryId']) ?? '') == e.key))
            JobCategory(id: e.key, name: e.value, jobs: jobs.where((j) => (_str(j, ['categoryId']) ?? '') == e.key).map(job).toList()),
      ],
    );
  }
}

// ---------------------------------------------------------------- 준비 기업 · 경험 · 온보딩 · 알림

class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository(this._api);
  final ApiClient _api;

  /// 준비 기업 / 경험 version (PATCH 본문의 version 으로 보낸다 — 서버가 현재 버전과 비교)
  final Map<String, int> _prepVersions = {};
  final Map<String, int> _expVersions = {};

  /// 첫 설정이 끝났는지 (끝나면 다시 묻지 않는다)
  bool _onboarded = false;

  /// 첫 설정 중 고른 기업의 이름 · 업종 (서버 온보딩 임시 저장에는 기업 id 만 있다)
  final Map<String, Preparation> _known = {};

  /// 첫 설정이 끝난 뒤, 직무 없이 추가한 기업 (서버 준비 기업 추가에는 직무가 필요하다)
  List<Preparation> _pending = [];

  /// QA: 이전 계정의 "첫 설정 끝남" 캐시가 남아, 새로 가입한 계정의 STEP 2 저장이 첫 설정 API 대신
  /// 준비 기업 API 로 가서 "기업과 직무 등 필수 단계를 확인해 주세요"(ONBOARDING_INCOMPLETE)가 나던 문제
  @override
  void clearCache() {
    _onboarded = false;
    _known.clear();
    _pending = [];
    _prepVersions.clear();
    _expVersions.clear();
  }

  Future<List<Preparation>> _server() async {
    final data = await _api.get(ApiPaths.meCompanies, query: {'page': 0, 'size': 100});
    return _content(data).map((j) => _preparation(j, _prepVersions)).toList();
  }

  Future<List<Preparation>> _merged() async {
    final server = await _server();
    _pending = _pending.where((p) => !server.any((s) => s.companyId == p.companyId)).toList();
    return [...server, ..._pending];
  }

  Map<String, dynamic> _job(Preparation p) {
    final id = p.jobId == null ? null : int.tryParse(p.jobId!);
    return id != null ? {'jobId': id} : {'customName': p.jobName};
  }

  String? _date(Preparation p) => p.interviewDate == null ? null : formatIsoDate(p.interviewDate!);

  bool _sameJob(Preparation a, Preparation b) =>
      (a.jobId != null || b.jobId != null) ? a.jobId == b.jobId : (a.jobName ?? '') == (b.jobName ?? '');

  bool _changed(Preparation a, Preparation b) => !_sameJob(a, b) || a.interviewDate != b.interviewDate;

  // ---- 첫 설정 (서버 온보딩: GET/PATCH /users/me/onboarding → POST complete 가 준비 기업을 만든다)

  /// 첫 설정 중이면 서버 온보딩 상태, 끝났으면 null
  Future<Map<String, dynamic>?> _openOnboarding() async {
    if (_onboarded) return null;
    final ob = _obj(await _api.get(ApiPaths.meOnboarding));
    if (ob['completed'] == true) {
      _onboarded = true;
      return null;
    }
    return ob;
  }

  Set<String> _steps(Map<String, dynamic> ob) => (ob['completedSteps'] as List<dynamic>? ?? const []).map((e) => e.toString()).toSet();

  Future<Map<String, dynamic>> _step(Map<String, dynamic> ob, String step, Map<String, dynamic> payload) async => _obj(
        await _api.patch(ApiPaths.meOnboarding, body: {'step': step, 'version': _int(ob, ['version']) ?? 1, 'payload': payload}),
      );

  List<Preparation> _fromDraft(Map<String, dynamic> ob) {
    final ids = (ob['companyIds'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
    final assignments = {for (final a in _list(ob['assignments'])) _str(a, ['companyId']) ?? '': a};
    return [
      for (final id in ids)
        () {
          final a = assignments[id];
          final job = _map(a?['job']);
          final known = _known[id];
          return Preparation(
            companyId: id,
            companyName: known?.companyName ?? _companyNames[id] ?? '',
            industry: known?.industry,
            jobId: job == null || job['isCustom'] == true ? null : _str(job, ['jobId']),
            jobName: _str(job, ['jobName', 'customName']),
            interviewDate: _day(a?['interviewDate']),
          );
        }(),
    ];
  }

  /// 첫 설정 단계를 순서대로 서버에 저장 (기업 → 직무 → 면접일). 앞 단계가 바뀌면 서버가 뒤 단계를 지운다.
  Future<List<Preparation>> _saveOnboarding(Map<String, dynamic> start, List<Preparation> items) async {
    var ob = start;
    for (final p in items) {
      _known[p.companyId] = p;
    }
    final ids = items.map((p) => _id(p.companyId)).toList();
    final draftIds = (ob['companyIds'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList();
    final sameCompanies = ids.length == draftIds.length && [for (var i = 0; i < ids.length; i++) ids[i] == draftIds[i]].every((v) => v);
    if (!_steps(ob).contains('COMPANIES') || !sameCompanies) {
      ob = await _step(ob, 'COMPANIES', {'companyIds': ids});
    }
    if (items.isNotEmpty && items.every((p) => p.hasJob)) {
      final current = _fromDraft(ob);
      Preparation? cur(String id) => current.where((c) => c.companyId == id).firstOrNull;
      if (!_steps(ob).contains('JOBS') || items.any((p) => cur(p.companyId) == null || !_sameJob(cur(p.companyId)!, p))) {
        ob = await _step(ob, 'JOBS', {
          'assignments': [for (final p in items) {'companyId': _id(p.companyId), 'job': _job(p)}],
        });
      }
      final afterJobs = _fromDraft(ob);
      Preparation? cur2(String id) => afterJobs.where((c) => c.companyId == id).firstOrNull;
      if (!_steps(ob).contains('DATES') || items.any((p) => cur2(p.companyId)?.interviewDate != p.interviewDate)) {
        ob = await _step(ob, 'DATES', {
          'dates': [for (final p in items) {'companyId': _id(p.companyId), 'interviewDate': _date(p)}],
        });
      }
    }
    return _fromDraft(ob);
  }

  @override
  Future<List<Preparation>> fetchPreparations() async {
    final ob = await _openOnboarding();
    return ob != null ? _fromDraft(ob) : _merged();
  }

  @override
  Future<List<Preparation>> savePreparations(List<Preparation> items) async {
    if (items.length > AppPolicy.maxCompanies) {
      throw const AppException(AppErrorKind.validation, message: '준비 기업은 최대 ${AppPolicy.maxCompanies}개까지 고를 수 있어요.');
    }
    final ob = await _openOnboarding();
    if (ob != null) return _saveOnboarding(ob, items);

    final server = await _server();
    for (final s in server) {
      if (!items.any((p) => p.companyId == s.companyId)) await _api.delete(ApiPaths.meCompany(s.companyId));
    }
    final pending = <Preparation>[];
    for (final p in items) {
      final existing = server.where((s) => s.companyId == p.companyId).firstOrNull;
      if (existing == null) {
        if (p.hasJob) {
          await _add(p);
        } else {
          pending.add(p);
        }
      } else if (_changed(existing, p)) {
        await _patch(p);
      }
    }
    _pending = pending;
    return _merged();
  }

  Future<void> _add(Preparation p) async {
    await _api.post(
      ApiPaths.meCompanies,
      body: {'companyId': _id(p.companyId), 'job': _job(p), 'interviewDate': ?_date(p)},
      idempotencyKey: _idem(),
    );
  }

  /// PATCH /users/me/companies/{id}: {version(필수), job?, interviewDate?(null=일정 해제)}
  Future<void> _patch(Preparation p) async {
    if (!_prepVersions.containsKey(p.companyId)) await _server();
    await _api.patch(ApiPaths.meCompany(p.companyId), body: {
      'version': _prepVersions[p.companyId] ?? 1,
      if (p.hasJob) 'job': _job(p),
      'interviewDate': _date(p),
    });
  }

  @override
  Future<List<Preparation>> addPreparation(Preparation item) async {
    final ob = await _openOnboarding();
    if (ob != null) return _saveOnboarding(ob, [..._fromDraft(ob).where((p) => p.companyId != item.companyId), item]);
    if (item.hasJob) {
      await _add(item);
    } else {
      _pending = [..._pending.where((p) => p.companyId != item.companyId), item];
    }
    return _merged();
  }

  @override
  Future<List<Preparation>> updatePreparation(Preparation item) async {
    final ob = await _openOnboarding();
    if (ob != null) {
      return _saveOnboarding(ob, [for (final p in _fromDraft(ob)) p.companyId == item.companyId ? item : p]);
    }
    if (_pending.any((p) => p.companyId == item.companyId)) {
      _pending = _pending.where((p) => p.companyId != item.companyId).toList();
      return addPreparation(item);
    }
    await _patch(item);
    return _merged();
  }

  @override
  Future<List<Preparation>> removePreparation(String companyId) async {
    final ob = await _openOnboarding();
    if (ob != null) return _saveOnboarding(ob, _fromDraft(ob).where((p) => p.companyId != companyId).toList());
    if (_pending.any((p) => p.companyId == companyId)) {
      _pending = _pending.where((p) => p.companyId != companyId).toList();
    } else {
      await _api.delete(ApiPaths.meCompany(companyId));
    }
    return _merged();
  }

  /// 복습 기업 목록 중 지금 준비하지 않는 기업 (isActive=false)
  @override
  Future<List<PastPreparation>> fetchPastPreparations() async {
    final data = await _api.get(ApiPaths.reviewCompanies, query: {'page': 0, 'size': 100});
    return [
      for (final j in _content(data))
        if (j['isActive'] == false)
          () {
            final c = _company(_map(j['company']) ?? j);
            return PastPreparation(
              companyId: c.id,
              companyName: c.name,
              industry: c.industry,
              quizCount: _int(j, ['quizQuestionCount']) ?? 0,
              answerCount: _int(j, ['interviewQuestionCount']) ?? 0,
            );
          }(),
    ];
  }

  Experience _experience(Map<String, dynamic> j) {
    final id = _str(j, ['experienceId', 'id']) ?? '';
    final v = _int(j, ['version']);
    if (v != null) _expVersions[id] = v;
    return Experience(id: id, title: _str(j, ['title']) ?? '', content: _str(j, ['content']) ?? '');
  }

  @override
  Future<List<Experience>> fetchExperiences() async {
    final items = _content(await _api.get(ApiPaths.meExperiences, query: {'page': 0, 'size': 100}));
    // 목록에 본문이 없으면 상세를 같이 읽는다
    return Future.wait(items.map((j) async {
      if (j['content'] is String) return _experience(j);
      final id = _str(j, ['experienceId', 'id']) ?? '';
      return _experience(_obj(await _api.get(ApiPaths.meExperience(id))));
    }));
  }

  /// 서버는 경험을 자동으로 나누지 않는다 (명세: 자소서 자동 분리 범위 밖) → 쓴 글을 경험 한 건으로
  @override
  Future<List<ExperienceDraft>> splitExperiences(String text) async {
    final body = text.trim();
    final firstLine = body.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '내 경험');
    final chars = firstLine.characters;
    final title = chars.length > AppPolicy.experienceTitleMaxLength ? chars.take(AppPolicy.experienceTitleMaxLength).toString() : firstLine;
    return [ExperienceDraft(title: title, content: body)];
  }

  @override
  Future<List<Experience>> addExperiences(List<ExperienceDraft> items) async {
    for (final d in items) {
      await _api.post(ApiPaths.meExperiences, body: {'title': d.title.trim(), 'content': d.content.trim()}, idempotencyKey: _idem());
    }
    return fetchExperiences();
  }

  @override
  Future<Experience> updateExperience(Experience item) async {
    var version = _expVersions[item.id];
    if (version == null) {
      _experience(_obj(await _api.get(ApiPaths.meExperience(item.id))));
      version = _expVersions[item.id];
    }
    final data = await _api.patch(ApiPaths.meExperience(item.id), body: {
      'version': version ?? 1,
      'title': item.title.trim(),
      'content': item.content.trim(),
    });
    final j = _obj(data);
    return j.isEmpty ? item : _experience(j);
  }

  @override
  Future<void> deleteExperience(String id) async {
    await _api.delete(ApiPaths.meExperience(id));
    _expVersions.remove(id);
  }

  /// 남은 온보딩 단계(면접일 · 경험 · 알림 안내)를 채운 뒤 완료. 완료할 때 서버가 준비 기업을 만든다.
  @override
  Future<AppUser> completeOnboarding() async {
    var ob = await _openOnboarding();
    if (ob != null) {
      if (!_steps(ob).contains('DATES')) {
        final current = _fromDraft(ob);
        ob = await _step(ob, 'DATES', {
          'dates': [for (final p in current) {'companyId': _id(p.companyId), 'interviewDate': _date(p)}],
        });
      }
      if (!_steps(ob).contains('EXPERIENCE')) {
        final items = _content(await _api.get(ApiPaths.meExperiences, query: {'page': 0, 'size': 100}));
        ob = await _step(ob, 'EXPERIENCE', {
          'experienceIds': [for (final e in items) ?_int(e, ['experienceId', 'id'])],
        });
      }
      if (!_steps(ob).contains('NOTIFICATION_GUIDANCE')) {
        ob = await _step(ob, 'NOTIFICATION_GUIDANCE', {'guidanceCompleted': true});
      }
      await _api.post(ApiPaths.meOnboardingComplete, idempotencyKey: _idem());
    }
    _onboarded = true;
    final user = await _fetchUser(_api, onboardingCompleted: true);
    return user.onboardingCompleted ? user : user.copyWith(onboardingCompleted: true);
  }

  @override
  Future<NotificationSettings> fetchNotificationSettings() async =>
      NotificationSettings.fromJson(_obj(await _api.get(ApiPaths.meNotificationSettings)));

  @override
  Future<NotificationSettings> updateNotificationSettings(NotificationSettings settings) async {
    final version = settings.version ?? (await fetchNotificationSettings()).version ?? 1;
    final data = await _api.patch(ApiPaths.meNotificationSettings, body: {
      'version': version,
      'enabled': settings.enabled,
      'scheduledTime': '${settings.hour.toString().padLeft(2, '0')}:${settings.minute.toString().padLeft(2, '0')}',
      'timeZone': 'Asia/Seoul',
    });
    return NotificationSettings.fromJson(_obj(data));
  }

  /// 서버는 푸시 토큰을 받지 않는다 (명세: 학습 알림은 앱 로컬 예약)
  @override
  Future<void> registerPushToken({required String token, required String platform}) async {}
}

// ---------------------------------------------------------------- 홈

class RemoteHomeRepository implements HomeRepository {
  RemoteHomeRepository(this._api);
  final ApiClient _api;

  @override
  Future<HomeSummary> fetchHome() async {
    final results = await Future.wait([
      _fetchUser(_api),
      _api.get(ApiPaths.meCompanies, query: {'page': 0, 'size': 100}),
    ]);
    final user = results[0] as AppUser;
    final items = _content(results[1]);
    final companies = await Future.wait(items.map((j) async {
      final prep = _preparation(j);
      Map<String, dynamic> dash = const {};
      try {
        dash = _obj(await _api.get(ApiPaths.meDashboard, query: {'companyId': _id(prep.companyId)}));
      } on AppException catch (e) {
        if (e.kind == AppErrorKind.unauthorized) rethrow;
      }
      final acc = _map(dash['quizAccuracy']);
      final eval = _map(dash['interviewEvaluationSummary']);
      final quiz = _map(j['quizToday']);
      final interview = _map(j['interviewToday']);
      return CompanyHome(
        preparation: prep,
        quizCorrect: _int(acc, ['firstCorrectCount']) ?? 0,
        quizSolved: _int(acc, ['firstAnsweredCount']) ?? 0,
        interviewAnswered: _int(eval, ['evaluatedQuestionCount']) ?? 0,
        interviewCompleted: 0,
        quiz: TodayTask(done: _int(quiz, ['submittedCount']) ?? 0, total: _int(quiz, ['totalCount']) ?? AppPolicy.quizQuestionCount),
        interview: TodayTask(
          done: _int(interview, ['questionUsed']) ?? 0,
          total: _int(interview, ['questionLimit']) ?? AppPolicy.interviewDailyCount,
        ),
        focusMode: (_str(j, ['learningMode']) ?? '').toUpperCase().contains('FOCUS'),
        adBonusAvailable: false,
        dday: _int(j, ['daysUntilInterview']),
        interviewScorePercent: _int(eval, ['averageScorePercent']),
      );
    }));
    return HomeSummary(nickname: user.nickname, companies: companies);
  }
}

// ---------------------------------------------------------------- 퀴즈

/// 서버 퀴즈는 한 문항씩 내려온다 (진행 중 정답·해설 비공개).
/// 세트에는 지금 풀 문항만 실제 내용이 있고 나머지는 자리(isPlaceholder)다. 제출 뒤 [fetchTodaySet] 을 다시 부르면 다음 문항이 온다.
class RemoteQuizRepository implements QuizRepository {
  RemoteQuizRepository(this._api);
  final ApiClient _api;

  @override
  Future<QuizSet> fetchTodaySet(String companyId) async {
    final summary = _obj(await _api.post(ApiPaths.quizToday(companyId), idempotencyKey: _idem()));
    final setId = _str(summary, ['quizSetId', 'id']) ?? '';
    var total = _int(summary, ['totalCount']) ?? AppPolicy.quizQuestionCount;
    var submitted = _int(summary, ['submittedCount']) ?? 0;
    QuizQuestion? current;
    if (submitted < total) {
      final detail = _obj(await _api.get(ApiPaths.quizSet(setId)));
      total = _int(detail, ['totalCount']) ?? total;
      submitted = _int(detail, ['submittedCount']) ?? submitted;
      current = _current(detail, _int(detail, ['nextItemPosition']) ?? _int(summary, ['nextItemPosition']) ?? submitted + 1);
    }
    return QuizSet(
      id: setId,
      companyId: companyId,
      companyName: _companyNames[companyId] ?? '',
      questions: [
        for (var i = 0; i < total; i++) i == submitted && current != null ? current : _placeholder(i + 1),
      ],
      answers: [
        for (var i = 0; i < submitted; i++) const QuizAnswerResult(questionId: '', answer: '', correct: false, explanation: ''),
      ],
    );
  }

  // 서버 QuizPlay.Detail: {quizSetId, submittedCount, totalCount, nextItemPosition, currentItem{itemId, position, question, options}, savedAnswers}
  QuizQuestion? _current(Map<String, dynamic> d, int nextPosition) {
    for (final key in ['currentItem', 'currentQuestion', 'item', 'nextItem', 'question']) {
      final m = _map(d[key]);
      if (m != null && m['options'] is List) return _quizQuestion(m);
    }
    if (d['options'] is List) return _quizQuestion(d);
    final items = _list(d['items'] ?? d['questions']).where((m) => m['options'] is List).toList();
    final byPosition = items.where((m) => _int(m, ['position']) == nextPosition).firstOrNull;
    final open = items.where((m) => m['selectedOptionId'] == null && m['answered'] != true && m['submitted'] != true).firstOrNull;
    final pick = byPosition ?? open;
    return pick == null ? null : _quizQuestion(pick);
  }

  /// 진행 중에는 채점 결과를 주지 않는다 → 결과 화면에서 본다
  @override
  Future<QuizAnswerResult> submitAnswer({required String setId, required String questionId, required String answer}) async {
    await _api.post(
      ApiPaths.quizAnswers(setId),
      body: {'itemId': _id(questionId), 'selectedOptionId': _id(answer)},
      idempotencyKey: _idem(),
    );
    return QuizAnswerResult(questionId: questionId, answer: answer, correct: false, explanation: '');
  }

  // 서버 QuizPlay.ResultItem: {question, answerId, selectedOptionId, correctOptionId, isCorrect, explanation, evidence[], revisionNotice}
  @override
  Future<QuizResult> fetchResult(String setId) async {
    final d = _obj(await _api.get(ApiPaths.quizResult(setId)));
    final items = _list(d['items'] ?? d['results'] ?? d['answers'] ?? d['questions']).map(_resultItem).toList();
    final acc = _map(d['quizAccuracy']) ?? _map(d['accuracy']);
    // QuizPlay.Result: {quizSetId, company{companyId, companyName}, correctCount, totalCount, accuracyBefore{percent}, accuracyAfter, items}
    final company = _map(d['company']);
    final companyId = _str(d, ['companyId']) ?? _str(company, ['companyId']) ?? '';
    return QuizResult(
      setId: setId,
      companyId: companyId,
      companyName: _str(company, ['companyName']) ?? _str(d, ['companyName']) ?? _companyNames[companyId] ?? '',
      correctCount: _int(d, ['correctCount']) ?? items.where((i) => i.correct).length,
      total: _int(d, ['totalCount', 'total']) ?? items.length,
      accuracyBefore: _percent(d, ['accuracyBefore', 'previousAccuracyPercent', 'beforePercent']) ?? _percent(acc, ['before', 'beforePercent', 'previousPercent']),
      accuracyAfter: _percent(d, ['accuracyAfter', 'accuracyPercent', 'afterPercent']) ?? _percent(acc, ['after', 'percent', 'afterPercent']),
      items: items,
    );
  }

  QuizResultItem _resultItem(Map<String, dynamic> j) {
    final q = _map(j['question']) ?? j;
    final options = _list(q['options'])..sort((a, b) => (_int(a, ['position']) ?? 0).compareTo(_int(b, ['position']) ?? 0));
    String? label(String? optionId) {
      if (optionId == null) return null;
      final i = options.indexWhere((o) => _str(o, ['optionId', 'id']) == optionId);
      if (i < 0) return null;
      return '${_letters[i.clamp(0, _letters.length - 1)]}. ${_str(options[i], ['text']) ?? ''}';
    }

    final selected = _str(j, ['selectedOptionId']);
    final correct = _str(j, ['correctOptionId']);
    return QuizResultItem(
      questionId: _str(q, ['questionId', 'itemId', 'id']) ?? '',
      title: _str(q, ['question', 'title']) ?? '',
      correct: _bool(j, ['isCorrect', 'correct']) ?? (selected != null && selected == correct),
      explanation: _str(j, ['explanation']) ?? '',
      myAnswer: label(selected),
      correctAnswer: label(correct),
      evidence: _firstEvidence(j['evidence']),
    );
  }

  /// 오류 제보는 문의(구글폼)로 받는다 (명세: 문의는 구글폼 링크)
  @override
  Future<void> reportQuestion({required String questionId, required String reason}) async {
    throw const AppException(AppErrorKind.validation, message: '오류 제보는 마이 > 서비스 문의 및 오류제보에서 보내 주세요.');
  }
}

// ---------------------------------------------------------------- 면접

class RemoteInterviewRepository implements InterviewRepository {
  RemoteInterviewRepository(this._api);
  final ApiClient _api;

  /// 질문별 서버 초안 (text, version). 제출 시 draftVersion, 저장 시 expectedVersion 으로 쓴다.
  final Map<String, ({String text, int? version})> _drafts = {};

  static const _poll = Duration(milliseconds: 1500);

  @override
  Future<TodayInterview> fetchToday(String companyId) async {
    final entry = _obj(await _api.get(ApiPaths.interviewEntry(companyId)));
    final action = (_str(entry, ['nextAction']) ?? '').toUpperCase();
    final task = _map(entry['generationTask']);
    final taskStatus = (_str(task, ['status']) ?? '').toUpperCase();
    final remaining = _int(_map(entry['dailyUsage']), ['questionRemaining']);
    String? questionId = _str(entry, ['questionId']);

    // 서버 nextAction (InterviewGenerationService.entry): RESUME_DRAFT · ANSWER_QUESTION · WAIT_GENERATION · GENERATE · REVIEW
    switch (action) {
      case 'RESUME_DRAFT' || 'ANSWER_QUESTION':
        break;
      case 'WAIT_GENERATION':
        questionId = await _waitForQuestion(companyId, _str(task, ['taskId']));
      case 'GENERATE':
        if (task != null && _isRunning(taskStatus)) {
          questionId = await _waitForQuestion(companyId, _str(task, ['taskId']));
        } else {
          final accepted = _obj(await _api.post(ApiPaths.interviewQuestionTasks(companyId), idempotencyKey: _idem()));
          questionId = _str(accepted, ['questionId']) ?? await _waitForQuestion(companyId, _str(accepted, ['taskId']));
        }
      default: // REVIEW: 오늘 한도를 다 썼거나 준비 기업이 아님
        questionId = null;
    }
    if (remaining == 0 && questionId == null) return TodayInterview(companyId: companyId, questionIds: const [], doneIds: const []);
    return TodayInterview(companyId: companyId, questionIds: [?questionId], doneIds: const []);
  }

  /// 질문 생성 작업이 끝날 때까지 interview-entry?taskId= 를 조회 (최대 약 90초)
  Future<String> _waitForQuestion(String companyId, String? taskId) async {
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(_poll);
      final entry = _obj(await _api.get(ApiPaths.interviewEntry(companyId), query: {'taskId': taskId}));
      final task = _map(entry['generationTask']);
      final status = (_str(task, ['status']) ?? '').toUpperCase();
      if (_isFailed(status)) {
        throw AppException(AppErrorKind.server, message: _str(_map(task?['error']), ['message']) ?? '질문을 만들지 못했어요. 다시 시도해 주세요.');
      }
      final id = _str(task, ['questionId']) ?? _str(entry, ['questionId']);
      if (id != null && !_isRunning(status)) return id;
    }
    throw const AppException(AppErrorKind.timeout, message: '질문을 만드는 데 시간이 걸리고 있어요. 잠시 후 다시 시도해 주세요.');
  }

  @override
  Future<InterviewQuestion> fetchQuestion(String questionId) async {
    final d = _obj(await _api.get(ApiPaths.interviewQuestion(questionId)));
    final company = _map(d['company']);
    final companyId = _str(d, ['companyId']) ?? _str(company, ['companyId']) ?? '';
    final companyName = _str(d, ['companyName']) ?? _str(company, ['companyName']) ?? _companyNames[companyId] ?? '';
    // InterviewGeneration.Detail: {questionId, company, jobSnapshot, question, evidence, draft, latestAttempt, usage}
    final jobName = _str(_map(d['jobSnapshot']), ['jobName']) ?? _str(_map(d['job']), ['jobName']);
    final draft = _map(d['draft']);
    if (draft != null) _drafts[questionId] = (text: _str(draft, ['text']) ?? '', version: _int(draft, ['version']));
    return InterviewQuestion(
      id: _str(d, ['questionId', 'id']) ?? questionId,
      companyId: companyId,
      companyName: companyName,
      tags: [if (companyName.isNotEmpty) companyName, ?jobName],
      text: _str(d, ['question', 'questionText', 'text', 'content']) ?? '',
      evidence: _list(d['evidence'] ?? d['references'] ?? d['disclosures']).map(_evidence).toList(),
      retryRemaining: _int(_map(d['usage']), ['questionRemaining']),
      // 서버 usage.canSubmit · blockedReason 기준으로 "답변하기" 버튼 상태를 정한다
      canSubmit: _bool(_map(d['usage']), ['canSubmit']) ?? true,
      blockedReason: _str(_map(d['usage']), ['blockedReason']),
      latestAnswerId: _str(_map(d['latestAttempt']), ['attemptId']),
    );
  }

  /// 응답을 못 받은 답변 제출의 Idempotency-Key (질문별). 같은 글을 다시 보내면 같은 키를 쓴다.
  final Map<String, ({String key, String text})> _pendingSubmits = {};

  /// 답변 제출 (202 접수) → 평가가 끝날 때까지 조회 → 피드백
  @override
  Future<AnswerFeedback> submitAnswer({
    required String questionId,
    required String content,
    required AnswerInputType inputType,
  }) async {
    final version = _drafts[questionId]?.version;
    // 같은 질문·같은 글을 다시 보내면(응답이 중간에 끊겼던 경우) 같은 Idempotency-Key 를 써서
    // 서버가 새 시도를 만들지 않고 처음 접수한 시도를 돌려주게 한다
    final pending = _pendingSubmits[questionId];
    final key = pending != null && pending.text == content ? pending.key : _idem();
    _pendingSubmits[questionId] = (key: key, text: content);
    final Map<String, dynamic> accepted;
    try {
      accepted = _obj(await _api.post(
        ApiPaths.interviewAttempts(questionId),
        body: {'text': content, 'draftVersion': ?version},
        idempotencyKey: key,
      ));
    } on AppException catch (e) {
      // 네트워크·시간 초과면 접수됐을 수도 있으니 키를 남겨 둔다. 서버가 분명히 거절했으면 버린다.
      if (!e.isRetryable || e.code == 'IDEMPOTENCY_KEY_EXPIRED') _pendingSubmits.remove(questionId);
      rethrow;
    }
    _pendingSubmits.remove(questionId);
    final attemptId = _str(accepted, ['attemptId']);
    if (attemptId == null) throw const AppException(AppErrorKind.server);
    _drafts.remove(questionId);
    // 여기부터는 접수 완료. 평가 조회가 실패해도 제출 실패가 아니다 → AnswerAccepted (다시 제출하지 않고 결과만 다시 조회)
    final Map<String, dynamic> evaluation;
    try {
      evaluation = await _waitForEvaluation(attemptId);
    } on EvaluationFailed {
      rethrow;
    } on AppException catch (e) {
      if (e.kind == AppErrorKind.unauthorized) rethrow;
      throw AnswerAccepted(answerId: attemptId, cause: e);
    }
    return _feedback(
      attemptId: attemptId,
      evaluation: evaluation,
      attempt: accepted,
      usage: _map(accepted['usage']),
      questionId: questionId,
      text: content,
    );
  }

  /// 평가 결과가 나올 때까지 조회 (AI 평가는 수십 초 걸릴 수 있다)
  Future<Map<String, dynamic>> _waitForEvaluation(String attemptId, {int tries = 80}) async {
    for (var i = 0; i < tries; i++) {
      Map<String, dynamic>? v;
      try {
        v = _obj(await _api.get(ApiPaths.attemptEvaluation(attemptId)));
      } on AppException catch (e) {
        // 접수 직후에는 평가가 아직 없을 수 있다
        if (e.kind != AppErrorKind.notFound || i > 5) rethrow;
      }
      if (v != null) {
        final status = (_str(v, ['status', 'evaluationStatus']) ?? _str(_map(v['task']), ['status']) ?? '').toUpperCase();
        final result = _map(v['result']);
        if (_isFailed(status)) {
          throw EvaluationFailed(answerId: attemptId, message: _str(_map(v['error']), ['message']));
        }
        if (result != null && _int(result, ['scorePercent', 'totalScore', 'score']) != null) return v;
        if (status.isNotEmpty && !_isRunning(status) && result != null) return v;
      }
      await Future<void>.delayed(_poll);
    }
    throw const AppException(AppErrorKind.timeout, message: '평가가 늦어지고 있어요. 잠시 후 복습 탭에서 결과를 확인해 주세요.');
  }

  /// POST /interview-attempts/{id}/evaluation-tasks (202) → 다시 평가. 결과는 fetchFeedback 이 기다린다.
  @override
  Future<void> retryEvaluation(String answerId) async {
    await _api.post(ApiPaths.attemptEvaluationTasks(answerId), idempotencyKey: _idem());
  }

  @override
  Future<AnswerFeedback> fetchFeedback(String answerId) async {
    final results = await Future.wait([_api.get(ApiPaths.attempt(answerId)), _waitForEvaluation(answerId, tries: 40)]);
    return _feedback(attemptId: answerId, evaluation: _obj(results[1]), attempt: _obj(results[0]));
  }

  @override
  Future<void> saveDraft({required String questionId, required String content}) async {
    Future<void> put() async {
      // InterviewSubmission.SaveDraft: {text, version} 둘 다 필수 (처음 저장이면 version=null)
      final data = _obj(await _api.put(ApiPaths.interviewDraft(questionId), body: <String, dynamic>{
        'text': content,
        'version': _drafts[questionId]?.version,
      }));
      final draft = _map(data['draft']);
      _drafts[questionId] = (text: content, version: _int(draft, ['version']) ?? _drafts[questionId]?.version);
    }

    try {
      await put();
    } on AppException catch (e) {
      if (e.kind != AppErrorKind.conflict) rethrow;
      // 다른 기기에서 먼저 저장됨 → 최신 버전을 받아 한 번 더
      await fetchQuestion(questionId);
      await put();
    }
  }

  @override
  Future<String?> fetchDraft(String questionId) async {
    if (!_drafts.containsKey(questionId)) await fetchQuestion(questionId);
    final text = _drafts[questionId]?.text;
    return (text == null || text.isEmpty) ? null : text;
  }

  /// 광고 보고 질문 더 받기는 서버 범위 밖 (홈 adBonusAvailable=false 라 부르지 않는다)
  @override
  Future<void> unlockBonusQuestion(String companyId) async {
    throw const AppException(AppErrorKind.validation, message: '추가 질문은 아직 지원하지 않아요.');
  }
}

// ---------------------------------------------------------------- 복습

class RemoteRecordsRepository implements RecordsRepository {
  RemoteRecordsRepository(this._api) : _interview = RemoteInterviewRepository(_api);
  final ApiClient _api;
  final RemoteInterviewRepository _interview;

  /// 퀴즈 복습 정답 (다시 풀기 채점을 앱에서 한다 — 서버에 다시 풀기 API 가 없다)
  final Map<String, ({String? correctId, String explanation, Evidence? evidence})> _answers = {};

  // 서버 query: companyId · page · size (· filter). 모르는 query 는 400
  @override
  Future<List<QuizReviewItem>> fetchQuizReview({required String companyId}) async {
    final page = await _api.get(ApiPaths.reviewQuizzes, query: {'companyId': _id(companyId), 'page': 0, 'size': 50});
    return Future.wait(_content(page).map((j) async {
      final questionId = _str(j, ['questionId']) ?? '';
      final d = await _quizDetail(questionId, companyId);
      final q = _map(d['question']) ?? {'question': j['question']};
      return QuizReviewItem(
        id: questionId,
        companyId: companyId,
        question: _quizQuestion(q, id: questionId),
        wrong: !(_bool(j, ['isCorrect']) ?? _bool(d, ['isCorrect']) ?? true),
        explanation: _str(d, ['explanation']) ?? '',
        solvedAt: _date(j['lastAnsweredAt']) ?? _date(d['submittedAt']) ?? DateTime.now(),
        evidence: _firstEvidence(d['evidence']),
        correctChoiceId: _str(d, ['correctOptionId']),
      );
    }));
  }

  Future<Map<String, dynamic>> _quizDetail(String questionId, String? companyId) async {
    // 상세는 query 를 받지 않는다 (서버가 모르는 query 는 400)
    final d = _obj(await _api.get(ApiPaths.reviewQuiz(questionId)));
    _answers[questionId] = (
      correctId: _str(d, ['correctOptionId']),
      explanation: _str(d, ['explanation']) ?? '',
      evidence: _firstEvidence(d['evidence']),
    );
    return d;
  }

  @override
  Future<QuizAnswerResult> retryQuiz({required String itemId, required String answer}) async {
    if (!_answers.containsKey(itemId)) await _quizDetail(itemId, null);
    final a = _answers[itemId]!;
    return QuizAnswerResult(
      questionId: itemId,
      answer: answer,
      correct: a.correctId != null && a.correctId == answer,
      explanation: a.explanation,
      correctChoiceId: a.correctId,
      evidence: a.evidence,
    );
  }

  @override
  Future<List<InterviewRecord>> fetchInterviewRecords({required String companyId}) async {
    final page = await _api.get(ApiPaths.reviewInterviews, query: {'companyId': _id(companyId), 'page': 0, 'size': 100});
    return [
      for (final j in _content(page))
        () {
          final latest = _map(j['latestAttempt']) ?? _map(j['latestEvaluation']) ?? _map(j['representativeAttempt']);
          final score = _int(j, ['scorePercent', 'latestScorePercent', 'score']) ??
              _int(latest, ['scorePercent']) ??
              _int(_map(latest?['result']), ['scorePercent']);
          // InterviewReview.Question: {questionId, question, hasDraft, latestAttempt, latestScorePercent, completionDecision, questionUsed, ...}
          final attempts = _int(j, ['questionUsed', 'attemptCount']) ?? (latest == null ? 0 : 1);
          final decided = _bool(j, ['completionDecision']);
          // QA: 아직 제출 안 한 질문 · 다시 쓰다 저장만 해 둔 질문은 "작성 중" (이어서 답변하기)
          final status = latest == null || j['hasDraft'] == true
              ? AnswerStatus.draft
              : (decided ?? (score != null && score >= AppPolicy.completeScore))
                  ? AnswerStatus.complete
                  : AnswerStatus.needsWork;
          return InterviewRecord(
            questionId: _str(j, ['questionId', 'id']) ?? '',
            companyId: _str(j, ['companyId']) ?? companyId,
            questionText: _str(j, ['question', 'questionText', 'text']) ?? '',
            status: status,
            attempts: attempts,
            score: score,
            lastAt: _date(j['lastSubmittedAt'] ?? j['lastAnsweredAt'] ?? j['updatedAt'] ?? latest?['submittedAt']),
            retryRemaining: _int(j, ['questionRemaining']),
            createdAt: _date(j['createdAt']),
          );
        }(),
    ];
  }

  @override
  Future<InterviewRecordDetail> fetchInterviewRecord(String questionId) async {
    final results = await Future.wait([
      _interview.fetchQuestion(questionId),
      _api.get(ApiPaths.interviewAttempts(questionId), query: {'page': 0, 'size': 20}),
    ]);
    final question = results[0] as InterviewQuestion;
    final attempts = await Future.wait(_content(results[1]).map((a) async {
      final id = _str(a, ['attemptId', 'id']) ?? '';
      Map<String, dynamic> evaluation = const {};
      EvaluationState? state;
      try {
        evaluation = _obj(await _api.get(ApiPaths.attemptEvaluation(id)));
      } on AppException catch (e) {
        if (e.kind == AppErrorKind.unauthorized) rethrow;
        // QA: 조회 실패를 0점·보완필요로 바꾸지 않는다. 평가가 아직 없으면(404) 평가 중으로 본다.
        state = e.kind == AppErrorKind.notFound ? EvaluationState.processing : EvaluationState.unavailable;
      }
      final f = _feedback(attemptId: id, evaluation: evaluation, attempt: a, questionId: questionId);
      return f.copyWith(evaluation: state ?? _evaluationState(evaluation, a));
    }));
    attempts.sort((a, b) => a.attempt.compareTo(b.attempt));
    return InterviewRecordDetail(question: question, attempts: attempts);
  }

  @override
  Future<void> deleteInterviewRecord(String questionId) async {
    await _api.delete(ApiPaths.interviewQuestion(questionId));
  }

  @override
  Future<void> deleteAttempt(String answerId) async {
    await _api.delete(ApiPaths.attempt(answerId));
  }
}

// ---------------------------------------------------------------- 문의

/// 문의는 서버 API 가 아니라 구글폼으로 받는다 (GET /v1/app-config → inquiryFormUrl). 마이 화면이 폼을 연다.
class RemoteInquiryRepository implements InquiryRepository {
  RemoteInquiryRepository(this._api);
  // ignore: unused_field
  final ApiClient _api;

  @override
  Future<void> submit({
    required InquiryType type,
    required String content,
    required String appVersion,
    required String platform,
    String? companyId,
  }) async {
    throw const AppException(AppErrorKind.validation, message: '문의는 마이 > 서비스 문의 및 오류제보의 구글폼으로 보내 주세요.');
  }

  @override
  Future<List<Inquiry>> fetchHistory() async => const [];
}
