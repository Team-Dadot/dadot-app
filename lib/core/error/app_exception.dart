/// 앱 전체에서 쓰는 오류 타입. 화면은 [userMessage] 만 보여주면 된다.
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,

  /// 오늘 AI 피드백 횟수 소진
  feedbackQuotaExceeded,

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

  static String? submissionMessage(String? code) => switch (code) {
    'TASK_PROCESSING' => '이전 답변을 평가하고 있어요. 잠시 후 다시 확인해 주세요.',
    'DAILY_LIMIT_EXCEEDED' => '오늘 답변할 수 있는 횟수를 모두 사용했어요.',
    'QUESTION_LIMIT_EXCEEDED' => '이 질문의 답변 기회를 모두 사용했어요.',
    'COMPANY_INACTIVE' => '준비 기업에서 빠진 기업이라 답변할 수 없어요.',
    'CONTENT_UNAVAILABLE' || 'CONTEXT_UNAVAILABLE' => '현재 이 질문의 자료를 사용할 수 없어요.',
    'ANSWER_ALREADY_SUBMITTED' => '이미 제출한 답변이에요. 진행 상태를 다시 불러와 주세요.',
    'IDEMPOTENCY_KEY_EXPIRED' => '제출 확인 기한이 지났어요. 복습에서 기존 답변 기록을 먼저 확인해 주세요.',
    _ => null,
  };

  static String submissionHelp(String? code) => switch (code) {
    'QUESTION_LIMIT_EXCEEDED' => '같은 질문에는 누적 최대 3회 답변할 수 있어요. 다음 날에도 기회가 초기화되지 않아요.',
    'DAILY_LIMIT_EXCEEDED' => '일일 답변 한도는 다음 날 다시 확인해 주세요.',
    'TASK_PROCESSING' => '평가가 끝난 뒤 제출 가능 상태를 다시 확인해 주세요.',
    'COMPANY_INACTIVE' => '준비 기업 설정을 확인해 주세요.',
    'CONTENT_UNAVAILABLE' || 'CONTEXT_UNAVAILABLE' => '사용 가능한 다른 질문을 확인해 주세요.',
    _ => '제출 가능 상태를 다시 확인해 주세요.',
  };

  /// 영문 서버 오류·SDK 예외 원문은 사용자용 문구로 사용하지 않는다.
  static String? _displayMessage(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || !RegExp(r'[가-힣]').hasMatch(text)) return null;
    if (text.length > 300 || RegExp(
      r'Exception|\b[A-Za-z_$][\w.$]*Error\b|StackTrace|Traceback|#[0-9]+\s|(?:^|\n)\s*at\s',
      caseSensitive: false,
    ).hasMatch(text)) return null;
    return text;
  }

  String get userMessage {
    final known = submissionMessage(code);
    if (known != null) return known;
    final localized = _displayMessage(message);
    if (localized != null) return localized;
    return switch (kind) {
      AppErrorKind.network => '인터넷 연결을 확인해 주세요.',
      AppErrorKind.timeout => '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
      AppErrorKind.unauthorized => '다시 로그인해 주세요.',
      AppErrorKind.forbidden => '접근 권한이 없어요.',
      AppErrorKind.notFound => '요청한 정보를 찾을 수 없어요.',
      AppErrorKind.validation => '입력한 내용을 확인해 주세요.',
      AppErrorKind.feedbackQuotaExceeded => '답변할 수 있는 횟수를 모두 사용했어요.',
      AppErrorKind.contentNotReady => '오늘 내용을 준비 중이에요. 잠시 후 다시 확인해 주세요.',
      AppErrorKind.conflict => '정보가 먼저 바뀌었어요. 새로 불러온 뒤 다시 시도해 주세요.',
      AppErrorKind.server => '일시적인 오류가 생겼어요. 잠시 후 다시 시도해 주세요.',
      AppErrorKind.unknown => '알 수 없는 오류가 생겼어요.',
    };
  }

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
      case 'ANSWER_ALREADY_SUBMITTED':
        return AppErrorKind.conflict;
      case 'COMPANY_INACTIVE':
        return AppErrorKind.forbidden;
      case 'CONTENT_UNAVAILABLE':
      case 'CONTEXT_UNAVAILABLE':
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
      // 409 자체는 한도 소진을 뜻하지 않는다. 명시적인 서버 코드로 구분한다.
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
Object unwrapAppError(Object error) {
  if (error.runtimeType.toString() == 'ProviderException') {
    return unwrapAppError((error as dynamic).exception as Object);
  }
  return error;
}

AppException asAppException(Object error) {
  final cause = unwrapAppError(error);
  if (cause is AppException) return cause;
  return AppException(AppErrorKind.unknown, message: null, code: cause.runtimeType.toString());
}
