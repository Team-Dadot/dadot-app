/// 응답 유실 시에도 동일한 논리 제출의 키·본문을 유지한다.
class PendingInterviewSubmission {
  const PendingInterviewSubmission({
    required this.idempotencyKey,
    required this.body,
    this.attemptId,
    this.accepted,
  });

  factory PendingInterviewSubmission.fromJson(Map<String, dynamic> json) => PendingInterviewSubmission(
    idempotencyKey: json['idempotencyKey'] as String,
    body: (json['body'] as Map).cast<String, dynamic>(),
    attemptId: json['attemptId'] as String?,
    accepted: (json['accepted'] as Map?)?.cast<String, dynamic>(),
  );

  final String idempotencyKey;
  final Map<String, dynamic> body;
  final String? attemptId;
  final Map<String, dynamic>? accepted;
  String get text => body['text'] as String;

  PendingInterviewSubmission withAccepted(String id, Map<String, dynamic> data) => PendingInterviewSubmission(
    idempotencyKey: idempotencyKey,
    body: body,
    attemptId: id,
    accepted: data,
  );

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'body': body,
    'attemptId': attemptId,
    'accepted': accepted,
  };
}
