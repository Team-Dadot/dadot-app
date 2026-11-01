# API 계약서 (앱 ↔ 백엔드)

앱 코드 기준: `lib/core/network/api_paths.dart`, `lib/data/models/*.dart`, `lib/data/remote/remote_repositories.dart`.
백엔드와 다르게 정하면 이 문서와 위 파일을 같이 고친다.

## 공통

- Base URL: `--dart-define=API_BASE_URL` (끝에 `/` 없이)
- 인증: `Authorization: Bearer <accessToken>` (로그인·토큰 갱신 제외)
- JSON, UTF-8. 날짜: `2026-10-11` (날짜만) / ISO-8601 (시각 포함)
- ID 는 문자열 또는 숫자 모두 받는다 (앱에서 문자열로 바꿈)
- 목록 응답: 배열 그대로 또는 `{ "items": [...] }` 둘 다 가능
- 오류 응답: `{ "code": "FEEDBACK_QUOTA_EXCEEDED", "message": "사용자에게 보여줄 문장(선택)" }`

| 상황 | HTTP | code |
|---|---|---|
| 입력값 오류 | 400 / 422 | `VALIDATION_ERROR` |
| 토큰 만료 | 401 | – (앱이 `/auth/refresh` 로 1번 갱신 후 재시도, 실패 시 로그인 화면) |
| 없음 | 404 | – |
| 오늘 AI 피드백 횟수 소진 | 429 | `FEEDBACK_QUOTA_EXCEEDED` |
| 오늘 콘텐츠 준비 전 | 409 | `CONTENT_NOT_READY` |
| 서버 오류 | 5xx | – |

## 인증

### POST /auth/social
```json
요청 { "provider": "KAKAO | APPLE | GOOGLE", "token": "SDK 토큰", "authorizationCode": "Apple 만" }
응답 { "accessToken": "...", "refreshToken": "...", "isNewUser": true, "user": User }
```
### POST /auth/refresh
`{ "refreshToken": "..." }` → `{ "accessToken": "...", "refreshToken": "..." }`
### POST /auth/logout → 204
### DELETE /me → 204 (회원 탈퇴: 모든 데이터 삭제, Apple 은 토큰 철회까지)

## 내 정보

```json
User { "id": "1", "nickname": "취준생", "jobId": "planning", "companyIds": ["kia"], "onboardingCompleted": true }
```

| 메서드 | 경로 | 요청 | 응답 |
|---|---|---|---|
| GET | /me | | User |
| PUT | /me/job | `{ "jobId" }` | User |
| PUT | /me/companies | `{ "companyIds": [3~5개] }` | User |
| GET/PUT | /me/experiences | Experience | Experience |
| POST | /me/onboarding/complete | | User |
| GET/PUT | /me/notification-settings | `{ "enabled": true, "time": "08:00" }` | 같음 |
| PUT | /me/push-token | `{ "token", "platform": "ANDROID|IOS" }` | 204 |
| GET/PUT | /me/interview-schedules ◐ | `{ "items": [{ "companyId", "companyName", "date": "2026-11-02" }] }` | 같음 |

```json
Experience { "experiences": ["경험1", "..."], "coverLetter": "자소서 or null", "consentAgreed": true }
```

## 카탈로그
- GET /jobs → `[{ "id", "name" }]`
- GET /companies?q=검색어&jobId= → `[{ "id", "name", "logoUrl", "industry" }]`

## 홈 — GET /home
```json
{ "companies": [{
  "companyId": "kia", "companyName": "기아",
  "accuracy": 60,                       // 기업별 퀴즈 정답률(%) — 푼 문제 없으면 null
  "quiz":      { "status": "NOT_STARTED|IN_PROGRESS|COMPLETED|NOT_READY", "done": 2, "total": 5 },
  "interview": { "status": "...", "done": 0, "total": 1 },
  "isReviewSet": false,                 // 주말·검수 전 복습 세트로 대체
  "dday": 12                            // ◐ 면접까지 남은 날, 없으면 null
}]}
```

## 퀴즈 (채점은 서버)

### GET /quiz-sets/today?companyId=kia
정답을 내려주지 않는다. `answers` 에 이미 푼 문항 결과가 있으면 앱이 이어서 푼다.
```json
{ "id": "set-1", "companyId": "kia", "companyName": "기아", "isReview": false,
  "questions": [{ "id": "q1", "order": 1, "prompt": "...", "choices": [{ "id": "c1", "text": "..." }],
                  "sourceType": "DART|NEWS|TALENT|REVIEW", "sourceLabel": "사업의 내용", "hint": "..." }],
  "answers": [ AnswerResult ] }
```
### POST /quiz-sets/{setId}/answers
`{ "questionId", "choiceId" }` → AnswerResult (같은 문항을 다시 보내면 처음 결과를 그대로 돌려준다 — 재시도·더블탭 대비)
```json
AnswerResult { "questionId", "choiceId", "correct": false, "correctChoiceId": "c2",
  "explanation": "...", "sourceTitle": "...", "sourceUrl": "https://...", "interviewTip": "◐ 면접 활용 문구 or null" }
```
틀린 문항은 서버가 오답 노트에 추가한다.
### GET /quiz-sets/{setId}/result
```json
{ "setId", "companyId", "companyName", "correctCount": 3, "total": 5,
  "accuracyBefore": 50, "accuracyAfter": 60,
  "wrongItems": [{ "questionId", "prompt", "correctText", "explanation" }],
  "interviewReady": true }
```
### POST /quiz-questions/{questionId}/reports — `{ "reason" }` → 204

## 면접

### GET /interview-questions/today?companyId=kia · GET /interview-questions/{id}
```json
{ "id", "companyId", "companyName", "type": "MOTIVATION|ASPIRATION|CONTRIBUTION|WHY_HIRE|RECENT_ISSUE",
  "text": "질문", "issueSummary": ["요약 1", "요약 2"], "sources": [{ "title", "url" }],
  "index": 1, "total": 1, "savedAnswerId": "저장한 완성 답변 id or null" }
```
### POST /interview-questions/{id}/answers  (= AI 피드백 1회 사용)
`{ "content": "답변(최소 100자)", "inputType": "TEXT|VOICE" }` — 음성은 앱에서 글자로 바꿔 보낸다 (1분 이내).
```json
Feedback { "answerId", "questionId", "content", "inputType",
  "criteria": [{ "key": "CONCLUSION_FIRST|EVIDENCE|EXPERIENCE_LINK", "result": "MET|PARTIAL|NOT_MET", "comment": "..." }],
  "completeness": 67,              // 충족 1, 부분 0.5 (결정 9) → 평균 %
  "remainingFeedback": 3, "saved": false,
  "experienceSuggestion": "...", "suggestionExample": "...", "needsExperience": false }
```
횟수 소진이면 429 `FEEDBACK_QUOTA_EXCEEDED` (앱은 답변을 기기에 저장해 두고 내일 다시 보내게 안내).
### GET /interview-answers/{answerId} → Feedback
### POST /interview-answers/{answerId}/save → SavedAnswer (같은 질문의 이전 저장 답변은 교체)
### GET /feedback-quota → `{ "remaining": 3, "dailyLimit": 5 }` (자정 초기화, 서버 시간 기준 KST)

## 기록
- GET /wrong-notes?companyId= → `[WrongNote]`
```json
WrongNote { "id", "companyId", "companyName", "prompt", "choices": [...], "myChoiceId", "correctChoiceId",
  "explanation", "solvedAt": "ISO", "reviewed": false, "sourceUrl", "sourceTitle" }
```
- POST /wrong-notes/{id}/retry `{ "choiceId" }` → `{ "correct": true, "correctChoiceId" }` (맞히면 reviewed=true)
- GET /saved-answers?companyId= → `[SavedAnswer]`, GET/DELETE /saved-answers/{id}
```json
SavedAnswer { "id", "answerId", "questionId", "companyId", "companyName", "type", "questionText",
  "content", "completeness", "criteria": [...], "savedAt": "ISO" }
```

## 문의 — POST /inquiries
`{ "type": "BUG|SUGGESTION|OTHER", "content", "appVersion": "1.0.0", "platform": "ANDROID|IOS" }` → 204

## 푸시 데이터 (FCM)
`data.route` 에 앱 경로를 넣는다. 예: `/quiz/kia`, `/home`

## 완성본 와이어프레임 반영 (2026-10-17) — 백엔드와 맞출 변경점

앱 모델(`lib/data/models/*.dart`) 기준. 위 본문보다 이 절이 최신이다.

- **퀴즈 결과** `GET /quiz/sets/{setId}/result` 의 `items[]` 에 두 필드 추가 (없어도 화면은 뜬다)
  - `myAnswer`: 내 답 표시용 문자열 `"C. 늘었다"` (퀴즈는 모두 객관식, 주관식 없음)
  - `correctAnswer`: 정답 표시용 문자열 `"C. 늘었다"`
- **퀴즈 풀이**: 문제마다 정답을 보여주지 않는다. 앱은 답을 제출하고 바로 다음 문제로 넘어가며, 정답·해설은 결과에서만 본다 (채점은 지금처럼 서버).
- **공시 근거** `evidence` 에 `interpretation` (선택) 추가: "해석 · 전기차가 차지하는 판매 비중이 전년보다 커졌다는 뜻이에요."
- **면접 피드백** `criteria[]`: 4개 항목 × 25점 = 100점
  - `key`: `COMPANY_INFO`(기업 정보의 활용) · `SPECIFICITY`(내용의 구체성) · `LOGIC`(논리와 답변 구조) · `CLARITY`(전달의 명료성)
  - `max`: 25 (빠지면 앱은 25로 본다). `metCount` 3개 이상이면 `status: COMPLETE`
- **문의**: 앱 안 입력 대신 구글폼으로 연다 (`--dart-define=INQUIRY_FORM_URL=...`). `POST /inquiries` 는 지금 쓰지 않는다.
- **첫 설정**: STEP 4 경험은 제목 + 내용을 바로 `POST /me/experiences` 로 저장 (AI 나누기 없음). 그 뒤 알림 설정 `PUT /me/notification-settings` (기본 오전 9시) → 완료 화면에서 `POST /me/onboarding/complete`.
