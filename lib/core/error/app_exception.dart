/// 앱 전체에서 쓰는 오류 타입. 화면은 [userMessage] 만 보여주면 된다.
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,

  /// 답변 기회 소진 (질문별 3회 QUESTION_LIMIT_EXCEEDED · 기업별 오늘 한도 DAILY_LIMIT_EXCEEDED)
  feedbackQuotaExceeded,

  /// 지금은 답변 제출이 막힘 (평가 진행 중 TASK_PROCESSING · 기업 비활성 COMPANY_INACTIVE · 근거 없음 CONTENT_UNAVAILABLE)
  submitBlocked,

  /// 오늘 퀴즈·질문이 아직 준비되지 않음
  contentNotReady,

  /// 다른 곳에서 먼저 바뀜 (409 VERSION_CONFLICT · IDEMPOTENCY_CONFLICT)
  conflict,
  server,
  unknown,
}

class AppException implements Exception {
  const AppException(this.kind, {this.message, this.statusCode, this.code});

  final AppErrorKind kind;

  /// 서버가 준 사용자용 메시지 (있으면 우선)
  final String? message;
  final int? statusCode;

  /// 서버 오류 코드 (예: FEEDBACK_QUOTA_EXCEEDED)
  final String? code;

  String get userMessage {
    if (kind == AppErrorKind.feedbackQuotaExceeded || kind == AppErrorKind.submitBlocked) {
      return submitBlockText(code).title;
    }
    if (message != null && message!.isNotEmpty) return message!;
    return switch (kind) {
      AppErrorKind.network => '인터넷 연결을 확인해 주세요.',
      AppErrorKind.timeout => '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
      AppErrorKind.unauthorized => '다시 로그인해 주세요.',
      AppErrorKind.forbidden => '접근 권한이 없어요.',
      AppErrorKind.notFound => '요청한 정보를 찾을 수 없어요.',
      AppErrorKind.validation => '입력한 내용을 확인해 주세요.',
      AppErrorKind.feedbackQuotaExceeded || AppErrorKind.submitBlocked => submitBlockText(code).title,
      AppErrorKind.contentNotReady => '오늘 내용을 준비 중이에요. 잠시 후 다시 확인해 주세요.',
      AppErrorKind.conflict => '정보가 먼저 바뀌었어요. 새로 불러온 뒤 다시 시도해 주세요.',
      AppErrorKind.server => '일시적인 오류가 생겼어요. 잠시 후 다시 시도해 주세요.',
      AppErrorKind.unknown => '알 수 없는 오류가 생겼어요.',
    };
  }

  /// 서버가 답변 제출을 막은 이유(usage.blockedReason · 오류 코드)별 안내 — 제목 · 한 줄 설명.
  /// 질문별 3회는 날짜가 바뀌어도 다시 생기지 않는다(서버 누적) → "내일" 이라고 하지 않는다.
  static ({String title, String message}) submitBlockText(String? reason) => switch (reason) {
        'DAILY_LIMIT_EXCEEDED' => (title: '오늘 이 기업의 학습 한도를 모두 사용했어요', message: '내일 다시 이용해 주세요.'),
        'TASK_PROCESSING' => (title: '이전 답변을 평가하고 있어요', message: '잠시 후 결과를 확인해 주세요.'),
        'COMPANY_INACTIVE' => (title: '준비 기업에서 빠진 기업이에요', message: '마이 > 준비 기업에서 다시 추가하면 답변할 수 있어요.'),
        'CONTENT_UNAVAILABLE' => (title: '지금은 이 질문에 답변할 수 없어요', message: '질문의 공시 근거를 쓸 수 없게 됐어요. 다른 질문으로 학습해 주세요.'),
        _ => (title: '이 질문의 답변 기회를 모두 사용했어요', message: '복습 탭에서 지난 평가를 다시 볼 수 있어요.'),
      };

  /// 다시 시도하면 해결될 수 있는 오류인지
  bool get isRetryable =>
      kind == AppErrorKind.network || kind == AppErrorKind.timeout || kind == AppErrorKind.server;

  /// 서버 오류 코드 → 종류 매핑. 백엔드와 API_CONTRACT.md 의 코드를 맞춘다.
  static AppErrorKind kindFromCode(String? code, int? status) {
    switch (code) {
      case 'FEEDBACK_QUOTA_EXCEEDED':
      case 'QUESTION_LIMIT_EXCEEDED':
      case 'DAILY_LIMIT_EXCEEDED':
        return AppErrorKind.feedbackQuotaExceeded;
      case 'TASK_PROCESSING':
      case 'COMPANY_INACTIVE':
      case 'CONTENT_UNAVAILABLE':
        return AppErrorKind.submitBlocked;
      case 'CONTENT_NOT_READY':
        return AppErrorKind.contentNotReady;
      case 'VALIDATION_ERROR':
      case 'INVALID_INPUT':
        return AppErrorKind.validation;
      case 'UNAUTHENTICATED':
        return AppErrorKind.unauthorized;
      case 'FORBIDDEN':
        return AppErrorKind.forbidden;
      case 'RESOURCE_NOT_FOUND':
        return AppErrorKind.notFound;
      case 'VERSION_CONFLICT':
      case 'IDEMPOTENCY_CONFLICT':
      case 'IDEMPOTENCY_KEY_EXPIRED':
        return AppErrorKind.conflict;
      case 'SERVICE_UNAVAILABLE':
      case 'INTERNAL_SERVER_ERROR':
      case 'RATE_LIMIT_EXCEEDED':
        return AppErrorKind.server;
    }
    return switch (status) {
      400 || 422 => AppErrorKind.validation,
      401 => AppErrorKind.unauthorized,
      403 => AppErrorKind.forbidden,
      404 => AppErrorKind.notFound,
      // 한도·제출 불가는 위에서 코드로 가른다. 코드를 모르는 409 는 "먼저 바뀜" (예전엔 전부 소진으로 봤다)
      409 => AppErrorKind.conflict,
      429 => AppErrorKind.server,
      final s? when s >= 500 => AppErrorKind.server,
      _ => AppErrorKind.unknown,
    };
  }

  @override
  String toString() => 'AppException($kind, status=$statusCode, code=$code, message=$message)';
}

/// 아무 오류나 AppException 으로 바꾼다.
/// Riverpod 3 은 provider 안의 오류를 ProviderException 으로 감싸는데, 이 타입은
/// flutter_riverpod 의 공개 API 로 export 되지 않으므로 런타임 타입 이름으로 구분해 벗긴다.
AppException asAppException(Object error) {
  if (error.runtimeType.toString() == 'ProviderException') {
    return asAppException((error as dynamic).exception as Object);
  }
  if (error is AppException) return error;
  return AppException(AppErrorKind.unknown, message: null, code: error.runtimeType.toString());
}
