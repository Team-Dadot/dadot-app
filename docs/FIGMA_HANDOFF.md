# 피그마 → 코드 반영 가이드

화면 코드는 색·글자·간격 숫자를 직접 쓰지 않고 **토큰과 공통 위젯만** 쓴다.
그래서 디자인이 나오면 아래 순서로 바꾸면 된다. 화면 로직(API·상태·예외 처리)은 그대로 둔다.

## 1. 토큰 (전체 화면에 한 번에 반영)

| 피그마 | 코드 |
|---|---|
| Color styles / Variables | `lib/design_system/tokens/app_colors.dart` |
| Text styles | `lib/design_system/tokens/app_typography.dart` |
| Spacing · Radius · 크기 | `lib/design_system/tokens/app_spacing.dart` |
| 폰트 파일 | `assets/fonts/` + `pubspec.yaml` fonts 주석 해제 + `AppTypography.fontFamily` |

토큰 이름이 피그마와 다르면 **코드 쪽 이름은 두고 값만** 바꾸는 걸 추천 (화면 코드 수정이 필요 없음).

## 2. 컴포넌트

| 피그마 컴포넌트 | 코드 위젯 | 파일 |
|---|---|---|
| Button (primary / secondary / text / danger, small) | `AppButton` | widgets/app_button.dart |
| 하단 고정 버튼 영역 | `BottomCta` | widgets/app_button.dart |
| Card | `AppCard` | widgets/app_card.dart |
| Input / Textarea (+ 글자수) | `AppTextField` | widgets/app_text_field.dart |
| 선택 타일 (직무·기업·퀴즈 보기: 기본/선택/정답/오답) | `SelectableTile` | widgets/selectable_tile.dart |
| Chip (기업 탭·필터) | `AppFilterChip` | widgets/selectable_tile.dart |
| Top bar | `AppTopBar` | widgets/misc.dart |
| Bottom navigation (4탭) | `AppBottomNav` | widgets/app_bottom_nav.dart |
| Badge (출처·유형·D-Day·복습 완료) | `TagBadge` (.warning/.neutral/.success) | widgets/misc.dart |
| 안내 박스 | `NoticeBox` | widgets/misc.dart |
| 설정 목록 행 | `SettingsRow` | widgets/misc.dart |
| Progress bar / 원형 % / 온보딩 단계 | `AppProgressBar` / `PercentRing` / `StepIndicator` | widgets/progress.dart |
| 로딩 · 오류 · 빈 화면 | `LoadingView` / `ErrorView` / `EmptyView` | widgets/state_views.dart |
| 팝업 · 토스트 | `showConfirmDialog` / `showToast` | widgets/dialogs.dart |

컴포넌트 모양이 바뀌면 해당 위젯 파일 하나만 고치면 모든 화면에 반영된다.

## 3. 화면 배치

화면별 파일은 README 의 "화면 ↔ 파일" 표 참고. 배치만 바꿀 때는 각 화면의 `build` 안 위젯 순서·간격만 바꾸고,
`ref.watch(...)`, `_submit()` 같은 데이터·이벤트 코드는 건드리지 않는다.

`TODO(디자인)` 주석이 있는 곳: 로고·일러스트 자리 (스플래시, 로그인).

## 4. 아이콘 · 이미지

- 현재는 Material Icons. 피그마 아이콘이 SVG 면 `flutter_svg` 추가 후 교체.
- 앱 아이콘: `flutter_launcher_icons`, 스플래시: `flutter_native_splash` 추천.

## 5. 디자이너에게 받아야 할 상태

각 화면마다: 기본 / 로딩 / 빈 상태 / 오류 / (해당 시) 비활성 버튼.
특수 상태: 퀴즈 정답·오답 표시, 피드백 기준 충족·부분·미충족, 음성 녹음 중, 피드백 횟수 소진, 콘텐츠 준비 중, 주말 복습 세트.
