# 미션 플로우 (Mission Flow v02)

> 작성일: 2026-05-18 · 최종 수정: 2026-05-19 · 상태: `draft`
> Figma 파일: [Yougabell OS Figma](https://www.figma.com/design/sKdG5GEBZPdMjFY9nYj5g0)
>
> **미션 소개 노드**: `2395:10007` (`미션 시작하기 - 02`)
> **미션 타이머 노드**: `2395:9927` (`미션 타이머 - 03`)
> **미션 효과 노드**: `2395:10109` (`미션 효과 - 04`)
> **미션 피드백 노드**: `2395:9759` (`미션 피드백 - 05`)
> **피드백 완료 노드**: `2395:10071` (`피드백 작성 완료 - 06`)

---

## 1. 배경 (Why)

홈의 "미션 시작하기"와 하단 탭 "10분 놀이"는 육아밸의 가장 자주 쓰이는 진입점이다. v01에서는 사용자가 추천 미션을 보고 시작하고, 수행 중인 10분 상호작용을 타이머로 따라갈 수 있게 만드는 첫 단계를 정의했다.

이번 v02 범위는 타이머 뒤의 후속 플로우를 마무리한다.

- 미션 효과 화면
- 미션 피드백 화면
- 피드백 작성 완료 화면

이 단계까지 연결되어야 `MissionExecution -> MissionFeedback -> 주간 리포트 집계` 흐름이 닫힌다.

---

## 2. 사용자 시나리오 (What)

- **누가**: 온보딩을 완료한 부모 사용자. 다자녀 사용자를 포함한다.
- **언제**:
  - 홈의 오늘 미션 카드에서 "미션 시작하기"를 누를 때
  - 하단 탭 "10분 놀이"를 누를 때
  - 타이머가 0이 되거나 조기완료를 누른 직후
- **흐름**:
  1. 사용자는 홈 또는 하단 탭에서 미션 소개 화면으로 진입한다.
  2. 시스템은 현재 선택된 자녀 기준 오늘의 추천 미션 1건을 조회해 제목, 설명, 시간, 카테고리, 출처를 보여준다.
  3. 사용자가 "미션 시작하기"를 누르면 `MissionExecution`이 생성되고 타이머 화면으로 이동한다.
  4. 사용자는 타이머를 진행하거나 pause/resume한다.
  5. 타이머가 0이 되거나 사용자가 "조기완료"를 누르면 `MissionExecution`이 종료되고 효과 화면으로 이동한다.
  6. 효과 화면의 "다음"을 누르면 피드백 작성 화면으로 이동한다.
  7. 사용자는 아이 반응(1~5), 부모 에너지(0~10), 미션 만족도(1~5), 오늘 아이가 많이 말한 단어를 입력한다.
  8. "미션 완료"를 누르면 `MissionFeedback`이 저장되고 피드백 완료 화면으로 이동한다.
  9. 완료 화면에서 "홈으로 가기"를 누르면 홈으로 이동한다.
- **수용 기준**:
  - 효과/피드백/완료 화면은 모두 하단 탭을 숨기고 별도 sub LNB를 사용한다.
  - 종료된 `MissionExecution.status`는 `completed` 또는 `early_completed`여야 한다.
  - `MissionFeedback`은 한 execution당 1건만 생성된다.
  - 피드백 저장 후 주간 리포트 집계에 필요한 값이 모두 채워진다.
  - 피드백 화면 재진입 시 이미 작성된 값이 있으면 재편집 가능하다.

---

## 3. 도메인 영향

이번 범위는 `MissionExecution` 종료 이후의 효과/피드백 도메인 계약을 확정한다.

| 엔티티                   | 변경 종류   | 비고                                                                               |
| ------------------------ | ----------- | ---------------------------------------------------------------------------------- |
| `Mission`                | 변경 없음   | 기존 `effect`를 효과 화면 문구로 재사용. `goal`, `subThemeLabel` 등 기존 필드 유지 |
| `MissionExecution`       | 변경 없음   | 종료 상태/실제 수행 시간은 v01에서 확정한 로직 유지                                |
| `MissionFeedback`        | 스키마 변경 | `parentEnergy` 저장 범위를 0..10으로 확장해 slider 값을 그대로 저장                |
| `MissionFeedbackKeyword` | 사용 확정   | 피드백 textarea 입력을 정규화해 rank 1..N 저장                                     |

### 키워드 저장 규칙

- 피드백 textarea는 자유 입력 문자열 1개를 받는다.
- 서버는 이 문자열을 콤마(`,`), 줄바꿈, 연속 공백 기준으로 정규화한다.
- 빈 문자열 제거 후 최대 10개까지 `MissionFeedbackKeyword(rank, keyword)`로 저장한다.
- 영문은 lowercase 정규화, 한국어는 원문 유지한다.
- `MissionFeedback.note`에는 사용자가 입력한 원문을 그대로 보존한다.

### 부모 에너지 점수 정책

- DB schema는 `MissionFeedback.parentEnergy Int // 0..10`으로 변경한다.
- web UI는 Figma를 따라 **0..10 slider**로 입력받는다.

---

## 4. 레포별 작업 분해

| 레포               | 작업                                                                                | 의존성       |
| ------------------ | ----------------------------------------------------------------------------------- | ------------ |
| `yougabell-api`    | 종료 execution 효과 조회, 피드백 조회/저장 endpoint, 저장 규칙 확정, OpenAPI export | 선행 (1순위) |
| `yougabell-web`    | 효과 화면, 피드백 화면, 완료 화면, 타이머 이후 전이, 피드백 폼 상태/검증            | api 완료 후  |
| `yougabell-mobile` | 별도 네이티브 UI 없음. WebView 뒤로가기/foreground 복귀 확인                        | web 후속     |
| `yougabell-admin`  | 기존 `Mission.effect` 입력/수정 UI가 효과 화면 문구 용도까지 커버하는지 확인 (후속) | 후속         |

### 4.1 yougabell-api 상세 스펙

#### 기존 endpoint 유지

- `GET /missions/current`
- `POST /mission-executions`
- `GET /mission-executions/active`
- `POST /mission-executions/:id/action`

`POST /mission-executions/:id/action`의 `complete`, `early_complete` 처리 결과는 동일하다. 둘 다 종료 시점까지의 실제 수행 시간을 `actualDurationSeconds`에 저장한다.

#### 엔드포인트 — `GET /mission-executions/:id/effect`

효과 화면 기본 데이터 조회 endpoint. 완료 화면도 같은 응답을 재사용한다.

**인증**: `Authorization: Bearer <Supabase JWT>` 필수.

**Response 200**:

```typescript
type GetMissionExecutionEffectResponse = {
  execution: {
    id: string;
    status: 'completed' | 'early_completed';
    completedAt: string;
    actualDurationSeconds: number;
    wasEarlyCompleted: boolean;
  };
  mission: {
    id: string;
    title: string;
    effect: string; // Mission.effect
    goal: string | null;
    subThemeLabel: string | null;
  };
};
```

**처리 로직**:

1. execution이 현재 사용자 소유인지 검증한다.
2. status가 `completed` 또는 `early_completed`인지 검증한다.
3. execution에 연결된 미션을 조회한다.
4. 효과 화면과 완료 화면이 바로 렌더링 가능한 shape로 응답한다.

**에러 응답**:

| 상태 | code                             | 의미                            |
| ---- | -------------------------------- | ------------------------------- |
| 400  | `VALIDATION_ERROR`               | id 형식 오류                    |
| 401  | `UNAUTHORIZED`                   | JWT 없음/만료                   |
| 404  | `MISSION_EXECUTION_NOT_FOUND`    | 본인 execution이 아님 또는 없음 |
| 409  | `MISSION_EXECUTION_NOT_FINISHED` | 아직 타이머가 종료되지 않음     |

#### 엔드포인트 — `PUT /mission-executions/:id/feedback`

피드백 저장 endpoint. 동일 execution에 대해 upsert로 동작한다.

**Request**:

```typescript
type UpsertMissionFeedbackDto = {
  childReaction: number; // 1..5
  parentEnergy: number; // 0..10
  missionSatisfaction: number; // 1..5
  note?: string | null; // 원문 textarea
};
```

**검증 룰**:

- execution은 현재 사용자 소유여야 한다.
- execution status는 `completed` 또는 `early_completed`여야 한다.
- `childReaction`, `missionSatisfaction`는 1..5
- `parentEnergy`는 0..10
- `note`는 최대 500자

**처리 로직**:

1. execution 소유권/종료 상태 검증
2. `note`를 정규화해 `keywords[]` 산출
3. `MissionFeedback` upsert
4. 기존 `MissionFeedbackKeyword`를 교체 저장
5. 저장된 값을 응답

**Response 200**:

```typescript
type UpsertMissionFeedbackResponse = {
  feedback: {
    id: string;
    executionId: string;
    childReaction: number;
    parentEnergy: number; // 0..10
    missionSatisfaction: number;
    note: string | null;
    keywords: string[];
    createdAt: string;
  };
};
```

#### OpenAPI

- OpenAPI export 갱신 필수
- web/mobile codegen 갱신 필수

### 4.2 yougabell-web 상세 스펙

#### 라우트 구조

미션 화면은 하단 탭이 없는 별도 흐름이므로 `(main)` 공통 shell 바깥으로 둔다.

```text
app/
  mission/
    page.tsx                  // 미션 소개
    timer/page.tsx            // 타이머
    effect/page.tsx           // 미션 효과
    feedback/page.tsx         // 미션 피드백
    done/page.tsx             // 피드백 작성 완료
```

#### 화면 전이

- 홈 "미션 시작하기" -> `/mission`
- 하단 탭 "10분 놀이" -> `/mission`
- 소개 화면 "미션 시작하기" -> `POST /mission-executions` 성공 후 `/mission/timer?executionId=...`
- 타이머 종료 또는 조기완료 -> `/mission/effect?executionId=...`
- 효과 화면 "다음" -> `/mission/feedback?executionId=...`
- 피드백 저장 성공 -> `/mission/done?executionId=...`
- 완료 화면 "홈으로 가기" -> `/`
- 완료 화면 우측 calendar 아이콘 -> `/weekly-report`

#### 상태 스키마

```typescript
type MissionExecutionEffect = {
  execution: {
    id: string;
    status: 'completed' | 'early_completed';
    actualDurationSeconds: number;
    completedAt: string;
    wasEarlyCompleted: boolean;
  };
  mission: {
    id: string;
    title: string;
    effect: string;
    goal: string | null;
    subThemeLabel: string | null;
  };
};

type MissionFeedbackDraft = {
  childReaction: number | null;
  parentEnergy: number | null; // 0..10
  missionSatisfaction: number | null;
  note: string;
};
```

#### UI 상태

- 효과 화면
  - loading: centered skeleton
  - success: Figma `2395:10109`
  - API 실패: 전체 에러 화면
- 피드백 화면
  - success: Figma `2395:9759`
  - `executionId`와 전역 child 정보로 렌더
  - 저장 중: CTA disabled
  - validation error: CTA 위 인라인 에러
  - draft 복구: `sessionStorage` 기반 임시 저장값 복원
- 완료 화면
  - success: Figma `2395:10071`
  - `GET /mission-executions/:id/effect` 재호출 후 렌더

#### 폼 규칙

- `childReaction`: 필수, 1..5 중 하나
- `parentEnergy`: 필수, 0..10 slider
- `missionSatisfaction`: 필수, 1..5 중 하나
- `note`: 선택

#### 입력 해석

- textarea는 자유 입력 1개 필드로 유지하고, API 필드명은 `note`를 사용한다.
- placeholder는 Figma 문구를 따른다.
- 사용자는 쉼표/띄어쓰기/줄바꿈으로 단어를 적을 수 있다.
- web은 원문만 보내고, keyword 파싱/정규화는 서버가 담당한다.
- 피드백 입력 draft는 `sessionStorage`에 `mission-feedback-draft:<executionId>` key로 임시 저장하고, 제출 성공 시 clear한다.

### 4.3 yougabell-mobile

- 별도 네이티브 UI 구현 없음
- 확인 항목:
  - 타이머 종료 후 effect -> feedback -> done 라우팅이 WebView에서 자연스러운지
  - Android hardware back 시 feedback 화면에서 직전 화면으로 이동하는지
  - foreground 복귀 시 feedback 입력값이 유지되는지

---

## 5. UI/디자인 참조

### 가져올 것

- 효과 화면의 중앙 일러스트 + headline + effect card
- 피드백 화면의 5단계 반응 선택 row 2개
- 부모 에너지 0~10 slider
- 완료 화면의 calendar 아이콘 + 홈 CTA

### 재해석할 것

- slider는 Figma 자산을 그대로 이미지로 쓰지 않고 입력 가능한 웹 슬라이더로 재구성한다.
- 5단계 반응 아이콘은 기존 `public/icons/figma/mission-feedback` 자산을 재사용한다.
- 효과/완료 화면 배경의 은은한 purple glow는 CSS 배경으로 근사 구현한다.

---

## 6. 비기능 요구

### 저장 전략

- `MissionExecution` 종료 후에만 피드백 작성 가능
- 피드백은 upsert 가능 (같은 execution 수정 허용)
- 슬라이더/textarea 입력 중 페이지 이동 전까지는 클라이언트 state 유지
- 저장 전 재진입 복구는 `sessionStorage` draft 저장으로 처리한다
- 피드백 제출 성공 시 draft를 clear한다

### 그 외

- 보안:
  - effect 조회와 feedback 저장 모두 본인 소유 execution만 접근 가능
- 접근성:
  - 5단계 반응 버튼은 `aria-pressed` 상태를 가져야 함
  - 에너지 slider는 현재 점수를 스크린리더로 읽을 수 있어야 함
- 분석 이벤트:
  - `mission_effect_view`
  - `mission_effect_next_click`
  - `mission_feedback_view`
  - `mission_feedback_child_reaction_select`
  - `mission_feedback_parent_energy_change`
  - `mission_feedback_satisfaction_select`
  - `mission_feedback_submit`
  - `mission_feedback_done_view`

---

## 7. 결정 사항

- [x] 효과 화면 본문은 기존 `Mission.effect`를 사용한다
- [x] 부모 에너지 상태 UI와 저장값 모두 0..10을 사용한다
- [x] keyword 입력은 자유 textarea 1개를 받고, 서버에서 키워드로 정규화한다
- [x] 피드백 작성 완료 화면 우측 아이콘은 주간 리포트 진입으로 사용한다
- [x] 동일 execution 피드백은 upsert 허용한다
- [x] 저장 전 피드백 재진입 복구는 서버 GET이 아니라 클라이언트 draft 저장으로 처리한다

---

## 8. Phase별 작업 todo

### Phase 1 — umbrella 문서/스키마 확정

- [x] 미션 문서를 v02로 확장
- [x] `docs/schema/05-mission.md`를 실제 Prisma schema 기준으로 갱신

### Phase 2 — `yougabell-api`

- [ ] `MissionFeedback.parentEnergy` 0..10 검증/저장 반영
- [ ] `GET /mission-executions/:id/effect`
- [ ] `PUT /mission-executions/:id/feedback`
- [ ] keyword 파싱/정규화 유틸
- [ ] OpenAPI export 갱신

### Phase 3 — `yougabell-web`

- [ ] `/mission/effect`
- [ ] `/mission/feedback`
- [ ] `/mission/done`
- [ ] 타이머 종료 후 effect 화면 전이
- [ ] feedback form 구현
- [ ] 완료 화면 구현
