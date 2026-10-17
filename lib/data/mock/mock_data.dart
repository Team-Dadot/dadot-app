/// Mock 서버 시드 데이터. 화면 개발·QA·디자인 확인용이며 실제 서비스 콘텐츠가 아니다.
/// 기아 문항·근거는 피그마 와이어프레임 예시 문구를 그대로 옮긴 샘플이라 사실과 다를 수 있다.
/// 나머지 기업은 회사 이름만 바꿔 끼운 공통 샘플 문항을 쓴다.
library;

import '../models/catalog.dart';
import '../models/quiz.dart';

class MockQuizSeed {
  const MockQuizSeed({
    required this.id,
    required this.kind,
    required this.tags,
    required this.prompt,
    required this.title,
    required this.explanation,
    this.choices = const [],
    this.correctIndex = 0,
    this.keywords = const [],
    this.modelAnswer,
    this.placeholder,
    this.evidence,
  });

  final String id;
  final QuizKind kind;
  final List<String> tags;
  final String prompt;
  final String title;
  final String explanation;

  /// 객관식 보기 (A, B, C, D 순서 그대로)
  final List<String> choices;
  final int correctIndex;

  /// 주관식: 이 중 하나라도 들어가면 정답
  final List<String> keywords;
  final String? modelAnswer;
  final String? placeholder;
  final Evidence? evidence;

  String choiceId(int i) => '$id-c$i';
  String get correctChoiceId => choiceId(correctIndex);

  List<QuizChoice> get quizChoices => [for (var i = 0; i < choices.length; i++) QuizChoice(id: choiceId(i), text: choices[i])];

  QuizQuestion toQuestion(int order) => QuizQuestion(
        id: id,
        order: order,
        kind: kind,
        tags: tags,
        prompt: prompt,
        title: title,
        choices: quizChoices,
        placeholder: placeholder,
        evidence: evidence,
      );
}

class MockInterviewSeed {
  const MockInterviewSeed({required this.id, required this.text, required this.evidence, this.keywords = const []});

  final String id;

  /// {job} 은 지원 직무로 바뀐다
  final String text;
  final List<Evidence> evidence;

  /// 기업 정보 활용 점수에 쓰는 단어
  final List<String> keywords;
}

class MockData {
  MockData._();

  static const companies = <Company>[
    Company(id: 'kia', name: '기아', industry: '자동차'),
    Company(id: 'lg', name: 'LG전자', industry: '전자·가전'),
    Company(id: 'cj', name: 'CJ제일제당', industry: '식품'),
    Company(id: 'naver', name: '네이버', industry: 'IT·플랫폼'),
    Company(id: 'samsung', name: '삼성전자', industry: '전자·반도체'),
    Company(id: 'hyundai', name: '현대자동차', industry: '자동차'),
    Company(id: 'skhynix', name: 'SK하이닉스', industry: '반도체'),
    Company(id: 'lges', name: 'LG에너지솔루션', industry: '배터리'),
    Company(id: 'kakao', name: '카카오', industry: 'IT·플랫폼'),
    Company(id: 'coupang', name: '쿠팡', industry: '유통·커머스'),
    Company(id: 'toss', name: '토스', industry: '핀테크'),
    Company(id: 'posco', name: '포스코', industry: '철강'),
  ];

  static Company company(String id) => companies.firstWhere((c) => c.id == id, orElse: () => Company(id: id, name: id));

  // ---------------------------------------------------------------- 직무

  static const jobCatalog = JobCatalog(
    popular: [
      Job(id: 'sales', name: '영업'),
      Job(id: 'marketing', name: '마케팅'),
      Job(id: 'strategy', name: '경영기획·전략'),
      Job(id: 'hr', name: '인사·HR'),
      Job(id: 'finance', name: '재무·회계'),
      Job(id: 'scm', name: '구매·SCM'),
    ],
    categories: [
      JobCategory(id: 'plan', name: '기획·전략', jobs: [
        Job(id: 'strategy', name: '경영기획·전략'),
        Job(id: 'service-plan', name: '서비스기획'),
        Job(id: 'product-plan', name: '상품기획·MD'),
        Job(id: 'new-biz', name: '신사업'),
      ]),
      JobCategory(id: 'mkt', name: '마케팅·홍보', jobs: [
        Job(id: 'marketing', name: '마케팅'),
        Job(id: 'brand', name: '브랜드마케팅'),
        Job(id: 'digital-mkt', name: '디지털마케팅'),
        Job(id: 'pr', name: '홍보·PR'),
      ]),
      JobCategory(id: 'sales-trade', name: '영업·무역', jobs: [
        Job(id: 'b2b', name: 'B2B영업'),
        Job(id: 'b2c', name: 'B2C영업'),
        Job(id: 'overseas', name: '해외영업'),
        Job(id: 'sales-mgmt', name: '영업관리'),
        Job(id: 'trade', name: '무역'),
        Job(id: 'sales', name: '영업'),
      ]),
      JobCategory(id: 'support', name: '경영지원', jobs: [
        Job(id: 'hr', name: '인사·HR'),
        Job(id: 'finance', name: '재무·회계'),
        Job(id: 'scm', name: '구매·SCM'),
        Job(id: 'legal', name: '법무'),
        Job(id: 'ga', name: '총무'),
      ]),
      JobCategory(id: 'tech', name: 'IT·개발', jobs: [
        Job(id: 'dev', name: '개발'),
        Job(id: 'data', name: '데이터'),
        Job(id: 'design', name: '디자인'),
      ]),
    ],
  );

  // ---------------------------------------------------------------- 근거

  static const _dartUrl = 'https://dart.fss.or.kr';

  static const kiaReport = Evidence(
    title: '기아 2025 사업보고서',
    publishedAt: '2026.03.12',
    period: '2025.01.01 – 2025.12.31',
    excerpt: '당사는 전기차 라인업 확대에 따라 전기차 판매 비중이 전년 대비 증가하였으며, 향후 목적 기반 모빌리티(PBV) 사업을 중점적으로 확대할 계획입니다.',
    url: _dartUrl,
    interpretation: '전기차가 차지하는 판매 비중이 전년보다 커졌다는 뜻이에요.',
  );

  static const kiaReportShort = Evidence(
    title: '기아 2025 사업보고서',
    publishedAt: '2026.03.12',
    period: '2025.01.01 – 2025.12.31',
    excerpt: '전기차 판매 비중이 전년 대비 증가했으며, 향후 목적 기반 모빌리티(PBV) 사업을 중점적으로 확대할 계획이에요.',
    url: _dartUrl,
  );

  static Evidence genericReport(Company c) => Evidence(
        title: '[샘플] ${c.name} 2025 사업보고서',
        publishedAt: '2026.03.12',
        period: '2025.01.01 – 2025.12.31',
        excerpt: '[샘플] ${c.name}의 사업보고서 “사업의 내용”과 “이사의 경영진단 및 분석의견”에서 주요 사업과 다음 해 계획을 확인할 수 있어요.',
        url: _dartUrl,
      );

  // ---------------------------------------------------------------- 퀴즈

  static const kiaQuiz = <MockQuizSeed>[
    MockQuizSeed(
      id: 'kia-q1',
      kind: QuizKind.choice,
      tags: ['실적'],
      prompt: '기아의 2025년 전기차 판매량은 전년 대비 어떻게 변했나요?',
      title: '전기차 판매량 변화',
      choices: ['크게 줄었다', '비슷했다', '늘었다', '공시에 나와 있지 않다'],
      correctIndex: 2,
      explanation: '사업보고서에서 전기차 판매 비중이 늘었다고 설명해요. 면접에서는 “전동화 전환 속도”와 연결해 말하기 좋아요.',
      evidence: kiaReport,
    ),
    MockQuizSeed(
      id: 'kia-q2',
      kind: QuizKind.choice,
      tags: ['위험 요인'],
      prompt: '기아의 주요 위험 요인은 무엇인가요?',
      title: '주요 위험 요인',
      choices: ['환율·원자재 가격 변동', '신규 상장 일정', '대표이사 교체', '공시에 나와 있지 않다'],
      correctIndex: 0,
      explanation: '환율 변동과 원자재 가격 변동을 주요 위험 요인으로 설명해요.',
      evidence: kiaReport,
    ),
    MockQuizSeed(
      id: 'kia-q3',
      kind: QuizKind.choice,
      tags: ['공시 읽기'],
      prompt: '공시일과 대상 기간은 어떻게 이해해야 할까요?',
      title: '공시일과 대상 기간',
      choices: ['항상 같은 날이다', '발표한 날짜와 자료가 설명하는 기간은 다를 수 있다', '대상 기간이 항상 더 늦다', '공시일만 보면 된다'],
      correctIndex: 1,
      explanation: '공시를 발표한 날짜와 자료가 설명하는 기간은 다를 수 있어요.',
      evidence: kiaReport,
    ),
    MockQuizSeed(
      id: 'kia-q4',
      kind: QuizKind.choice,
      tags: ['사업 구조'],
      prompt: '사업보고서 기준, 기아의 핵심 사업 부문은?',
      title: '핵심 사업 부문',
      choices: ['금융 부문', '자동차 부문', '건설 부문', '반도체 부문'],
      correctIndex: 1,
      explanation: '기아 매출의 대부분은 완성차를 만들고 파는 자동차 부문에서 나와요.',
      evidence: kiaReport,
    ),
    MockQuizSeed(
      id: 'kia-s1',
      kind: QuizKind.short,
      tags: ['사업 계획'],
      prompt: '기아가 공시에서 밝힌 향후 중점 사업 한 가지를 적어 주세요.',
      title: '향후 중점 사업',
      placeholder: '예: 목적 기반 모빌리티(PBV) 사업 확대',
      keywords: ['PBV', '목적기반', '목적 기반', '모빌리티'],
      modelAnswer: '목적 기반 모빌리티(PBV) 사업 확대',
      explanation: '사업보고서에서 목적 기반 모빌리티(PBV) 사업을 중점적으로 확대할 계획이라고 밝혔어요.',
      evidence: kiaReport,
    ),
    MockQuizSeed(
      id: 'kia-s2',
      kind: QuizKind.short,
      tags: ['제품·서비스'],
      prompt: '기아의 주요 제품·서비스를 한 가지 적어 주세요.',
      title: '주요 제품·서비스',
      placeholder: '예: 전기차',
      keywords: ['전기차', 'EV', '자동차', '완성차', 'SUV', '승용', 'PBV'],
      modelAnswer: '완성차(전기차·SUV 등)',
      explanation: '기아는 승용차·SUV·전기차 같은 완성차를 만들어 팔아요.',
      evidence: kiaReport,
    ),
  ];

  static List<MockQuizSeed> genericQuiz(Company c) {
    final ev = genericReport(c);
    return [
      MockQuizSeed(
        id: '${c.id}-q1',
        kind: QuizKind.choice,
        tags: ['공시 읽기'],
        prompt: '[샘플] ${c.name}의 사업보고서를 볼 수 있는 공식 공시 사이트는?',
        title: '공시 사이트',
        choices: ['회사 블로그', 'DART 전자공시시스템', '취업 커뮤니티', '포털 지식검색'],
        correctIndex: 1,
        explanation: '상장사의 사업보고서·분기보고서는 금융감독원 DART 에서 무료로 볼 수 있어요.',
        evidence: ev,
      ),
      MockQuizSeed(
        id: '${c.id}-q2',
        kind: QuizKind.choice,
        tags: ['실적'],
        prompt: '[샘플] 매출액에서 매출원가를 뺀 값은?',
        title: '매출총이익',
        choices: ['영업이익', '당기순이익', '매출총이익', '영업외수익'],
        correctIndex: 2,
        explanation: '매출총이익 = 매출액 − 매출원가. 여기서 판매비와 관리비를 더 빼면 영업이익이에요.',
        evidence: ev,
      ),
      MockQuizSeed(
        id: '${c.id}-q3',
        kind: QuizKind.choice,
        tags: ['공시 읽기'],
        prompt: '[샘플] 사업보고서에서 경영진이 직접 실적과 전망을 설명하는 항목은?',
        title: '경영진 의견 항목',
        choices: ['감사인의 감사의견', '이사의 경영진단 및 분석의견', '주주에 관한 사항', '임원의 보수'],
        correctIndex: 1,
        explanation: '‘이사의 경영진단 및 분석의견’에는 회사가 스스로 본 실적 요인과 다음 해 계획이 들어 있어요.',
        evidence: ev,
      ),
      MockQuizSeed(
        id: '${c.id}-q4',
        kind: QuizKind.choice,
        tags: ['실적'],
        prompt: '[샘플] 영업이익률을 구하는 식은?',
        title: '영업이익률',
        choices: ['영업이익 ÷ 매출액', '순이익 ÷ 자본', '매출액 ÷ 자산', '부채 ÷ 자본'],
        correctIndex: 0,
        explanation: '영업이익률은 본업으로 얼마나 효율적으로 돈을 버는지 보여줘요.',
        evidence: ev,
      ),
      MockQuizSeed(
        id: '${c.id}-s1',
        kind: QuizKind.short,
        tags: ['사업 계획'],
        prompt: '[샘플] ${c.name}의 주요 사업 부문 한 가지를 적어 주세요.',
        title: '주요 사업 부문',
        placeholder: '예: ${c.industry ?? '주요 사업'}',
        keywords: [?c.industry?.split('·').first, '사업'],
        modelAnswer: c.industry,
        explanation: '사업보고서 “사업의 내용”에 부문별 매출과 주요 제품이 나와 있어요.',
        evidence: ev,
      ),
      MockQuizSeed(
        id: '${c.id}-s2',
        kind: QuizKind.short,
        tags: ['공시 읽기'],
        prompt: '[샘플] 상장사 공시를 볼 수 있는 금융감독원 사이트 이름을 적어 주세요.',
        title: '공시 사이트 이름',
        placeholder: '예: ○○○ 전자공시시스템',
        keywords: ['DART', '다트', '전자공시'],
        modelAnswer: 'DART 전자공시시스템',
        explanation: '금융감독원 DART(dart.fss.or.kr)에서 상장사 공시를 볼 수 있어요.',
        evidence: ev,
      ),
    ];
  }

  static List<MockQuizSeed> quizBank(String companyId) => companyId == 'kia' ? kiaQuiz : genericQuiz(company(companyId));

  // ---------------------------------------------------------------- 면접 질문

  static const kiaInterview = <MockInterviewSeed>[
    MockInterviewSeed(
      id: 'kia-i1',
      text: '기아에 지원한 이유를 {job} 직무와 연결해 말해 주세요.',
      evidence: [kiaReportShort],
      keywords: ['전동화', '전기차', 'PBV', '모빌리티'],
    ),
    MockInterviewSeed(
      id: 'kia-i2',
      text: '기아의 주요 사업을 설명하고, {job}(으)로서 어떻게 기여할 수 있을지 말해 주세요.',
      evidence: [kiaReportShort],
      keywords: ['자동차', '전기차', 'PBV', 'SUV'],
    ),
    MockInterviewSeed(
      id: 'kia-i3',
      text: '기아가 공시에서 밝힌 향후 계획을 보고, 입사 후 해보고 싶은 일을 말해 주세요.',
      evidence: [kiaReportShort],
      keywords: ['PBV', '모빌리티', '확대', '전동화'],
    ),
    MockInterviewSeed(
      id: 'kia-i4',
      text: '기아의 주요 위험 요인 중 하나를 골라, {job} 관점에서 대응 방안을 말해 주세요.',
      evidence: [kiaReportShort],
      keywords: ['환율', '원자재', '위험'],
    ),
  ];

  static List<MockInterviewSeed> genericInterview(Company c) {
    final ev = [genericReport(c)];
    return [
      MockInterviewSeed(id: '${c.id}-i1', text: '[샘플] ${c.name}에 지원한 이유를 {job} 직무와 연결해 말해 주세요.', evidence: ev, keywords: [c.name]),
      MockInterviewSeed(id: '${c.id}-i2', text: '[샘플] ${c.name}의 주요 사업을 설명하고, {job}(으)로서 기여할 점을 말해 주세요.', evidence: ev, keywords: [c.name]),
      MockInterviewSeed(id: '${c.id}-i3', text: '[샘플] 입사 후 3년 안에 ${c.name}에서 이루고 싶은 목표는 무엇인가요?', evidence: ev, keywords: [c.name]),
      MockInterviewSeed(id: '${c.id}-i4', text: '[샘플] ${c.name}가 당신을 뽑아야 하는 이유는 무엇인가요?', evidence: ev, keywords: [c.name]),
    ];
  }

  static List<MockInterviewSeed> interviewBank(String companyId) =>
      companyId == 'kia' ? kiaInterview : genericInterview(company(companyId));
}
