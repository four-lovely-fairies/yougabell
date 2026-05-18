# 미션 시작/타이머 (Mission Start & Timer v01)

> 작성일: 2026-05-18 · 작성자: — · 상태: `draft`
> Figma 파일: [Yougabell OS Figma](https://www.figma.com/design/sKdG5GEBZPdMjFY9nYj5g0)
>
> **미션 소개 노드**: `2395:10007` (`미션 시작하기 - 02`)
> **미션 타이머 노드**: `2395:9927` (`미션 타이머 - 03`)

---

## 1. 배경 (Why)

홈의 "미션 시작하기"와 하단 탭 "10분 놀이"는 육아밸의 가장 자주 쓰이는 진입점이다. 지금까지는 홈에서 추천 미션 카드만 보여주고 실제 수행 플로우가 연결되지 않았다. 이번 기능은 사용자가 추천 미션을 보고 바로 시작하고, 수행 중인 10분 상호작용을 타이머로 따라갈 수 있게 만드는 첫 단계다.

이번 v01 범위는 다음 두 화면을 구현한다.

- 미션 소개 화면
- 미션 타이머 화면

미션 종료 후 이동하는 "미션 효과/다음 단계" 화면은 이번 범위에서 제외하고, 타이머 종료·조기완료 시점의 전이 계약만 문서에 남긴다.

---

## 2. 사용자 시나리오 (What)

- **누가**: 온보딩을 완료한 부모 사용자. 다자녀 사용자를 포함한다.
- **언제**:
  - 홈의 오늘 미션 카드에서 "미션 시작하기"를 누를 때
  - 하단 탭 "10분 놀이"를 누를 때
  - 이후 미션 소개 화면에서 다시 "미션 시작하기"를 누를 때
- **흐름**:
  1. 사용자는 홈 또는 하단 탭에서 미션 소개 화면으로 진입한다.
  2. 시스템은 현재 선택된 자녀 기준 오늘의 추천 미션 1건을 조회해 제목, 설명, 시간, 카테고리, 출처를 보여준다.
  3. 사용자가 "미션 시작하기"를 누르면 `MissionExecution`이 생성되고 타이머 화면으로 이동한다.
  4. 타이머 화면은 생성된 수행 인스턴스 기준으로 남은 시간을 초 단위로 표시한다.
  5. 사용자가 앱을 나갔다 돌아와도 진행 중인 미션이 있으면 같은 타이머 화면으로 복귀할 수 있어야 한다.
  6. 타이머가 0이 되거나 사용자가 "조기완료"를 누르면 다음 단계(미션 효과 화면)로 이동한다.
- **수용 기준**:
  - 미션 소개 화면은 하단 탭을 숨기고 별도 sub LNB를 사용한다.
  - 미션 시작 시점에 `MissionExecution.status='in_progress'` row가 1건 생성된다.
  - 같은 자녀 기준 진행 중(`in_progress` 또는 `paused`)인 `MissionExecution`이 있으면 새 row를 만들지 않고 기존 수행을 재사용한다.
  - 타이머는 `Mission.durationMinutes * 60`을 기준으로 감소한다.
  - 타이머는 새로고침/재진입 시에도 서버 시각 기준으로 복원 가능해야 한다.
  - 타이머 종료 또는 조기완료 후의 효과/피드백 화면은 후속 범위지만, 실행 상태 전이는 이번 계약에 포함한다.

---

## 3. 도메인 영향

기존 `docs/schema/05-mission.md`에 `Mission`, `MissionExecution`, `MissionFeedback`이 정의돼 있다. 이번 기능은 새로운 도메인 엔티티를 추가하기보다, 이미 있는 `MissionExecution`을 실제로 시작/복구하는 API 계약을 확정한다.

| 엔티티                        | 변경 종류     | 비고                                                                            |
| ----------------------------- | ------------- | ------------------------------------------------------------------------------- |
| `Mission`                     | 변경 없음     | 미션 소개 화면에서 `title`, `description`, `durationMinutes`, `effect` 등 사용  |
| `MissionExecution`            | 필드 추가     | pause/resume 복구용 `activeSegmentStartedAt`, `pausedAt`, `elapsedSeconds` 추가 |
| `HomeDashboard` (DTO)         | 변경 없음     | 홈의 `recommendedMission.id`를 미션 소개 진입에 사용                            |
| `MissionEntry` (DTO, DB 아님) | 신규 응답 DTO | 미션 소개/타이머 화면에서 공통으로 쓰는 조회 응답                               |

> `docs/schema/05-mission.md`의 TBD 중 "paused 상태를 DB에 저장하는지"는 **서버 DB에 저장**으로 확정한다. 타이머 복구와 멀티 디바이스 일관성을 위해 클라이언트 메모리만으로는 부족하다.

### `MissionExecution` 상태 전이 확정

```text
not started
  -> in_progress      (미션 시작하기)
in_progress
  -> paused           (멈추기)
  -> completed        (시간 만료)
  -> early_completed  (조기완료)
paused
  -> in_progress      (다시 시작하기)
  -> early_completed  (조기완료)
```

### Prisma schema diff

pause/resume을 정확히 지원하려면 `MissionExecution`에 누적 진행 시간과 현재 active segment 기준 시각이 필요하다.

```prisma
model MissionExecution {
  // ... existing fields
  activeSegmentStartedAt DateTime?
  pausedAt               DateTime?
  elapsedSeconds         Int       @default(0)
}
```

- 마이그레이션: `pnpm prisma:migrate:dev --name mission_execution_pause_resume`
- 미션 총 시간은 기존 `Mission.durationMinutes * 60`으로 계산한다.

### 타이머 복구 계산 규칙

```text
missionTotalSeconds = Mission.durationMinutes * 60

if status == 'in_progress':
  currentElapsedSeconds = elapsedSeconds + (now - activeSegmentStartedAt)

if status == 'paused':
  currentElapsedSeconds = elapsedSeconds

remainingSeconds = missionTotalSeconds - currentElapsedSeconds
```

- 새 execution 생성 시:
  - `startedAt = now`
  - `activeSegmentStartedAt = now`
  - `elapsedSeconds = 0`
  - `pausedAt = null`
- pause 시:
  - `elapsedSeconds += now - activeSegmentStartedAt`
  - `activeSegmentStartedAt = null`
  - `pausedAt = now`
- resume 시:
  - `activeSegmentStartedAt = now`
  - `pausedAt = null`

---

## 4. 레포별 작업 분해

| 레포               | 작업                                                                                 | 의존성       |
| ------------------ | ------------------------------------------------------------------------------------ | ------------ |
| `yougabell-api`    | 추천 미션 상세 조회, 시작/복구/상태 전이 endpoint, OpenAPI export                    | 선행 (1순위) |
| `yougabell-web`    | 미션 소개 화면, 타이머 화면, 홈/하단 탭 진입 연결, 타이머 상태 복원                  | api 완료 후  |
| `yougabell-mobile` | 별도 네이티브 기능 없음. WebView 뒤로가기와 foreground 복귀 시 타이머 복원 동작 확인 | web 후속     |
| `yougabell-admin`  | 영향 없음                                                                            | —            |

### 4.1 yougabell-api 상세 스펙

#### Prisma schema diff

신규 schema diff 없음.

#### 엔드포인트 — `GET /missions/current`

현재 선택 자녀 기준 "지금 보여줄 미션 소개 화면" 데이터를 반환한다.

**인증**: `Authorization: Bearer <Supabase JWT>` 필수. `JwtAuthGuard` + `OnboardingCompleteGuard` 적용.

**Query**:

```typescript
type GetCurrentMissionQuery = {
  childId?: string; // 없으면 displayOrder 가장 앞 active child
};
```

**처리 로직**:

1. 현재 사용자 active child 목록에서 선택 자녀를 확정한다.
2. 자녀 월령과 roadmap category 매칭 규칙으로 오늘의 추천 미션 1건을 고른다.
3. 같은 자녀 기준 `status in ('in_progress', 'paused')` 수행이 있으면 `activeExecution`에 포함한다.
4. 미션 소개 화면에 필요한 제목, 설명, 시간, 카테고리, 출처를 반환한다.

**Response 200**:

```typescript
type GetCurrentMissionResponse = {
  selectedChild: {
    id: string;
    name: string;
    ageLabel: string;
  };
  mission: {
    id: string;
    subThemeLabel: string | null;
    title: string;
    description: string;
    durationMinutes: number;
    durationLabel: string; // "10분"
    categoryLabel: string; // "언어발달"
    sourceLabel: string; // "CDC"
  };
  activeExecution: null | {
    id: string;
    status: "in_progress" | "paused";
    startedAt: string;
    activeSegmentStartedAt: string | null;
    pausedAt: string | null;
    durationMinutes: number;
    elapsedSeconds: number;
    remainingSeconds: number;
  };
};
```

**에러 응답**:

| 상태 | code                  | 의미                                    |
| ---- | --------------------- | --------------------------------------- |
| 400  | `VALIDATION_ERROR`    | `childId` 형식 오류                     |
| 401  | `UNAUTHORIZED`        | JWT 없음/만료                           |
| 403  | `ONBOARDING_REQUIRED` | 온보딩 미완료                           |
| 404  | `CHILD_NOT_FOUND`     | 자녀 없음 또는 사용자 소유 자녀가 아님  |
| 409  | `NO_CHILD_PROFILE`    | 온보딩 완료 상태이나 자녀 데이터가 없음 |
| 500  | `INTERNAL_ERROR`      | 추천 미션 조회 실패                     |

#### 엔드포인트 — `POST /mission-executions`

미션 시작하기를 누를 때 수행 인스턴스를 생성하거나, 이미 진행 중인 수행이 있으면 그것을 재사용한다.

**Request**:

```typescript
type StartMissionExecutionDto = {
  childId: string;
  missionId: string;
};
```

**검증 룰**:

- `childId`는 현재 사용자 소유 active child여야 한다.
- `missionId`는 노출 가능한 미션이어야 한다.
- 같은 `childId` 기준 `status in ('in_progress', 'paused')` 수행이 이미 있으면 새 row를 만들지 않는다.

**처리 로직**:

1. active child/mission 유효성 검사
2. 기존 진행 중 수행 조회
3. 있으면 기존 execution 반환
4. 없으면 `startedAt=now`, `status='in_progress'`, `wasEarlyCompleted=false`로 생성
5. `activeSegmentStartedAt=now`, `elapsedSeconds=0`, `pausedAt=null`로 초기화한다.
6. duration은 `Mission.durationMinutes * 60`을 timer 기준으로 사용한다.

**Response 200**:

```typescript
type StartMissionExecutionResponse = {
  execution: {
    id: string;
    missionId: string;
    childId: string;
    status: "in_progress" | "paused";
    startedAt: string;
    activeSegmentStartedAt: string | null;
    pausedAt: string | null;
    durationMinutes: number;
    elapsedSeconds: number;
    remainingSeconds: number;
  };
};
```

#### 엔드포인트 — `GET /mission-executions/active`

진행 중 또는 일시정지된 수행이 있으면 복구용 snapshot을 반환한다.

```typescript
type GetActiveMissionExecutionQuery = {
  childId?: string;
};
```

**Response 200**:

```typescript
type GetActiveMissionExecutionResponse = {
  execution: null | {
    id: string;
    missionId: string;
    childId: string;
    status: "in_progress" | "paused";
    startedAt: string;
    activeSegmentStartedAt: string | null;
    pausedAt: string | null;
    durationMinutes: number;
    elapsedSeconds: number;
    remainingSeconds: number;
  };
};
```

#### 엔드포인트 — `POST /mission-executions/:id/action`

타이머 화면의 상태 전이 endpoint.

```typescript
type MissionExecutionActionDto = {
  action: "pause" | "resume" | "complete" | "early_complete";
};
```

**처리 로직**:

- `pause`: `elapsedSeconds += now - activeSegmentStartedAt`, `status='paused'`, `activeSegmentStartedAt=null`, `pausedAt=now`
- `resume`: `status='in_progress'`, `activeSegmentStartedAt=now`, `pausedAt=null`
- `complete`: `status='completed'`, `completedAt=now`, `actualDurationSeconds=elapsedSeconds + (now - activeSegmentStartedAt)`
- `early_complete`: `status='early_completed'`, `completedAt=now`, `actualDurationSeconds=elapsedSeconds + (status == 'in_progress' ? now - activeSegmentStartedAt : 0)`, `wasEarlyCompleted=true`

**비고**:

- 이번 범위의 web 구현은 `pause`/`resume`과 timer 종료 시 `complete` 호출까지 포함한다.
- `early_complete` 이후 도착하는 효과 화면은 후속 범위다.

#### OpenAPI

- OpenAPI export 갱신 필수
- web/mobile codegen 갱신 필수

### 4.2 yougabell-web 상세 스펙

#### 라우트 구조

미션 화면은 하단 탭이 없는 별도 흐름이므로 `(main)` 공통 shell 바깥으로 둔다.

```text
app/
  (main)/
    page.tsx                  // 홈
    weekly-report/page.tsx
  mission/
    page.tsx                  // 미션 소개
    timer/page.tsx            // 타이머
```

#### 화면 전이

- 홈 "미션 시작하기" -> `/mission`
- 하단 탭 "10분 놀이" -> `/mission`
- 소개 화면 "미션 시작하기" -> `POST /mission-executions` 성공 후 `/mission/timer?executionId=...`
- 소개 화면에서 `activeExecution`이 있으면 CTA를 `이어서 하기`로 보여주고, 누르면 해당 execution의 타이머 화면으로 이동
- 타이머 종료 또는 조기완료 -> 후속 범위의 `/mission/effect?...`로 이동 예정

#### 상태 스키마

```typescript
type MissionTimerSnapshot = {
  executionId: string;
  missionId: string;
  childId: string;
  status: "in_progress" | "paused";
  durationMinutes: number;
  elapsedSeconds: number;
  remainingSeconds: number;
  startedAt: string;
  activeSegmentStartedAt: string | null;
  pausedAt: string | null;
  serverNow: string;
};
```

- source of truth는 서버 응답이다.
- 클라이언트는 매 초 decrement UI를 하되, 화면 진입/복귀 시 서버 snapshot으로 다시 동기화한다.
- localStorage 영속 저장은 하지 않는다. 서버에 진행 상태가 있으므로 복원은 API 재조회로 처리한다.
- `startedAt`은 최초 시작 시각 기록용이고, 실제 running 타이머 복원 계산은 `elapsedSeconds + (serverNow - activeSegmentStartedAt)`로 한다.

#### 훅 인터페이스

```typescript
function useCurrentMission(childId?: string): {
  data: GetCurrentMissionResponse | undefined;
  isLoading: boolean;
  error: ApiError | null;
  refetch: () => Promise<void>;
};

function useMissionTimer(executionId: string): {
  snapshot: MissionTimerSnapshot | null;
  isLoading: boolean;
  pause: () => Promise<void>;
  resume: () => Promise<void>;
  complete: () => Promise<void>;
  earlyComplete: () => Promise<void>;
};
```

#### 컴포넌트 인터페이스

```typescript
type MissionIntroScreenProps = {
  childLabel: string;
  mission: {
    subThemeLabel: string | null;
    title: string;
    description: string;
    durationLabel: string;
    categoryLabel: string;
    sourceLabel: string;
  };
  hasActiveExecution: boolean;
  onBack: () => void;
  onStart: () => void;
};

type MissionTimerScreenProps = {
  childLabel: string;
  remainingSeconds: number;
  totalSeconds: number;
  status: "in_progress" | "paused";
  onBack: () => void;
  onPause: () => void;
  onResume: () => void;
  onEarlyComplete: () => void;
};
```

#### UI 상태

- 소개 화면
  - loading: skeleton
  - success: Figma `2395:10007`
  - API 실패: 전체 에러 화면
  - `activeExecution.status='paused'`면 CTA 문구를 `이어서 하기`로 변경
  - `activeExecution.status='in_progress'`면 소개 화면을 건너뛰고 바로 타이머 화면으로 보낸다
- 타이머 화면
  - loading: centered spinner/skeleton
  - in_progress: 보라색 progress ring + `멈추기`
  - paused: progress 유지 + primary CTA `다시 시작하기`, secondary CTA `조기완료`
  - API 실패: 전체 에러 화면

#### middleware 분기

- 기존 홈/리포트와 동일하게 로그인 + 온보딩 완료 필요
- 미션 화면도 온보딩 미완료 시 온보딩으로 리디렉션

### 4.3 yougabell-mobile

- 별도 네이티브 UI 구현 없음
- 확인 항목:
  - Android hardware back 시 `/mission/timer`에서 오동작 없이 이전 화면으로 이동하는지
  - 앱 background -> foreground 복귀 시 web이 `GET /mission-executions/active`로 snapshot 복원하는지
  - WebView safe area에서 상단 sub LNB와 하단 home indicator spacing이 깨지지 않는지

---

## 5. UI/디자인 참조

- Figma 노드:
  - `2395:10007` — 미션 소개 화면
  - `2395:9927` — 미션 타이머 화면
- 디자인 토큰 변경 필요 여부: 없음

### 가져올 것 / 무시할 것

| 구분        | 내용                                                                              |
| ----------- | --------------------------------------------------------------------------------- |
| 가져올 것   | 상단 sub LNB 구조, 중앙 정렬된 미션 정보, 하단 CTA, 타이머 원형 진행 UI           |
| 가져올 것   | 미션 정보 카드의 3개 메타 항목(시간, 카테고리, 출처)                              |
| 가져올 것   | 타이머 화면의 큰 숫자 시간 표시, `멈추기`, `조기완료` 계층 구조                   |
| 무시할 것   | iOS status bar/Home indicator asset의 절대 좌표                                   |
| 무시할 것   | Figma 원본 이미지 asset URL 자체                                                  |
| 재해석할 것 | 원형 progress ring의 animation 구현 방식                                          |
| 재해석할 것 | 소개 화면의 캐릭터 일러스트 asset. 초기 구현은 mission-illustration.svg 참조 허용 |

### 화면 구조 해석

- 미션 소개 화면은 **리스트/피드형 미션 탭이 아니라 단일 미션 상세 시작 화면**이다.
- 타이머 화면은 **전체 앱 shell 안의 카드가 아니라 풀스크린 task 화면**이다.
- 두 화면 모두 하단 탭을 숨긴다.

---

## 6. 비기능 요구

### 저장 전략

- 서버 DB: `MissionExecution` 상태를 서버에 저장한다.
- 단계별 저장: 시작/일시정지/재개/완료 시점마다 상태를 서버에 반영한다.
- 영속성 등급: 앱 강제 종료 후에도 수행 복구가 가능해야 한다.
- 멀티 디바이스: 같은 계정으로 다른 디바이스에 들어가도 active execution 1건만 복원 가능해야 한다.

### 그 외

- 성능:
  - `GET /missions/current` 응답 300ms 이내 목표
  - 타이머 화면 재진입 복구 응답 300ms 이내 목표
- 보안:
  - execution 조회/전이는 본인 소유 자녀·미션만 가능
  - 다른 사용자의 `executionId` 직접 호출은 404 또는 403 차단
- 접근성:
  - 타이머 숫자는 스크린리더에서 남은 시간을 읽을 수 있어야 함
  - CTA 버튼은 `button` semantics 유지
- 분석 이벤트:
  - `mission_intro_view`
  - `mission_intro_start_click`
  - `mission_timer_view`
  - `mission_timer_pause_click`
  - `mission_timer_resume_click`
  - `mission_timer_early_complete_click`
  - `mission_timer_complete`

---

## 7. 리스크·미해결 질문

- [x] ~~`GET /missions/current`가 항상 "오늘의 추천 미션 1건"만 보여주면 충분한가, 아니면 리스트/다음 추천 전환이 필요한가~~ → **현재 범위에서는 추천 미션 1건만 보여주면 충분하다. 리스트/다음 추천 전환은 후속 범위로 둔다. (2026-05-18)**
- [x] ~~미션 소개 화면의 "출처"는 현재 실제 데이터로 채울 수 있는가, 아니면 초기에는 하드코딩/seed 기반인가~~ → **출처는 실제 MissionSource 데이터로 채운다. (2026-05-18)**
- [x] ~~진행 중 미션이 있을 때 홈/하단 탭에서 `/mission` 진입 시 소개 화면을 보여줄지, 바로 타이머로 보낼지~~ → **`in_progress` 상태면 소개 화면을 건너뛰고 바로 타이머로 보낸다. `paused` 상태만 소개 화면에서 `이어서 하기`로 노출한다. (2026-05-18)**
- [x] ~~background 상태에서 브라우저 타이머 drift가 큰 경우 보정 주기를 얼마나 둘지~~ → **상시 polling은 두지 않는다. pause/resume/complete/early_complete 같은 상태 전이 시점과 background 복귀·재진입 시점에만 서버 snapshot으로 보정한다. (2026-05-18)**

---

## 8. Phase별 작업 todo

### Phase 0 — 기획 확정 (선행)

- [x] 진행 중 미션 재진입 정책 확정 (`in_progress`는 바로 타이머, `paused`는 소개 화면에서 이어서 하기)
- [x] 출처/sourceLabel 데이터 채우는 방식 확정 (실제 데이터 사용)
- [x] 타이머 drift 보정 정책 확정 (상태 전이/재진입 시점만 서버 snapshot 재동기화)

### Phase 1 — `yougabell-api` (선행, 다른 레포 시작 차단)

- [ ] `GET /missions/current`
- [ ] `POST /mission-executions`
- [ ] `GET /mission-executions/active`
- [ ] `POST /mission-executions/:id/action`
- [ ] OpenAPI export 갱신

### Phase 2 — `yougabell-web` (api 완료 후)

- [ ] `/mission` 라우트 추가
- [ ] `/mission/timer` 라우트 추가
- [ ] 홈 CTA `/mission` 연결
- [ ] bottom nav "10분 놀이" `/mission` 연결
- [ ] 소개 화면 구현
- [ ] 타이머 화면 구현
- [ ] active execution 복구 처리

### Phase 3 — `yougabell-mobile` (해당 시)

- [ ] WebView foreground 복귀 시 동작 검증
- [ ] Android back 검증

### Phase 4 — `yougabell-admin` (해당 시)

- [ ] —

### Phase 5 — 통합 검증

- [ ] 홈 -> 미션 소개 -> 타이머 진입
- [ ] 앱 이탈 후 타이머 복구
- [ ] 멈추기/다시 시작하기
- [ ] 타이머 만료 시 complete 전이
- [ ] 조기완료 시 early_complete 전이

---

## 9. 구현 결과 (구현 완료 후 채움)

- 관련 PR: —
- 마이그레이션 이름: 없음
- 스펙 변경점: —
- 후속 과제: 미션 효과 화면, 수행 후 피드백 화면
