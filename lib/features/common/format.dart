/// 화면에 쓰는 날짜·시간 표기 (피그마 문구 기준)
library;

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026.10.24
String formatDot(DateTime d) => '${d.year}.${_two(d.month)}.${_two(d.day)}';

/// 2026. 10. 24.
String formatDotSpaced(DateTime d) => '${d.year}. ${d.month}. ${d.day}.';

/// 10월 24일 (토)
String formatMonthDayWeek(DateTime d) => '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';

/// 10.14
String formatShort(DateTime d) => '${_two(d.month)}.${_two(d.day)}';

/// 10.14 오후 2:10
String formatShortTime(DateTime d) {
  final period = d.hour < 12 ? '오전' : '오후';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${formatShort(d)} $period $h12:${_two(d.minute)}';
}

/// D-10 / D-Day / D+2
String formatDday(int dday) => dday == 0 ? 'D-Day' : dday > 0 ? 'D-$dday' : 'D+${-dday}';

/// 00:42
String formatClock(Duration d) => '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';

/// 마케팅 · D-10 / 마케팅 · 면접일 미정
String prepSubtitle({String? jobName, int? dday, DateTime? date, bool showDate = false}) {
  final job = (jobName ?? '').isEmpty ? '직무 미정' : jobName!;
  if (date == null) return '$job · 면접일 미정';
  return '$job · ${showDate ? formatDot(date) : formatDday(dday ?? 0)}';
}
