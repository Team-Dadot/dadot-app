import 'package:url_launcher/url_launcher.dart';

/// 원문 링크 · 약관 · 앱 설정 열기
class LinkService {
  const LinkService();

  /// 외부 브라우저로 연다. 실패하면 false.
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 휴대폰 설정 > 이 앱 화면 (마이크·알림 권한을 켜러 갈 때). iOS 는 app-settings: 로 열리고, 못 열면 false.
  Future<bool> openAppSettings() async {
    try {
      return await launchUrl(Uri.parse('app-settings:'));
    } catch (_) {
      return false;
    }
  }

  /// 문의 메일 (서버 문의 API 가 없을 때 대체)
  Future<bool> email(String to, {String? subject}) async {
    final uri = Uri(scheme: 'mailto', path: to, query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}');
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
