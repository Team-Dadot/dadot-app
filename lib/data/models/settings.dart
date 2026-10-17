/// 학습 알림 (6-9)
class NotificationSettings {
  const NotificationSettings({required this.enabled, required this.hour, required this.minute});

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final time = (json['time'] as String? ?? '09:00').split(':');
    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      hour: int.tryParse(time.first) ?? 9,
      minute: time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0,
    );
  }

  final bool enabled;
  final int hour;
  final int minute;

  /// "오전 9:00"
  String get timeLabel {
    final period = hour < 12 ? '오전' : '오후';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$period $h12:${minute.toString().padLeft(2, '0')}';
  }

  /// 마이 화면 "매일 오전 9시 · 켜짐"
  String get summary {
    final period = hour < 12 ? '오전' : '오후';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final time = minute == 0 ? '$period $h12시' : '$period $h12시 $minute분';
    return '매일 $time · ${enabled ? '켜짐' : '꺼짐'}';
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'time': '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      };

  NotificationSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      NotificationSettings(enabled: enabled ?? this.enabled, hour: hour ?? this.hour, minute: minute ?? this.minute);
}

enum InquiryType {
  service('SERVICE', '서비스 문의'),
  quizError('QUIZ_ERROR', '퀴즈·공시 오류 제보'),
  interviewError('INTERVIEW_ERROR', '면접·피드백 오류 제보');

  const InquiryType(this.wire, this.label);
  final String wire;
  final String label;

  static InquiryType fromWire(String? v) => InquiryType.values.firstWhere((e) => e.wire == v, orElse: () => InquiryType.service);
}

/// 접수 내역 한 건
class Inquiry {
  const Inquiry({required this.id, required this.type, required this.content, required this.createdAt, required this.statusLabel});

  factory Inquiry.fromJson(Map<String, dynamic> json) => Inquiry(
        id: json['id'].toString(),
        type: InquiryType.fromWire(json['type'] as String?),
        content: json['content'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        statusLabel: json['statusLabel'] as String? ?? '접수됨',
      );

  final String id;
  final InquiryType type;
  final String content;
  final DateTime createdAt;

  /// 접수됨 / 답변 완료
  final String statusLabel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wire,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'statusLabel': statusLabel,
      };
}
