import 'interview.dart';
import 'quiz.dart';

/// 퀴즈 복습 한 문제 (5-1). 마지막으로 푼 결과가 오답이면 "최근 오답".
class QuizReviewItem {
  const QuizReviewItem({
    required this.id,
    required this.companyId,
    required this.question,
    required this.wrong,
    required this.explanation,
    required this.solvedAt,
    this.evidence,
  });

  factory QuizReviewItem.fromJson(Map<String, dynamic> json) => QuizReviewItem(
        id: json['id'].toString(),
        companyId: json['companyId'].toString(),
        question: QuizQuestion.fromJson((json['question'] as Map).cast<String, dynamic>()),
        wrong: json['wrong'] as bool,
        explanation: json['explanation'] as String,
        solvedAt: DateTime.parse(json['solvedAt'] as String),
        evidence: json['evidence'] == null ? null : Evidence.fromJson((json['evidence'] as Map).cast<String, dynamic>()),
      );

  final String id;
  final String companyId;
  final QuizQuestion question;
  final bool wrong;
  final String explanation;
  final DateTime solvedAt;
  final Evidence? evidence;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'question': question.toJson(),
        'wrong': wrong,
        'explanation': explanation,
        'solvedAt': solvedAt.toIso8601String(),
        'evidence': evidence?.toJson(),
      };

  QuizReviewItem copyWith({bool? wrong, DateTime? solvedAt}) => QuizReviewItem(
        id: id,
        companyId: companyId,
        question: question,
        wrong: wrong ?? this.wrong,
        explanation: explanation,
        solvedAt: solvedAt ?? this.solvedAt,
        evidence: evidence,
      );
}

/// 면접 복습 한 질문 (5-2)
class InterviewRecord {
  const InterviewRecord({
    required this.questionId,
    required this.companyId,
    required this.questionText,
    required this.status,
    required this.attempts,
    this.score,
    this.metCount,
    this.lastAt,
  });

  factory InterviewRecord.fromJson(Map<String, dynamic> json) => InterviewRecord(
        questionId: json['questionId'].toString(),
        companyId: json['companyId'].toString(),
        questionText: json['questionText'] as String,
        status: AnswerStatus.fromWire(json['status'] as String?),
        attempts: json['attempts'] as int? ?? 0,
        score: json['score'] as int?,
        metCount: json['metCount'] as int?,
        lastAt: json['lastAt'] == null ? null : DateTime.parse(json['lastAt'] as String),
      );

  final String questionId;
  final String companyId;
  final String questionText;
  final AnswerStatus status;
  final int attempts;

  /// 마지막 시도 점수 (작성 중이면 null)
  final int? score;
  final int? metCount;
  final DateTime? lastAt;
}

/// 답변 보기 (5-3): 질문 + 시도 목록
class InterviewRecordDetail {
  const InterviewRecordDetail({required this.question, required this.attempts});

  factory InterviewRecordDetail.fromJson(Map<String, dynamic> json) => InterviewRecordDetail(
        question: InterviewQuestion.fromJson((json['question'] as Map).cast<String, dynamic>()),
        attempts:
            (json['attempts'] as List<dynamic>).map((e) => AnswerFeedback.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );

  final InterviewQuestion question;

  /// 시도 1, 시도 2 … 순서
  final List<AnswerFeedback> attempts;
}
