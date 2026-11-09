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

  String get userMessage {
    if (message != null && message!.isNotEmpty) return message!;
    return switch (kind) {
      AppErrorKind.network => '인터넷 연결을 확인해 주세요.',
      AppErrorKind.timeout => '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
      AppErrorKind.unauthorized => '다시 로그인해 주세요.',
      AppErrorKind.forbidden => '접근 권한이 없어요.',
      AppErrorKind.notFound => '요청한 정보를 찾을 수 없어요.',
      AppErrorKind.validation => '입력한 내용을 확인해 주세요.',
      AppErrorKind.feedbackQuotaExceeded => '오늘 답변할 수 있는 횟수를 모두 사용했어요. 내일 다시 할 수 있어요.',
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
      // 다닷 서버: 일일/질문 한도 소진은 409 (트래픽 제한 429 와 구분)
      409 => AppErrorKind.feedbackQuotaExceeded,
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
