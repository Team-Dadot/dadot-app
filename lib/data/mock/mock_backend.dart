import 'dart:math' as math;

import 'package:flutter/widgets.dart' show StringCharacters;

import '../../core/config/app_policy.dart';
import '../../core/error/app_exception.dart';
import '../../core/storage/local_store.dart';
import '../models/auth.dart';
import '../models/catalog.dart';
import '../models/home.dart';
import '../models/interview.dart';
import '../models/quiz.dart';
import '../models/records.dart';
import '../models/settings.dart';
import 'mock_data.dart';

/// 앱 안에서 도는 가짜 서버.
/// - 백엔드 규칙(채점, 정답률, D-day·집중 모드, 재도전 횟수, 복습 목록)을 흉내 낸다.
/// - 상태는 SharedPreferences 에 저장돼서 앱을 껐다 켜도 이어진다.
/// - [now] 를 바꿔 끼우면 날짜가 바뀌는 상황(자정 초기화)을 테스트할 수 있다.
class MockBackend {
  MockBackend({
    LocalStore? store,
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? now,
  })  : _store = store,
        _now = now ?? DateTime.now {
    _load();
  }

  static const storageKey = 'mock.backend.v3'; // v3: 퀴즈 주관식 제거 (예전 세트에 주관식 id 가 남아 있어 초기화)

  final LocalStore? _store;
  final Duration latency;
  final DateTime Function() _now;

  // ---------------------------------------------------------------- 상태
  AppUser? _user;
  bool _loggedIn = false;
  List<Preparation> _preps = [];

  /// 준비 기업에서 뺀 기업 (6-2 준비했던 기업)
  List<PastPreparation> _past = [];
  List<Experience> _experiences = [];
  NotificationSettings _notification = const NotificationSettings(enabled: true, hour: 9, minute: 0);
  String _day = '';

  /// companyId_day → 오늘 퀴즈 세트
  final Map<String, _SetState> _sets = {};

  /// companyId → [맞힌 수, 푼 수] (누적)
  final Map<String, List<int>> _stats = {};

  /// questionId → 퀴즈 복습 항목 (마지막 결과)
  final Map<String, QuizReviewItem> _review = {};

  /// answerId → 피드백
  final Map<String, AnswerFeedback> _answers = {};

  /// questionId → 임시저장한 답변
  final Map<String, String> _drafts = {};

  /// companyId → 오늘의 면접 질문 id
  final Map<String, List<String>> _todayQuestions = {};

  /// 오늘 답한 횟수 (questionId → 횟수)
  final Map<String, int> _attemptsToday = {};

  /// 오늘 광고 보너스를 쓴 기업
  final Set<String> _bonusUsed = {};
  final List<Inquiry> _inquiries = [];
  final List<Map<String, dynamic>> reports = [];
  int _seq = 0;

  // ---------------------------------------------------------------- 공통

  Future<T> run<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    _rollDay();
    return body();
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  int get _dayIndex {
    final n = _now();
    return DateTime.utc(n.year, n.month, n.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  /// 날짜가 바뀌면 오늘 세트·질문·횟수 초기화 (서버 자정 배치 흉내)
  void _rollDay() {
    final today = _dayKey(_now());
    if (_day == today) return;
    _day = today;
    _todayQuestions.clear();
    _attemptsToday.clear();
    _bonusUsed.clear();
    _sets.removeWhere((id, _) => !id.endsWith('_$today'));
    _persist();
  }

  AppUser _requireUser() {
    final u = _user;
    if (u == null || !_loggedIn) throw const AppException(AppErrorKind.unauthorized, statusCode: 401);
    return u;
  }

  String _nextId(String prefix) => '$prefix-${++_seq}';

  static String companyIdOf(String id) => id.substring(0, id.lastIndexOf('-'));

  static AppException _invalid(String message) => AppException(AppErrorKind.validation, message: message, code: 'VALIDATION_ERROR', statusCode: 422);

  Preparation _requirePrep(String companyId) {
    _requireUser();
    final p = _preps.where((p) => p.companyId == companyId).firstOrNull;
    if (p == null) throw const AppException(AppErrorKind.notFound, statusCode: 404, message: '준비 기업에서 빠진 기업이에요.');
    return p;
  }

  // ---------------------------------------------------------------- 인증

  AuthSession signIn(SocialCredential credential) {
    final isNew = _user == null;
    _user ??= AppUser(
      id: 'mock-user',
      nickname: '지민',
      loginMethod: LoginMethod.fromWire(credential.provider.wire),
      onboardingCompleted: false,
    );
    _loggedIn = true;
    _persist();
    return AuthSession(
      accessToken: 'mock-access-${_now().millisecondsSinceEpoch}',
      refreshToken: 'mock-refresh',
      user: _user!,
      isNewUser: isNew || !_user!.onboardingCompleted,
    );
  }

  /// 이메일 가입. Mock 은 같은 이메일이면 그 계정으로 로그인한다.
  AuthSession signUpEmail({required String email, required String password}) {
    if (!AppPolicy.isValidEmail(email)) throw _invalid('올바르지 않은 이메일 형식입니다');
    if (!AppPolicy.isValidPassword(password)) throw _invalid(AppPolicy.passwordRule);
    final isNew = _user == null || _user!.email != email.trim();
    if (isNew) {
      _user = AppUser(id: 'mock-user', nickname: email.split('@').first, email: email.trim(), loginMethod: LoginMethod.email, onboardingCompleted: false);
      _preps = [];
      _past = [];
    }
    _loggedIn = true;
    _persist();
    return AuthSession(
      accessToken: 'mock-access-${_now().millisecondsSinceEpoch}',
      refreshToken: 'mock-refresh',
      user: _user!,
      isNewUser: isNew || !_user!.onboardingCompleted,
    );
  }

  /// 이메일 로그인. Mock 은 가입한 이메일이면 비밀번호와 상관없이 들어간다.
  AuthSession signInEmail({required String email, required String password}) {
    final u = _user;
    if (u == null || u.email != email.trim() || password.isEmpty) {
      throw const AppException(AppErrorKind.unauthorized, statusCode: 401, message: '이메일 또는 비밀번호를 확인해 주세요.');
    }
    _loggedIn = true;
    _persist();
    return AuthSession(accessToken: 'mock-access-${_now().millisecondsSinceEpoch}', refreshToken: 'mock-refresh', user: u, isNewUser: !u.onboardingCompleted);
  }

  AppUser me() => _requireUser();

  AppUser updateProfile({required String nickname, required int avatarIndex}) {
    final name = nickname.trim();
    if (name.isEmpty || name.characters.length > 12) throw _invalid('닉네임은 1~12자로 써 주세요.');
    _user = _requireUser().copyWith(nickname: name, avatarIndex: avatarIndex);
    _persist();
    return _user!;
  }

  void sendPasswordCode() {
    final u = _requireUser();
    if (u.loginMethod != LoginMethod.email) throw _invalid('이메일·비밀번호로 가입한 회원만 비밀번호를 바꿀 수 있어요.');
  }

  void changePassword({required String code, required String newPassword}) {
    sendPasswordCode();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) throw _invalid('본인 확인 코드 6자리를 확인해 주세요.');
    if (!AppPolicy.isValidPassword(newPassword)) throw _invalid(AppPolicy.passwordRule);
  }

  void signOut() {
    _loggedIn = false;
    _persist();
  }

  void deleteAccount() {
    _requireUser();
    _user = null;
    _loggedIn = false;
    _preps = [];
    _past = [];
    _experiences = [];
    _sets.clear();
    _stats.clear();
    _review.clear();
    _answers.clear();
    _drafts.clear();
    _todayQuestions.clear();
    _attemptsToday.clear();
    _bonusUsed.clear();
    _inquiries.clear();
    _persist();
  }

  // ---------------------------------------------------------------- 카탈로그

  List<Company> companies({String? query}) {
    final q = query?.trim() ?? '';
    if (q.isEmpty) return MockData.companies;
    return MockData.companies.where((c) => c.name.contains(q) || (c.industry ?? '').contains(q)).toList();
  }

  JobCatalog jobCatalog() => MockData.jobCatalog;

  // ---------------------------------------------------------------- 준비 기업

  List<Preparation> preparations() {
    _requireUser();
    return List.unmodifiable(_preps);
  }

  List<Preparation> savePreparations(List<Preparation> items) {
    _requireUser();
    if (items.length > AppPolicy.maxCompanies) throw _invalid('준비 기업은 최대 ${AppPolicy.maxCompanies}개까지 고를 수 있어요.');
    _preps = List.of(items);
    _persist();
    return preparations();
  }

  List<Preparation> addPreparation(Preparation item) {
    _requireUser();
    if (_preps.any((p) => p.companyId == item.companyId)) throw _invalid('이미 준비 중인 기업이에요.');
    if (_preps.length >= AppPolicy.maxCompanies) throw _invalid('준비 기업은 최대 ${AppPolicy.maxCompanies}개까지예요. 다른 기업을 빼고 추가해 주세요.');
    _preps = [..._preps, item];
    _past = _past.where((p) => p.companyId != item.companyId).toList();
    _persist();
    return preparations();
  }

  List<Preparation> updatePreparation(Preparation item) {
    _requirePrep(item.companyId);
    _preps = [for (final p in _preps) p.companyId == item.companyId ? item : p];
    _persist();
    return preparations();
  }

  List<Preparation> removePreparation(String companyId) {
    final removed = _requirePrep(companyId);
    _preps = _preps.where((p) => p.companyId != companyId).toList();
    _past = [
      PastPreparation(
        companyId: removed.companyId,
        companyName: removed.companyName,
        industry: removed.industry,
        quizCount: _stats[companyId]?.elementAtOrNull(1) ?? 0,
        answerCount: _answers.values.where((a) => companyIdOf(a.questionId) == companyId).length,
      ),
      ..._past.where((p) => p.companyId != companyId),
    ];
    _persist();
    return preparations();
  }

  List<PastPreparation> pastPreparations() {
    _requireUser();
    return List.unmodifiable(_past);
  }

  // ---------------------------------------------------------------- 내 경험

  List<Experience> experiences() {
    _requireUser();
    return List.unmodifiable(_experiences);
  }

  /// AI 경험 나누기 흉내: 줄머리 기호(-, •, 숫자.)나 빈 줄로 나눈다.
  List<ExperienceDraft> splitExperiences(String text) {
    _requireUser();
    final cleaned = text.replaceAll(RegExp(r'예\)\s*'), '').trim();
    if (cleaned.isEmpty) throw _invalid('경험을 적어 주세요.');
    final lines = cleaned.split(RegExp(r'\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final marker = RegExp(r'^([-•*·]|\d+[.)])\s*');
    final hasMarkers = lines.where((l) => marker.hasMatch(l)).length >= 2;
    final List<String> parts;
    if (hasMarkers) {
      parts = [];
      for (final l in lines) {
        if (marker.hasMatch(l) || parts.isEmpty) {
          parts.add(l.replaceFirst(marker, ''));
        } else {
          parts[parts.length - 1] = '${parts.last} $l';
        }
      }
    } else {
      parts = cleaned.split(RegExp(r'\n\s*\n')).map((p) => p.replaceAll('\n', ' ').trim()).where((p) => p.isNotEmpty).toList();
    }
    return [
      for (final p in parts.take(20))
        () {
          final cut = p.indexOf(RegExp('[,.]'));
          var title = (cut > 0 ? p.substring(0, cut) : p).trim();
          if (title.characters.length > 24) title = '${title.characters.take(24)}…';
          return ExperienceDraft(title: title, content: p);
        }(),
    ];
  }

  List<Experience> addExperiences(List<ExperienceDraft> items) {
    _requireUser();
    if (items.isEmpty) throw _invalid('저장할 경험을 하나 이상 골라 주세요.');
    if (_experiences.length + items.length > AppPolicy.maxExperiences) {
      throw _invalid('경험은 최대 ${AppPolicy.maxExperiences}개까지 저장할 수 있어요.');
    }
    final added = [for (final d in items) Experience(id: _nextId('exp'), title: d.title.trim(), content: d.content.trim())];
    _experiences = [...added, ..._experiences];
    _persist();
    return added;
  }

  Experience updateExperience(Experience item) {
    _requireUser();
    if (item.title.trim().isEmpty || item.content.trim().isEmpty) throw _invalid('제목과 내용을 모두 적어 주세요.');
    final i = _experiences.indexWhere((e) => e.id == item.id);
    if (i < 0) throw const AppException(AppErrorKind.notFound, statusCode: 404);
    _experiences[i] = item;
    _persist();
    return item;
  }

  void deleteExperience(String id) {
    _requireUser();
    _experiences.removeWhere((e) => e.id == id);
    _persist();
  }

  AppUser completeOnboarding() {
    final u = _requireUser();
    if (_preps.isEmpty) throw _invalid('준비 기업을 먼저 골라 주세요.');
    _user = u.copyWith(onboardingCompleted: true);
    _persist();
    return _user!;
  }

  NotificationSettings notificationSettings() => _notification;

  NotificationSettings updateNotificationSettings(NotificationSettings s) {
    _notification = s;
    _persist();
    return s;
  }

  // ---------------------------------------------------------------- 홈

  HomeSummary home() {
    final u = _requireUser();
    return HomeSummary(nickname: u.nickname, companies: [for (final p in _preps) _companyHome(p)]);
  }

  CompanyHome _companyHome(Preparation p) {
    final id = p.companyId;
    final stat = _stats[id] ?? const [0, 0];
    final dday = p.ddayFrom(_now());
    final todayIds = _todayQuestions[id];
    final interviewTotal = AppPolicy.interviewDailyCount + (_bonusUsed.contains(id) ? AppPolicy.interviewAdBonus : 0);
    final interviewDone = todayIds == null ? 0 : todayIds.where((q) => (_attemptsToday[q] ?? 0) > 0).length;
    final questions = _answers.values.where((a) => companyIdOf(a.questionId) == id).map((a) => a.questionId).toSet();
    final completed = questions.where((q) => _answers.values.any((a) => a.questionId == q && a.status == AnswerStatus.complete)).length;
    final interview = TodayTask(done: interviewDone, total: interviewTotal);
    return CompanyHome(
      preparation: p,
      quizCorrect: stat[0],
      quizSolved: stat[1],
      interviewAnswered: questions.length,
      interviewCompleted: completed,
      quiz: TodayTask(done: _sets[_setId(id)]?.answers.length ?? 0, total: AppPolicy.quizQuestionCount),
      interview: interview,
      focusMode: dday != null && dday >= 0 && dday <= AppPolicy.focusModeDays,
      adBonusAvailable: interview.isDone && !_bonusUsed.contains(id),
      dday: dday,
    );
  }

  int? _accuracy(String companyId) {
    final s = _stats[companyId];
    if (s == null || s[1] == 0) return null;
    return (s[0] * 100 / s[1]).round();
  }

  // ---------------------------------------------------------------- 퀴즈

  String _setId(String companyId) => '${companyId}_$_day';

  QuizSet todaySet(String companyId) {
    final p = _requirePrep(companyId);
    final id = _setId(companyId);
    final state = _sets.putIfAbsent(id, () {
      // 퀴즈는 모두 객관식. 날마다 문제 순서를 돌려 5문제를 고른다.
      final bank = MockData.quizBank(companyId);
      final n = math.min(AppPolicy.quizQuestionCount, bank.length);
      return _SetState(
        companyId: companyId,
        questionIds: [for (var i = 0; i < n; i++) bank[(_dayIndex + i) % bank.length].id],
        answers: [],
        accuracyBefore: _accuracy(companyId),
      );
    });
    _persist();
    return QuizSet(
      id: id,
      companyId: companyId,
      companyName: p.companyName,
      questions: [for (var i = 0; i < state.questionIds.length; i++) _seed(state.questionIds[i]).toQuestion(i + 1)],
      answers: List.of(state.answers),
    );
  }

  MockQuizSeed _seed(String questionId) => MockData.quizBank(companyIdOf(questionId)).firstWhere((q) => q.id == questionId);

  _SetState _requireSet(String setId) {
    _requireUser();
    final s = _sets[setId];
    if (s == null) throw const AppException(AppErrorKind.notFound, statusCode: 404, message: '오늘 퀴즈가 바뀌었어요. 홈에서 다시 시작해 주세요.');
    return s;
  }

  QuizAnswerResult _grade(MockQuizSeed seed, String answer) => QuizAnswerResult(
        questionId: seed.id,
        answer: answer,
        correct: seed.correctChoiceId == answer,
        explanation: seed.explanation,
        correctChoiceId: seed.correctChoiceId,
        evidence: seed.evidence,
      );

  QuizAnswerResult answerQuiz({required String setId, required String questionId, required String answer}) {
    final s = _requireSet(setId);
    final existing = s.answers.where((a) => a.questionId == questionId).firstOrNull;
    if (existing != null) return existing; // 중복 제출은 처음 결과 그대로 (재시도·더블탭 대비)
    if (!s.questionIds.contains(questionId)) throw const AppException(AppErrorKind.validation);
    if (answer.trim().isEmpty) throw _invalid('답을 입력해 주세요.');

    final seed = _seed(questionId);
    final result = _grade(seed, answer.trim());
    s.answers.add(result);

    final stat = _stats.putIfAbsent(s.companyId, () => [0, 0]);
    stat[1] += 1;
    if (result.correct) stat[0] += 1;

    _review[questionId] = QuizReviewItem(
      id: 'rv-$questionId',
      companyId: s.companyId,
      question: seed.toQuestion(1),
      wrong: !result.correct,
      explanation: seed.explanation,
      solvedAt: _now(),
      evidence: seed.evidence,
      correctChoiceId: result.correctChoiceId,
    );
    _persist();
    return result;
  }

  QuizResult quizResult(String setId) {
    final s = _requireSet(setId);
    return QuizResult(
      setId: setId,
      companyId: s.companyId,
      companyName: MockData.company(s.companyId).name,
      correctCount: s.answers.where((a) => a.correct).length,
      total: s.questionIds.length,
      accuracyBefore: s.accuracyBefore,
      accuracyAfter: _accuracy(s.companyId),
      items: [
        for (final a in s.answers)
          QuizResultItem(
            questionId: a.questionId,
            title: _seed(a.questionId).title,
            correct: a.correct,
            explanation: a.explanation,
            myAnswer: _answerLabel(_seed(a.questionId), a.answer),
            correctAnswer: _answerLabel(_seed(a.questionId), _seed(a.questionId).correctChoiceId),
            evidence: a.evidence,
          ),
      ],
    );
  }

  /// 결과 화면 "내 답 C. 늘었다" (보기 글자 + 내용)
  static String _answerLabel(MockQuizSeed seed, String answer) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final i = seed.quizChoices.indexWhere((c) => c.id == answer);
    if (i < 0) return answer;
    return '${i < letters.length ? letters[i] : '${i + 1}'}. ${seed.choices[i]}';
  }

  void reportQuestion(String questionId, String reason) {
    _requireUser();
    reports.add({'questionId': questionId, 'reason': reason, 'at': _now().toIso8601String()});
  }

  // ---------------------------------------------------------------- 면접

  TodayInterview todayInterview(String companyId) {
    _requirePrep(companyId);
    final ids = _todayQuestions.putIfAbsent(companyId, () {
      final bank = MockData.interviewBank(companyId);
      return [for (var i = 0; i < math.min(AppPolicy.interviewDailyCount, bank.length); i++) bank[(_dayIndex + i) % bank.length].id];
    });
    _persist();
    return TodayInterview(companyId: companyId, questionIds: List.of(ids), doneIds: ids.where((q) => (_attemptsToday[q] ?? 0) > 0).toList());
  }

  void unlockBonusQuestion(String companyId) {
    _requirePrep(companyId);
    if (_bonusUsed.contains(companyId)) throw _invalid('오늘은 이미 1개 더 받았어요.');
    final today = todayInterview(companyId);
    final bank = MockData.interviewBank(companyId);
    final extra = bank.where((q) => !today.questionIds.contains(q.id)).firstOrNull ?? bank.first;
    _todayQuestions[companyId] = [...today.questionIds, extra.id];
    _bonusUsed.add(companyId);
    _persist();
  }

  InterviewQuestion question(String questionId) {
    _requireUser();
    final companyId = companyIdOf(questionId);
    final seed = MockData.interviewBank(companyId).where((q) => q.id == questionId).firstOrNull;
    if (seed == null) throw const AppException(AppErrorKind.notFound, statusCode: 404);
    final prep = _preps.where((p) => p.companyId == companyId).firstOrNull;
    final company = MockData.company(companyId);
    final job = prep?.jobName ?? '지원';
    return InterviewQuestion(
      id: seed.id,
      companyId: companyId,
      companyName: company.name,
      tags: [company.name, ?prep?.jobName],
      text: seed.text.replaceAll('{job}', job),
      evidence: seed.evidence,
      retryRemaining: _retryRemaining(questionId),
    );
  }

  int _retryRemaining(String questionId) => math.max(0, AppPolicy.retryPerQuestionDaily - (_attemptsToday[questionId] ?? 0));

  AnswerFeedback submitAnswer({required String questionId, required String content, required AnswerInputType inputType}) {
    final q = question(questionId);
    final text = content.trim();
    if (text.characters.length < AppPolicy.minAnswerLength) {
      throw _invalid('답변을 ${AppPolicy.minAnswerLength}자 이상 써 주세요.');
    }
    if (_retryRemaining(questionId) <= 0) {
      throw const AppException(
        AppErrorKind.feedbackQuotaExceeded,
        code: 'FEEDBACK_QUOTA_EXCEEDED',
        statusCode: 429,
        message: '오늘 이 질문에는 모두 답했어요. 내일 다시 도전해 주세요.',
      );
    }
    _attemptsToday[questionId] = (_attemptsToday[questionId] ?? 0) + 1;
    _drafts.remove(questionId);

    final seed = MockData.interviewBank(q.companyId).firstWhere((s) => s.id == questionId);
    final eval = MockFeedbackEngine.evaluate(text, q, seed.keywords, _experiences);
    final attempt = _answers.values.where((a) => a.questionId == questionId).fold<int>(0, (m, a) => math.max(m, a.attempt)) + 1;
    final feedback = AnswerFeedback(
      answerId: _nextId('ans'),
      questionId: questionId,
      content: text,
      inputType: inputType,
      attempt: attempt,
      submittedAt: _now(),
      score: eval.criteria.fold(0, (s, c) => s + c.score),
      criteria: eval.criteria,
      metCount: eval.metCount,
      status: eval.metCount >= AppPolicy.completeMetCount ? AnswerStatus.complete : AnswerStatus.needsWork,
      goodPoint: eval.goodPoint,
      improvement: eval.improvement,
      retryRemaining: _retryRemaining(questionId),
      relatedExperience: eval.related,
    );
    _answers[feedback.answerId] = feedback;
    _persist();
    return feedback;
  }

  AnswerFeedback feedback(String answerId) {
    _requireUser();
    final f = _answers[answerId];
    if (f == null) throw const AppException(AppErrorKind.notFound, statusCode: 404);
    return f.copyWith(retryRemaining: _retryRemaining(f.questionId));
  }

  void saveDraft(String questionId, String content) {
    question(questionId);
    if (content.trim().isEmpty) {
      _drafts.remove(questionId);
    } else {
      _drafts[questionId] = content;
    }
    _persist();
  }

  String? draft(String questionId) {
    _requireUser();
    return _drafts[questionId];
  }

  // ---------------------------------------------------------------- 복습

  List<QuizReviewItem> quizReview({required String companyId}) {
    _requireUser();
    return _review.values.where((r) => r.companyId == companyId).toList()..sort((a, b) => b.solvedAt.compareTo(a.solvedAt));
  }

  QuizAnswerResult retryQuiz(String itemId, String answer) {
    _requireUser();
    final item = _review.values.where((r) => r.id == itemId).firstOrNull;
    if (item == null) throw const AppException(AppErrorKind.notFound, statusCode: 404);
    final result = _grade(_seed(item.question.id), answer.trim());
    // 누적 정답률에 최근 결과로 반영 (푼 문제 수는 그대로, 맞힌 수만 바뀜)
    final stat = _stats.putIfAbsent(item.companyId, () => [0, 0]);
    if (item.wrong && result.correct) stat[0] += 1;
    if (!item.wrong && !result.correct) stat[0] = math.max(0, stat[0] - 1);
    _review[item.question.id] = item.copyWith(wrong: !result.correct, solvedAt: _now());
    _persist();
    return result;
  }

  List<InterviewRecord> interviewRecords({required String companyId}) {
    _requireUser();
    final ids = {
      ..._answers.values.map((a) => a.questionId),
      ..._drafts.keys,
    }.where((q) => companyIdOf(q) == companyId);
    final records = <InterviewRecord>[];
    for (final id in ids) {
      final attempts = _answers.values.where((a) => a.questionId == id).toList()..sort((a, b) => a.attempt.compareTo(b.attempt));
      final last = attempts.lastOrNull;
      records.add(InterviewRecord(
        questionId: id,
        companyId: companyId,
        questionText: question(id).text,
        status: last?.status ?? AnswerStatus.draft,
        attempts: attempts.length,
        score: last?.score,
        metCount: last?.metCount,
        lastAt: last?.submittedAt,
      ));
    }
    records.sort((a, b) => (b.lastAt ?? _now()).compareTo(a.lastAt ?? _now()));
    return records;
  }

  InterviewRecordDetail interviewRecord(String questionId) {
    final q = question(questionId);
    final attempts = _answers.values.where((a) => a.questionId == questionId).map((a) => feedback(a.answerId)).toList()
      ..sort((a, b) => a.attempt.compareTo(b.attempt));
    return InterviewRecordDetail(question: q, attempts: attempts);
  }

  void deleteInterviewRecord(String questionId) {
    _requireUser();
    _answers.removeWhere((_, a) => a.questionId == questionId);
    _drafts.remove(questionId);
    _persist();
  }

  void deleteAttempt(String answerId) {
    _requireUser();
    _answers.remove(answerId);
    _persist();
  }

  // ---------------------------------------------------------------- 문의

  void submitInquiry({required InquiryType type, required String content}) {
    _requireUser();
    if (content.trim().isEmpty) throw _invalid('문의 내용을 적어 주세요.');
    _inquiries.insert(0, Inquiry(id: _nextId('inq'), type: type, content: content.trim(), createdAt: _now(), statusLabel: '접수됨'));
    _persist();
  }

  List<Inquiry> inquiries() {
    _requireUser();
    return List.unmodifiable(_inquiries);
  }

  // ---------------------------------------------------------------- 저장 / 복원

  void _persist() {
    final store = _store;
    if (store == null) return;
    store.writeJson(storageKey, {
      'user': _user?.toJson(),
      'loggedIn': _loggedIn,
      'preps': _preps.map((p) => p.toJson()).toList(),
      'past': _past.map((p) => p.toJson()).toList(),
      'experiences': _experiences.map((e) => e.toJson()).toList(),
      'notification': _notification.toJson(),
      'day': _day,
      'sets': _sets.map((k, v) => MapEntry(k, v.toJson())),
      'stats': _stats,
      'review': _review.map((k, v) => MapEntry(k, v.toJson())),
      'answers': _answers.map((k, v) => MapEntry(k, v.toJson())),
      'drafts': _drafts,
      'todayQuestions': _todayQuestions,
      'attemptsToday': _attemptsToday,
      'bonusUsed': _bonusUsed.toList(),
      'inquiries': _inquiries.map((i) => i.toJson()).toList(),
      'seq': _seq,
    });
  }

  void _load() {
    final json = _store?.readJson(storageKey);
    if (json == null) return;
    Map<String, dynamic> obj(dynamic v) => (v as Map).cast<String, dynamic>();
    try {
      final u = json['user'];
      _user = u == null ? null : AppUser.fromJson(obj(u));
      _loggedIn = json['loggedIn'] as bool? ?? false;
      _preps = (json['preps'] as List<dynamic>).map((e) => Preparation.fromJson(obj(e))).toList();
      _past = (json['past'] as List<dynamic>? ?? const []).map((e) => PastPreparation.fromJson(obj(e))).toList();
      _experiences = (json['experiences'] as List<dynamic>).map((e) => Experience.fromJson(obj(e))).toList();
      _notification = NotificationSettings.fromJson(obj(json['notification']));
      _day = json['day'] as String? ?? '';
      obj(json['sets']).forEach((k, v) => _sets[k] = _SetState.fromJson(obj(v)));
      obj(json['stats']).forEach((k, v) => _stats[k] = (v as List<dynamic>).cast<int>().toList());
      obj(json['review']).forEach((k, v) => _review[k] = QuizReviewItem.fromJson(obj(v)));
      obj(json['answers']).forEach((k, v) => _answers[k] = AnswerFeedback.fromJson(obj(v)));
      obj(json['drafts']).forEach((k, v) => _drafts[k] = v as String);
      obj(json['todayQuestions']).forEach((k, v) => _todayQuestions[k] = (v as List<dynamic>).cast<String>().toList());
      obj(json['attemptsToday']).forEach((k, v) => _attemptsToday[k] = v as int);
      _bonusUsed.addAll((json['bonusUsed'] as List<dynamic>).cast<String>());
      _inquiries.addAll((json['inquiries'] as List<dynamic>).map((e) => Inquiry.fromJson(obj(e))));
      _seq = json['seq'] as int? ?? 0;
    } catch (_) {
      // 저장 형식이 바뀌었으면 처음부터
      _store?.remove(storageKey);
    }
  }
}

class _SetState {
  _SetState({required this.companyId, required this.questionIds, required this.answers, required this.accuracyBefore});

  factory _SetState.fromJson(Map<String, dynamic> json) => _SetState(
        companyId: json['companyId'] as String,
        questionIds: (json['questionIds'] as List<dynamic>).cast<String>().toList(),
        answers: (json['answers'] as List<dynamic>)
            .map((e) => QuizAnswerResult.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        accuracyBefore: json['accuracyBefore'] as int?,
      );

  final String companyId;
  final List<String> questionIds;
  final List<QuizAnswerResult> answers;
  final int? accuracyBefore;

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'questionIds': questionIds,
        'answers': answers.map((a) => a.toJson()).toList(),
        'accuracyBefore': accuracyBefore,
      };
}

class MockEvaluation {
  const MockEvaluation({required this.criteria, required this.goodPoint, required this.improvement, this.related});

  final List<CriterionScore> criteria;
  final String goodPoint;
  final String improvement;
  final RelatedExperience? related;

  int get metCount => criteria.where((c) => c.score >= AppPolicy.criterionPassScore).length;
}

/// AI 피드백 흉내. 실제 서비스에서는 서버(LLM)가 판단한다.
/// 화면이 보완 필요 / 완성 두 결과를 모두 보여주는지 확인하려고 간단한 규칙으로 점수를 매긴다.
class MockFeedbackEngine {
  MockFeedbackEngine._();

  static final _sentence = RegExp(r'[^.!?。\n]+[.!?。]?');
  static final _digits = RegExp(r'\d');

  static int _clamp(num v) => v.round().clamp(8, 20);

  static MockEvaluation evaluate(String text, InterviewQuestion q, List<String> keywords, List<Experience> experiences) {
    final sentences = _sentence.allMatches(text).map((m) => m.group(0)!.trim()).where((s) => s.isNotEmpty).toList();
    final first = sentences.isEmpty ? text : sentences.first;
    final len = text.characters.length;

    // 1) 응답성: 첫 문장에서 결론(지원 이유·기여)을 말했는지
    final conclusive = ['때문', '지원했', '싶습니다', '하겠습니다', '입니다', '이유는'].any(first.contains);
    final responsiveness = _clamp(10 + (conclusive ? 6 : 0) + (first.characters.length <= 80 ? 2 : 0) + (len > 150 ? 1 : 0));

    // 2) 기업 정보 활용: 기업 이름·근거 단어
    final hits = keywords.where(text.contains).length + (text.contains(q.companyName) ? 1 : 0);
    final companyInfo = _clamp(9 + hits * 3.5);

    // 3) 구체성: 숫자와 경험 표현
    final numbers = _digits.allMatches(text).length;
    final expWords = ['경험', '프로젝트', '운영', '담당', '맡아', '결과'].where(text.contains).length;
    final specificity = _clamp(9 + math.min(numbers, 3) * 2 + expWords * 1.5);

    // 4) 논리와 구조: 문장 수와 연결어
    final connectors = ['그래서', '따라서', '또한', '이를 통해', '먼저', '마지막으로', '예를 들어'].where(text.contains).length;
    final logic = _clamp(9 + math.min(sentences.length, 5) + connectors * 2);

    // 5) 명료성: 너무 짧거나 길지 않은지
    final clarity = _clamp(len < 80 ? 10 : len <= 600 ? 15 + (len > 200 ? 2 : 0) : 13);

    // 완성본 와이어프레임: 4개 항목 × 25점 = 100점. 응답성은 따로 보여주지 않고 논리·구조 점수에 섞는다.
    int to25(num v) => (v * AppPolicy.criterionMaxScore / 20).round().clamp(0, AppPolicy.criterionMaxScore);
    final criteria = [
      CriterionScore(key: CriterionKey.companyInfo, score: to25(companyInfo)),
      CriterionScore(key: CriterionKey.specificity, score: to25(specificity)),
      CriterionScore(key: CriterionKey.logic, score: to25((logic + responsiveness) / 2)),
      CriterionScore(key: CriterionKey.clarity, score: to25(clarity)),
    ];
    final sorted = List.of(criteria)..sort((a, b) => b.score.compareTo(a.score));

    String good(CriterionKey k) => switch (k) {
          CriterionKey.responsiveness => '지원 이유를 먼저 말해서 질문에 바로 답했어요.',
          CriterionKey.companyInfo => '${q.companyName}의 사업 방향을 근거로 들었어요.',
          CriterionKey.specificity => '숫자와 경험으로 내용을 구체적으로 보여줬어요.',
          CriterionKey.logic => '이유 → 경험 → 기여 순서로 흐름이 자연스러워요.',
          CriterionKey.clarity => '길이가 알맞고 문장이 분명해요.',
        };
    String improve(CriterionKey k) => switch (k) {
          CriterionKey.responsiveness => '첫 문장에 “저는 ~ 때문에 지원했습니다”처럼 결론을 먼저 말해 보세요.',
          CriterionKey.companyInfo => '공시 근거(예: ${keywords.isEmpty ? '주요 사업' : keywords.first})를 한 가지 넣어 보세요.',
          CriterionKey.specificity => '내 경험의 역할과 결과를 숫자로 보여주면 더 구체적이에요.',
          CriterionKey.logic => '“먼저 · 또한 · 그래서”로 이유와 경험을 이어 보세요.',
          CriterionKey.clarity => len < 80 ? '조금 더 길게, 1분 분량으로 말해 보세요.' : '문장을 짧게 나누면 더 잘 들려요.',
        };

    RelatedExperience? related;
    final unused = experiences.where((e) => !text.contains(e.title)).toList();
    if (unused.isNotEmpty) {
      final e = unused.first;
      related = RelatedExperience(
        title: e.title,
        content: e.content,
        tip: '이 경험의 역할·결과를 ${q.companyName}의 사업과 연결하면 답변이 더 구체적이에요.',
      );
    }
    return MockEvaluation(criteria: criteria, goodPoint: good(sorted.first.key), improvement: improve(sorted.last.key), related: related);
  }
}
