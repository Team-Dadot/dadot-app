/// 퀴즈 모델. 채점은 서버가 한다 (정답을 앱에 미리 내려주지 않음). 퀴즈는 모두 객관식이다 (주관식 없음).
library;

/// 공시 근거 (3-4 시트, 4-2 답변에 활용할 정보)
class Evidence {
  const Evidence({required this.title, required this.excerpt, this.publishedAt, this.period, this.url, this.interpretation});

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
        title: json['title'] as String,
        excerpt: json['excerpt'] as String? ?? '',
        publishedAt: json['publishedAt'] as String?,
        period: json['period'] as String?,
        url: json['url'] as String?,
        interpretation: json['interpretation'] as String?,
      );

  /// 예: 기아 2025 사업보고서
  final String title;
  final String excerpt;

  /// 예: 2026.03.12
  final String? publishedAt;

  /// 예: 2025.01.01 – 2025.12.31
  final String? period;
  final String? url;

  /// 공시 근거 시트 "해석 · 전기차가 차지하는 판매 비중이 전년보다 커졌다는 뜻이에요."
  final String? interpretation;

  /// "공시일 2026.03.12 · 대상 기간 2025.01.01 – 2025.12.31"
  String get metaLine => [
        if (publishedAt != null) '공시일 $publishedAt',
        if (period != null) '대상 기간 $period',
      ].join(' · ');

  Map<String, dynamic> toJson() =>
      {'title': title, 'excerpt': excerpt, 'publishedAt': publishedAt, 'period': period, 'url': url, 'interpretation': interpretation};
}

class QuizChoice {
  const QuizChoice({required this.id, required this.text});

  factory QuizChoice.fromJson(Map<String, dynamic> json) => QuizChoice(id: json['id'].toString(), text: json['text'] as String);

  final String id;
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.order,
    required this.tags,
    required this.prompt,
    required this.title,
    required this.choices,
    this.evidence,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'].toString(),
        order: json['order'] as int? ?? 1,
        tags: (json['tags'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        prompt: json['prompt'] as String,
        title: json['title'] as String? ?? json['prompt'] as String,
        choices: (json['choices'] as List<dynamic>? ?? const [])
            .map((e) => QuizChoice.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        evidence: json['evidence'] == null ? null : Evidence.fromJson((json['evidence'] as Map).cast<String, dynamic>()),
      );

  final String id;
  final int order;

  /// 주제 태그 (실적, 사업 계획 …)
  final List<String> tags;
  final String prompt;

  /// 결과 목록에 쓰는 짧은 제목 (전기차 판매량 변화)
  final String title;
  final List<QuizChoice> choices;

  /// "공시 근거 먼저 보기" 로 미리 볼 수 있는 근거
  final Evidence? evidence;

  /// 서버에서 아직 받지 않은 문항 자리 (다닷 서버는 한 문항씩 준다 → 제출 뒤 세트를 다시 불러와 받는다)
  bool get isPlaceholder => id.isEmpty && prompt.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'tags': tags,
        'prompt': prompt,
        'title': title,
        'choices': choices.map((c) => c.toJson()).toList(),
        'evidence': evidence?.toJson(),
      };
}

/// 문항 하나 채점 결과
class QuizAnswerResult {
  const QuizAnswerResult({
    required this.questionId,
    required this.answer,
    required this.correct,
    required this.explanation,
    this.correctChoiceId,
    this.evidence,
  });

  factory QuizAnswerResult.fromJson(Map<String, dynamic> json) => QuizAnswerResult(
        questionId: json['questionId'].toString(),
        answer: json['answer'].toString(),
        correct: json['correct'] as bool,
        explanation: json['explanation'] as String,
        correctChoiceId: json['correctChoiceId']?.toString(),
        evidence: json['evidence'] == null ? null : Evidence.fromJson((json['evidence'] as Map).cast<String, dynamic>()),
      );

  final String questionId;

  /// 고른 보기 choiceId
  final String answer;
  final bool correct;
  final String explanation;
  final String? correctChoiceId;
  final Evidence? evidence;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'answer': answer,
        'correct': correct,
        'explanation': explanation,
        'correctChoiceId': correctChoiceId,
        'evidence': evidence?.toJson(),
      };
}

/// 오늘의 퀴즈 세트. answers 에 이미 푼 문항이 들어 있으면 이어하기.
class QuizSet {
  const QuizSet({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.questions,
    required this.answers,
  });

  factory QuizSet.fromJson(Map<String, dynamic> json) => QuizSet(
        id: json['id'].toString(),
        companyId: json['companyId'].toString(),
        companyName: json['companyName'] as String,
        questions: (json['questions'] as List<dynamic>).map((e) => QuizQuestion.fromJson((e as Map).cast<String, dynamic>())).toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
        answers: (json['answers'] as List<dynamic>? ?? const [])
            .map((e) => QuizAnswerResult.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  final String id;
  final String companyId;
  final String companyName;
  final List<QuizQuestion> questions;
  final List<QuizAnswerResult> answers;

  bool get isCompleted => answers.length >= questions.length;

  /// 다음에 풀 문항 순서 (0부터)
  int get nextIndex => answers.length.clamp(0, questions.length);
}

/// 결과 화면 "문제별 해설" 한 문항 (Q1 전기차 판매량은 … · 정답 ⌄)
class QuizResultItem {
  const QuizResultItem({
    required this.questionId,
    required this.title,
    required this.correct,
    required this.explanation,
    this.myAnswer,
    this.correctAnswer,
    this.evidence,
  });

  factory QuizResultItem.fromJson(Map<String, dynamic> json) => QuizResultItem(
        questionId: json['questionId'].toString(),
        title: json['title'] as String,
        correct: json['correct'] as bool,
        explanation: json['explanation'] as String,
        myAnswer: json['myAnswer'] as String?,
        correctAnswer: json['correctAnswer'] as String?,
        evidence: json['evidence'] == null ? null : Evidence.fromJson((json['evidence'] as Map).cast<String, dynamic>()),
      );

  final String questionId;
  final String title;
  final bool correct;
  final String explanation;

  /// "C. 늘었다" (보기 글자 + 내용)
  final String? myAnswer;

  /// "C. 늘었다"
  final String? correctAnswer;
  final Evidence? evidence;
}

class QuizResult {
  const QuizResult({
    required this.setId,
    required this.companyId,
    required this.companyName,
    required this.correctCount,
    required this.total,
    required this.accuracyBefore,
    required this.accuracyAfter,
    required this.items,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        setId: json['setId'].toString(),
        companyId: json['companyId'].toString(),
        companyName: json['companyName'] as String,
        correctCount: json['correctCount'] as int,
        total: json['total'] as int,
        accuracyBefore: json['accuracyBefore'] as int?,
        accuracyAfter: json['accuracyAfter'] as int?,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => QuizResultItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  final String setId;
  final String companyId;
  final String companyName;
  final int correctCount;
  final int total;

  /// 이번 세트 반영 전 정답률 (첫 세트면 null)
  final int? accuracyBefore;
  final int? accuracyAfter;
  final List<QuizResultItem> items;

  int get wrongCount => total - correctCount;
}
