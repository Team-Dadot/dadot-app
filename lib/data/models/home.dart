import 'catalog.dart';

/// 오늘 할 일 진행 (퀴즈 0/5, 면접 질문 0/3)
class TodayTask {
  const TodayTask({required this.done, required this.total});

  factory TodayTask.fromJson(Map<String, dynamic> json) => TodayTask(done: json['done'] as int? ?? 0, total: json['total'] as int? ?? 0);

  final int done;
  final int total;

  bool get isDone => total > 0 && done >= total;
  int get remaining => (total - done).clamp(0, total);

  Map<String, dynamic> toJson() => {'done': done, 'total': total};
}

/// 홈의 준비 기업 한 곳 (2-1 ~ 2-4)
class CompanyHome {
  const CompanyHome({
    required this.preparation,
    required this.quizCorrect,
    required this.quizSolved,
    required this.interviewAnswered,
    required this.interviewCompleted,
    required this.quiz,
    required this.interview,
    required this.focusMode,
    required this.adBonusAvailable,
    this.dday,
    this.interviewScorePercent,
  });

  factory CompanyHome.fromJson(Map<String, dynamic> json) => CompanyHome(
        preparation: Preparation.fromJson((json['preparation'] as Map).cast<String, dynamic>()),
        quizCorrect: json['quizCorrect'] as int? ?? 0,
        quizSolved: json['quizSolved'] as int? ?? 0,
        interviewAnswered: json['interviewAnswered'] as int? ?? 0,
        interviewCompleted: json['interviewCompleted'] as int? ?? 0,
        quiz: TodayTask.fromJson((json['quiz'] as Map).cast<String, dynamic>()),
        interview: TodayTask.fromJson((json['interview'] as Map).cast<String, dynamic>()),
        focusMode: json['focusMode'] as bool? ?? false,
        adBonusAvailable: json['adBonusAvailable'] as bool? ?? false,
        dday: json['dday'] as int?,
      );

  final Preparation preparation;

  /// 누적 퀴즈: 푼 문제 중 맞힌 수
  final int quizCorrect;
  final int quizSolved;

  /// 누적 면접: 답한 질문 중 완성한 수
  final int interviewAnswered;
  final int interviewCompleted;

  final TodayTask quiz;
  final TodayTask interview;

  /// 면접 3일 전부터 복습·다듬기 위주 (2-2)
  final bool focusMode;

  /// 광고 보고 면접 질문 1개 더 받을 수 있는지 (2-4)
  final bool adBonusAvailable;

  /// 면접까지 남은 날. 면접일이 없으면 null.
  final int? dday;

  /// 서버 홈 지표: 질문별 최신 답변 평균 점수 비율 (interviewEvaluationSummary.averageScorePercent). 집계가 없으면 null.
  final int? interviewScorePercent;

  String get companyId => preparation.companyId;
  String get companyName => preparation.companyName;

  int? get accuracy => quizSolved == 0 ? null : (quizCorrect * 100 / quizSolved).round();
  int? get completionRate =>
      interviewScorePercent ?? (interviewAnswered == 0 ? null : (interviewCompleted * 100 / interviewAnswered).round());

  bool get allDone => quiz.isDone && interview.isDone;

  /// 오늘 남은 학습 수 (전환 시트 "오늘 8개 남음")
  int get remainingToday => quiz.remaining + interview.remaining;
}

class HomeSummary {
  const HomeSummary({required this.nickname, required this.companies});

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
        nickname: json['nickname'] as String? ?? '',
        companies:
            (json['companies'] as List<dynamic>).map((e) => CompanyHome.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );

  final String nickname;
  final List<CompanyHome> companies;

  CompanyHome? byId(String? id) => companies.where((c) => c.companyId == id).firstOrNull;
}
