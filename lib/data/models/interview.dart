/// 면접 질문 · 답변 · AI 피드백 모델
library;

import 'quiz.dart';

enum AnswerInputType {
  text('TEXT'),
  voice('VOICE');

  const AnswerInputType(this.wire);
  final String wire;

  static AnswerInputType fromWire(String? v) => v == 'VOICE' ? AnswerInputType.voice : AnswerInputType.text;
}

class InterviewQuestion {
  const InterviewQuestion({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.tags,
    required this.text,
    required this.evidence,
    this.retryRemaining,
  });

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) => InterviewQuestion(
        id: json['id'].toString(),
        companyId: json['companyId'].toString(),
        companyName: json['companyName'] as String,
        tags: (json['tags'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        text: json['text'] as String,
        evidence: (json['evidence'] as List<dynamic>? ?? const [])
            .map((e) => Evidence.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        retryRemaining: json['retryRemaining'] as int?,
      );

  final String id;
  final String companyId;
  final String companyName;

  /// [기아] [마케팅]
  final List<String> tags;
  final String text;

  /// 답변에 활용할 정보
  final List<Evidence> evidence;

  /// 오늘 이 질문에 더 답할 수 있는 횟수
  final int? retryRemaining;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'companyName': companyName,
        'tags': tags,
        'text': text,
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'retryRemaining': retryRemaining,
      };
}

/// 오늘의 면접 질문 묶음 (기업별 3개, 광고 보면 +1)
class TodayInterview {
  const TodayInterview({required this.companyId, required this.questionIds, required this.doneIds});

  factory TodayInterview.fromJson(Map<String, dynamic> json) => TodayInterview(
        companyId: json['companyId'].toString(),
        questionIds: (json['questionIds'] as List<dynamic>).map((e) => e.toString()).toList(),
        doneIds: (json['doneIds'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      );

  final String companyId;
  final List<String> questionIds;
  final List<String> doneIds;

  /// 아직 답하지 않은 첫 질문
  String? get nextQuestionId => questionIds.where((id) => !doneIds.contains(id)).firstOrNull;
}

/// 피드백 평가 항목. 완성본 와이어프레임은 4개 (응답성은 서버가 아직 보내도 읽을 수 있게 남겨 둠)
enum CriterionKey {
  responsiveness('RESPONSIVENESS', '질문에 대한 응답성'),
  companyInfo('COMPANY_INFO', '기업 정보의 활용'),
  specificity('SPECIFICITY', '내용의 구체성'),
  logic('LOGIC', '논리와 답변 구조'),
  clarity('CLARITY', '전달의 명료성');

  const CriterionKey(this.wire, this.label);
  final String wire;
  final String label;

  static CriterionKey fromWire(String? v) => CriterionKey.values.firstWhere((e) => e.wire == v, orElse: () => CriterionKey.clarity);
}

class CriterionScore {
  const CriterionScore({required this.key, required this.score, this.max = 25});

  factory CriterionScore.fromJson(Map<String, dynamic> json) => CriterionScore(
        key: CriterionKey.fromWire(json['key'] as String?),
        score: json['score'] as int,
        max: json['max'] as int? ?? 25,
      );

  final CriterionKey key;
  final int score;
  final int max;

  Map<String, dynamic> toJson() => {'key': key.wire, 'score': score, 'max': max};
}

/// 답변 상태 (복습 탭 태그)
enum AnswerStatus {
  needsWork('NEEDS_WORK', '보완 필요'),
  complete('COMPLETE', '완성'),
  draft('DRAFT', '작성 중');

  const AnswerStatus(this.wire, this.label);
  final String wire;
  final String label;

  static AnswerStatus fromWire(String? v) => AnswerStatus.values.firstWhere((e) => e.wire == v, orElse: () => AnswerStatus.needsWork);
}

/// "연결해볼 만한 내 경험"
class RelatedExperience {
  const RelatedExperience({required this.title, required this.content, required this.tip});

  factory RelatedExperience.fromJson(Map<String, dynamic> json) =>
      RelatedExperience(title: json['title'] as String, content: json['content'] as String, tip: json['tip'] as String? ?? '');

  final String title;
  final String content;
  final String tip;

  Map<String, dynamic> toJson() => {'title': title, 'content': content, 'tip': tip};
}

/// AI 피드백 (4-6). 답변 1회 제출 = 시도 1회.
class AnswerFeedback {
  const AnswerFeedback({
    required this.answerId,
    required this.questionId,
    required this.content,
    required this.inputType,
    required this.attempt,
    required this.submittedAt,
    required this.score,
    required this.criteria,
    required this.metCount,
    required this.status,
    required this.goodPoint,
    required this.improvement,
    required this.retryRemaining,
    this.relatedExperience,
  });

  factory AnswerFeedback.fromJson(Map<String, dynamic> json) => AnswerFeedback(
        answerId: json['answerId'].toString(),
        questionId: json['questionId'].toString(),
        content: json['content'] as String,
        inputType: AnswerInputType.fromWire(json['inputType'] as String?),
        attempt: json['attempt'] as int? ?? 1,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        score: json['score'] as int,
        criteria: (json['criteria'] as List<dynamic>).map((e) => CriterionScore.fromJson((e as Map).cast<String, dynamic>())).toList(),
        metCount: json['metCount'] as int? ?? 0,
        status: AnswerStatus.fromWire(json['status'] as String?),
        goodPoint: json['goodPoint'] as String? ?? '',
        improvement: json['improvement'] as String? ?? '',
        retryRemaining: json['retryRemaining'] as int? ?? 0,
        relatedExperience: json['relatedExperience'] == null
            ? null
            : RelatedExperience.fromJson((json['relatedExperience'] as Map).cast<String, dynamic>()),
      );

  final String answerId;
  final String questionId;
  final String content;
  final AnswerInputType inputType;

  /// 몇 번째 시도 (1부터)
  final int attempt;
  final DateTime submittedAt;

  /// 100점 만점
  final int score;
  final List<CriterionScore> criteria;

  /// 기준을 충족한 항목 수 (3개 이상이면 완성)
  final int metCount;
  final AnswerStatus status;
  final String goodPoint;
  final String improvement;

  /// 오늘 같은 질문에 더 답할 수 있는 횟수
  final int retryRemaining;
  final RelatedExperience? relatedExperience;

  Map<String, dynamic> toJson() => {
        'answerId': answerId,
        'questionId': questionId,
        'content': content,
        'inputType': inputType.wire,
        'attempt': attempt,
        'submittedAt': submittedAt.toIso8601String(),
        'score': score,
        'criteria': criteria.map((c) => c.toJson()).toList(),
        'metCount': metCount,
        'status': status.wire,
        'goodPoint': goodPoint,
        'improvement': improvement,
        'retryRemaining': retryRemaining,
        'relatedExperience': relatedExperience?.toJson(),
      };

  AnswerFeedback copyWith({int? retryRemaining}) => AnswerFeedback(
        answerId: answerId,
        questionId: questionId,
        content: content,
        inputType: inputType,
        attempt: attempt,
        submittedAt: submittedAt,
        score: score,
        criteria: criteria,
        metCount: metCount,
        status: status,
        goodPoint: goodPoint,
        improvement: improvement,
        retryRemaining: retryRemaining ?? this.retryRemaining,
        relatedExperience: relatedExperience,
      );
}
