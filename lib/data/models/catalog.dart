/// 기업 · 직무 · 준비 기업(지원 정보) · 내 경험 모델
library;

class Company {
  const Company({required this.id, required this.name, this.industry});

  factory Company.fromJson(Map<String, dynamic> json) =>
      Company(id: json['id'].toString(), name: json['name'] as String, industry: json['industry'] as String?);

  final String id;
  final String name;
  final String? industry;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'industry': industry};
}

class Job {
  const Job({required this.id, required this.name});

  factory Job.fromJson(Map<String, dynamic> json) => Job(id: json['id'].toString(), name: json['name'] as String);

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// 직무 분류 (기획·전략, 마케팅·홍보 …)
class JobCategory {
  const JobCategory({required this.id, required this.name, required this.jobs});

  factory JobCategory.fromJson(Map<String, dynamic> json) => JobCategory(
        id: json['id'].toString(),
        name: json['name'] as String,
        jobs: (json['jobs'] as List<dynamic>).map((e) => Job.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );

  final String id;
  final String name;
  final List<Job> jobs;
}

/// 직무 선택 시트 (1-4)
class JobCatalog {
  const JobCatalog({required this.popular, required this.categories});

  factory JobCatalog.fromJson(Map<String, dynamic> json) => JobCatalog(
        popular: (json['popular'] as List<dynamic>).map((e) => Job.fromJson((e as Map).cast<String, dynamic>())).toList(),
        categories:
            (json['categories'] as List<dynamic>).map((e) => JobCategory.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );

  final List<Job> popular;
  final List<JobCategory> categories;

  Iterable<Job> get all => categories.expand((c) => c.jobs);
}

/// 예전에 준비했던 기업 (6-2 "준비했던 기업 · 퀴즈 30문제 · 면접 답변 4개 · 다시 추가하기")
class PastPreparation {
  const PastPreparation({required this.companyId, required this.companyName, this.industry, this.jobId, this.jobName, this.quizCount = 0, this.answerCount = 0});

  factory PastPreparation.fromJson(Map<String, dynamic> json) => PastPreparation(
        companyId: json['companyId'].toString(),
        companyName: json['companyName'] as String,
        industry: json['industry'] as String?,
        jobId: json['jobId']?.toString(),
        jobName: json['jobName'] as String?,
        quizCount: json['quizCount'] as int? ?? 0,
        answerCount: json['answerCount'] as int? ?? 0,
      );

  final String companyId;
  final String companyName;
  final String? industry;

  /// 이전 지원 직무. 직접 입력한 직무는 jobId 없이 jobName만 있다.
  final String? jobId;
  final String? jobName;
  final int quizCount;
  final int answerCount;

  Company get company => Company(id: companyId, name: companyName, industry: industry);

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'companyName': companyName,
        'industry': industry,
        'jobId': jobId,
        'jobName': jobName,
        'quizCount': quizCount,
        'answerCount': answerCount,
      };
}

/// 준비 기업 한 곳의 지원 정보 (기업 + 직무 + 면접일)
class Preparation {
  const Preparation({
    required this.companyId,
    required this.companyName,
    this.industry,
    this.jobId,
    this.jobName,
    this.interviewDate,
  });

  factory Preparation.fromJson(Map<String, dynamic> json) => Preparation(
        companyId: json['companyId'].toString(),
        companyName: json['companyName'] as String,
        industry: json['industry'] as String?,
        jobId: json['jobId'] as String?,
        jobName: json['jobName'] as String?,
        interviewDate: json['interviewDate'] == null ? null : DateTime.parse(json['interviewDate'] as String),
      );

  factory Preparation.fromCompany(Company c) => Preparation(companyId: c.id, companyName: c.name, industry: c.industry);

  final String companyId;
  final String companyName;
  final String? industry;

  /// 직접 입력한 직무는 jobId 없이 jobName 만 있다
  final String? jobId;
  final String? jobName;
  final DateTime? interviewDate;

  bool get hasJob => (jobName ?? '').isNotEmpty;

  /// 오늘 기준 면접까지 남은 날. 면접일이 없으면 null, 지났으면 음수.
  int? ddayFrom(DateTime now) {
    final d = interviewDate;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'companyName': companyName,
        'industry': industry,
        'jobId': jobId,
        'jobName': jobName,
        'interviewDate': interviewDate == null ? null : formatIsoDate(interviewDate!),
      };

  Preparation copyWith({String? jobId, String? jobName, DateTime? interviewDate, bool clearDate = false}) => Preparation(
        companyId: companyId,
        companyName: companyName,
        industry: industry,
        jobId: jobId ?? this.jobId,
        jobName: jobName ?? this.jobName,
        interviewDate: clearDate ? null : (interviewDate ?? this.interviewDate),
      );
}

/// 저장한 내 경험 한 건
class Experience {
  const Experience({required this.id, required this.title, required this.content});

  factory Experience.fromJson(Map<String, dynamic> json) =>
      Experience(id: json['id'].toString(), title: json['title'] as String, content: json['content'] as String);

  final String id;
  final String title;
  final String content;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'content': content};
}

/// AI 가 나눈 경험 후보 (1-7). 저장 전이라 id 가 없다.
class ExperienceDraft {
  const ExperienceDraft({required this.title, required this.content});

  factory ExperienceDraft.fromJson(Map<String, dynamic> json) =>
      ExperienceDraft(title: json['title'] as String, content: json['content'] as String);

  final String title;
  final String content;

  Map<String, dynamic> toJson() => {'title': title, 'content': content};
}

String formatIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
