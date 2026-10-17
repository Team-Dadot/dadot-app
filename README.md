# 공시노트 (스와이프 7기) — 공시 퀴즈 + 면접 답변 연습 앱

관심 기업 공시 퀴즈(5문제 세트) + 공시·내 경험 기반 면접 답변 연습(AI 피드백 4개 항목, 글·말 답변 3분 권장).
Flutter 하나로 Android · iOS 동시 출시.

## 바로 실행 (백엔드 없이)

```bash
flutter pub get
flutter run            # 기본 Mock 모드: 앱 안의 가짜 서버로 전체 흐름 동작
```

VS Code: 실행 및 디버그 → `Mock (백엔드 없이)` 선택.
Mock 데이터는 기기에 저장된다. 처음부터 다시 보려면 마이 → `[개발] Mock 데이터 초기화`.

## 백엔드 붙이기

```bash
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://dev-api.example.com
```

- 요청·응답 형식: `docs/API_CONTRACT.md` (백엔드와 이 문서로 맞춘다)
- 경로가 다르면 `lib/core/network/api_paths.dart`, 키 이름이 다르면 `lib/data/models/*.dart` 의 fromJson 만 고친다.
- Android 에뮬레이터에서 내 맥의 서버: `http://10.0.2.2:8080`, iOS 시뮬레이터: `http://localhost:8080`

## 피그마 디자인 입히기

`docs/FIGMA_HANDOFF.md` 참고. 색·글자·간격은 `lib/design_system/tokens/` 만 바꾸면 전 화면에 반영된다.
화면 코드는 디자인 시스템 위젯(`AppButton`, `AppCard` …)만 쓰도록 만들어 두었다.

## 폴더 구조

```
lib/
  core/            설정·정책값·네트워크·저장소·세션·라우터·외부 서비스(STT, 푸시, 소셜 로그인)
  data/
    models/        서버 JSON ↔ 앱 모델
    repositories/  화면이 쓰는 인터페이스
    remote/        실제 백엔드 구현 (dio)
    mock/          가짜 서버 (개발·QA·디자인 확인용)
  design_system/   토큰 + 공통 위젯 (피그마 컴포넌트와 1:1)
  features/        화면 (S01~S13, 노션 화면 번호와 같음)
```

## 화면 ↔ 파일

피그마 "스위프 7기 > 와이어프레임" **완성본(10.17)** 프레임 번호 기준. 경로는 `lib/core/router/app_router.dart` 의 `Routes`.

| 피그마 | 파일 |
|---|---|
| [1-1] 시작 · 로그인 | features/auth/splash_screen.dart · login_screen.dart |
| [1-2] 첫 설정 STEP 1~4 (기업 · 직무 · 면접일 · 경험) | features/onboarding/onboarding_*_screen.dart |
| [1-2] 직무 선택 시트 | features/common/pickers.dart (`showJobPicker`) |
| [1-2] 알림 · 완료 | features/onboarding/onboarding_finish_screens.dart |
| [2-1] 홈 기본 · 기업 전환 · 오늘의 학습 완료 / [2-2] 면접 집중 모드 (D-3) | features/home/ |
| [3-1] 오늘의 퀴즈 · 결과(문제별 해설) · 공시 근거 | features/quiz/ · common/pickers.dart (`showEvidenceSheet`) |
| [4-1] 면접 질문 · 질문 생성 중 · 답변 작성(글/말) · 분석 중 · 답변 피드백 | features/interview/ |
| [5-1] 퀴즈 복습 · [5-2] 면접 복습 · 답변 피드백 | features/review/ |
| [6-1] 마이 홈 · [6-2] 준비 기업·지원 정보 · [6-3] 내 경험 · [6-4] 알림·문의·계정 | features/my/ |

예외·빈 화면·오류 프레임은 `design_system/widgets/state_views.dart` 의 공통 화면과 확인 팝업으로 처리했다.

## 확인

```bash
flutter analyze
flutter test
```

## 출시 전 할 일

`docs/RELEASE_CHECKLIST.md` (번들 ID, 서명, 카카오/Apple 로그인 SDK, FCM, 개인정보 등)
정책 값 중 팀 결정이 필요한 것은 코드에 `TODO(결정 N)` 으로 표시되어 있다 (`lib/core/config/app_policy.dart`).
