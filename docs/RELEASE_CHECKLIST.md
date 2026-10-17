# 출시 체크리스트 (Android · iOS)

## 1. 앱 기본 정보
- [ ] 번들 ID 변경: 지금 `com.example.swipe` → 스토어에서 거부됨
  - Android: `android/app/build.gradle.kts` 의 `namespace`, `applicationId` (+ MainActivity 패키지 경로)
  - iOS: Xcode > Runner > Signing & Capabilities > Bundle Identifier
- [ ] 앱 이름: Android `AndroidManifest.xml` `android:label`, iOS `Info.plist` `CFBundleDisplayName`
- [ ] 버전: `pubspec.yaml` `version: 1.0.0+1` (+ 뒤 빌드번호는 업로드마다 올리기)
- [ ] 앱 아이콘 · 스플래시 (FIGMA_HANDOFF.md 4장)

## 2. 로그인 SDK (지금은 FakeSocialAuthService)
- [ ] 카카오: `kakao_flutter_sdk_user` + 네이티브 앱 키, Android 키 해시, iOS URL scheme `kakao{앱키}`
- [ ] Apple: `sign_in_with_apple` + Xcode Capability "Sign in with Apple"
  - iOS 에서 카카오 등 다른 소셜 로그인을 제공하면 Apple 로그인도 함께 요구받을 수 있음 (App Review 4.8) → `AppPolicy.loginProvidersIos`
- [ ] `SocialAuthService` 구현 → `core/providers.dart` 의 `socialAuthServiceProvider` 교체
- [ ] 회원 탈퇴 시 Apple 토큰 철회(revoke)는 서버에서 (authorizationCode 전달 중)

## 3. 푸시 (지금은 NoopPushService)
- [ ] Firebase 프로젝트, `flutterfire configure` (google-services.json / GoogleService-Info.plist)
- [ ] iOS: APNs 키 등록, Capability "Push Notifications" + "Background Modes > Remote notifications"
- [ ] `PushService` 구현 → `pushServiceProvider` 교체, 알림 클릭 시 `data.route` 로 이동

## 4. 권한 문구 (넣어 둠)
- [x] Android: INTERNET, RECORD_AUDIO, POST_NOTIFICATIONS, RecognitionService/https queries
- [x] iOS: NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
- [ ] Android 음성 인식: 기기에 Google 앱(음성 인식 서비스) 필요 — 없으면 앱이 "글로 답변" 안내

## 5. 스토어 심사 · 개인정보
- [x] 앱 안에서 회원 탈퇴 (마이 > 계정 관리)
- [ ] 개인정보처리방침 · 이용약관 URL → `--dart-define=PRIVACY_POLICY_URL=... TERMS_URL=...`
- [ ] Google Play 데이터 보안 양식: 계정 정보, 음성(기기에서 글자 변환, 서버 미전송), 자소서·경험(사용자 입력), 앱 활동
- [ ] App Store 개인정보 라벨 + Privacy Manifest(PrivacyInfo.xcprivacy) — 사용하는 패키지의 manifest 포함 여부 확인
- [ ] 수출 규정: `ITSAppUsesNonExemptEncryption = false` (HTTPS 만 쓰는 경우, 넣어 둠)
- [ ] 심사용 테스트 계정 / 데모 영상 (소셜 로그인만 있으면 심사 노트에 방법 안내)

## 6. 빌드 · 서명
- [ ] Android: 업로드 키스토어 만들고 `build.gradle.kts` release signingConfig (지금은 debug 키)
- [ ] `flutter build appbundle --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://api...`
- [ ] iOS: Apple Developer 팀 선택, `flutter build ipa --dart-define=...`
- [ ] **릴리스 빌드에서 USE_MOCK=false 꼭 확인** (기본값이 Mock)

## 7. 팀 결정 대기 (코드에 TODO(결정 N))
로그인 수단, 경험 글자수, 최소 답변 글자수, 하루 피드백 횟수, 부분 충족 점수 → `lib/core/config/app_policy.dart`
