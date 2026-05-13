# 주간 리포트 (Weekly Report v03)

> 작성일: 2026-05-13 · 작성자: — · 상태: `draft`
> Figma 파일: [Yougabell OS Figma](https://www.figma.com/design/sKdG5GEBZPdMjFY9nYj5g0)
>
> **데이터 있음 노드**: `2183:6775` (`Weekly Report_v03`) — 해당 주에 미션 수행 이력이 있어 리포트가 생성된 상태.
> **리포트 없음 노드**: `2183:3895` (`미션 최초 수행 전`) — 앱 설치 후 아직 수행한 미션이 없어 보여줄 주간 리포트가 없는 상태.

---

## 1. 배경 (Why)

주간 리포트는 부모가 한 주 동안 아이와 쌓은 짧은 상호작용을 회고하고, 다음 주에 이어갈 행동을 제안하는 화면이다. 홈이 "오늘 무엇을 할지"를 보여준다면, 주간 리포트는 "지난주에 어떤 흐름이 있었는지"를 정리한다.

이번 v03 화면은 다음 데이터를 한 화면에 묶는다.

- "나는 잘하고 있는가?"에 대한 AI 기반 격려 문장
- 월~일 미션 수행 현황
- 누적 미션 수행시간
- 아이 반응 긍정률
- 아이 관심 키워드 Top 3
- 아이의 베스트 모먼트
- 사용자의 내면 상태
- 다음 행동 제안

리포트는 **매주 월요일 00:00 KST**에 지난주 월~일 데이터를 기준으로 생성한다. 해당 주에 미션 수행 이력이 1건도 없으면 리포트 row를 만들지 않는다.

---

## 2. 사용자 시나리오 (What)

- **누가**: 온보딩을 완료한 부모 사용자. 다자녀 사용자를 포함한다.
- **언제**:
  - 하단 탭 "주간 리포트"를 누를 때
  - 알림에서 주간 리포트 도착 알림을 누를 때
  - 홈 리포트 카드에서 진입할 때
- **흐름**:
  1. 사용자는 주간 리포트 화면에 진입한다.
  2. 시스템은 현재 선택된 자녀 기준으로 직전 완료 주차의 주간 리포트를 조회한다.
  3. 리포트가 있으면 `Weekly Report_v03` 구조로 이번주 요약, 키워드, 베스트 모먼트, 내면 상태, AI 제안을 보여준다.
  4. 리포트가 없으면 `미션 최초 수행 전` 노드를 기준으로 empty state를 보여주고 "미션 시작하기" CTA를 제공한다.
  5. 해당 주의 미션 피드백에 아이 키워드 입력이 1건도 없으면 "아이의 관심 키워드 Top 3" 섹션은 키워드 칩 대신 입력 유도 empty state를 보여준다.
- **수용 기준**:
  - 리포트 생성 기준 주차는 월요일 00:00:00~일요일 23:59:59 KST다.
  - 생성 시점은 일요일에서 월요일로 넘어가는 자정, 즉 **월요일 00:00 KST**다.
  - 해당 주에 completed/early_completed 미션이 1건도 없으면 주간 리포트는 생성하지 않는다.
  - 한 주에 미션은 수행했지만 피드백 키워드 입력이 없으면 리포트는 생성하되 `topKeywords`는 빈 배열로 반환한다.
  - `topKeywords`가 빈 배열이면 키워드 섹션을 숨기지 않고, 다음 피드백에서 아이가 많이 말한 단어를 입력해보라는 문구를 표시한다.
  - 다자녀 사용자는 자녀별로 주간 리포트가 별도 생성된다.
  - 온보딩 미완료 사용자는 주간 리포트에 접근하지 못하고 온보딩으로 리디렉션된다.

---

## 3. 도메인 영향

기존 `docs/schema/08-report.md`와 `yougabell-api/prisma/schema.prisma`에 주간 리포트 모델이 이미 존재한다. 이번 기능은 생성 조건과 조회 계약을 확정하고, 키워드 없음 상태를 명시한다.

| 엔티티                       | 변경 종류      | 비고                                                                                               |
| ---------------------------- | -------------- | -------------------------------------------------------------------------------------------------- |
| `WeeklyReport`               | 필드 변경      | `headlineBody: String?` 추가, 기존 단일 `bestMomentTitle`/`bestMomentBody` 제거. 자녀별·주차별 1건 |
| `WeeklyReportDay`            | 기존 모델 사용 | 요일별 completed/early_completed 미션 수                                                           |
| `WeeklyReportKeyword`        | 기존 모델 사용 | `MissionFeedbackKeyword` 집계 결과. 입력이 없으면 0건                                              |
| `WeeklyReportBestMoment`     | 신규 테이블    | 베스트 모먼트 여러 건 저장. carousel 표시                                                          |
| `WeeklyReportImprovementTip` | 기존 모델 사용 | 심리적 에너지/카테고리 기반 추천 팁 연결                                                           |
| `MissionExecution`           | 변경 없음      | 주간 리포트 생성 여부, 요일별 수행 현황, 누적 수행시간의 원천                                      |
| `MissionFeedback`            | 변경 없음      | 아이 반응 긍정률, 부모 에너지, 미션 만족도, 베스트 모먼트 후보의 원천                              |
| `MissionFeedbackKeyword`     | 변경 없음      | 아이 관심 키워드 Top 3의 원천                                                                      |
| `MentalBatteryCheck`         | 변경 없음      | 사용자의 내면 상태 산출 원천                                                                       |
| `Notification`               | 기존 모델 사용 | 리포트 생성 시 `weekly_report_ready` 알림 생성                                                     |

> `docs/schema/08-report.md`의 TBD 중 "주간 리포트 생성 트리거"는 **월요일 00:00 KST 배치 생성**으로 확정한다. "자녀가 여러 명일 때"는 **자녀별 리포트**로 확정한다.

### Prisma schema diff

Figma `2183:6775`의 첫 카드가 제목(`지금 충분히 잘하고 계십니다.`)과 본문 문단을 분리해 보여주므로, 기존 `headline`은 제목으로 사용하고 본문 필드를 추가한다. 베스트 모먼트는 여러 개일 수 있으므로 기존 단일 `bestMomentTitle`/`bestMomentBody` 컬럼을 제거하고 별도 테이블로 분리한다.

```prisma
model WeeklyReport {
  // ... 기존 필드 유지
  headline     String
  headlineBody String?
  bestMoments  WeeklyReportBestMoment[]
}

model WeeklyReportBestMoment {
  id       String @id @default(uuid()) @db.Uuid
  reportId String @db.Uuid
  order    Int
  label    String?
  title    String
  body     String

  report WeeklyReport @relation(fields: [reportId], references: [id], onDelete: Cascade)

  @@unique([reportId, order])
}
```

- 마이그레이션: `pnpm prisma:migrate:dev --name weekly_report_best_moments`

### 생성 조건

```text
지난주 월요일 00:00:00 KST <= MissionExecution.completedAt <= 지난주 일요일 23:59:59 KST
AND MissionExecution.status IN ('completed', 'early_completed')
AND Child.deletedAt IS NULL
```

- 조건에 맞는 미션 수행이 1건 이상이면 `WeeklyReport`를 생성한다.
- 조건에 맞는 미션 수행이 0건이면 `WeeklyReport`를 생성하지 않는다.
- `completed` 또는 `early_completed` 상태의 `MissionExecution.completedAt`은 필수다.
- 주간 리포트의 기간 판정은 `completedAt` 기준으로 한다.

---

## 4. 레포별 작업 분해

| 레포               | 작업                                                                                              | 의존성       |
| ------------------ | ------------------------------------------------------------------------------------------------- | ------------ |
| `yougabell-api`    | 주간 리포트 생성 서비스/배치, 조회 endpoint, 알림 생성, OpenAPI export                            | 선행 (1순위) |
| `yougabell-web`    | `/weekly-report` 화면, 리포트 있음/없음/키워드 없음 상태, 하단 탭 또는 기존 navigation 연결       | api 완료 후  |
| `yougabell-mobile` | WebView safe-area, Android back, 푸시 알림 딥링크가 `/weekly-report?reportId=...`로 열리는지 확인 | web 후속     |
| `yougabell-admin`  | 초기 영향 없음. 리포트 생성 실패 모니터링 화면은 후속 운영 기능으로 분리                          | —            |

### 4.1 yougabell-api 상세 스펙

#### Prisma schema diff

화면 구현을 위해 `WeeklyReport.headlineBody`와 `WeeklyReportBestMoment`를 추가하고, 기존 단일 베스트 모먼트 컬럼은 제거한다.

```prisma
model WeeklyReport {
  // ... 기존 필드 유지
  headline     String
  headlineBody String?
  bestMoments  WeeklyReportBestMoment[]
}

model WeeklyReportBestMoment {
  id       String @id @default(uuid()) @db.Uuid
  reportId String @db.Uuid
  order    Int
  label    String?
  title    String
  body     String

  report WeeklyReport @relation(fields: [reportId], references: [id], onDelete: Cascade)

  @@unique([reportId, order])
}
```

- 마이그레이션: `pnpm prisma:migrate:dev --name weekly_report_best_moments`

#### 배치 — 주간 리포트 생성

**실행 시각**: 매주 월요일 00:00 KST.

**대상 기간**: 실행 시점 기준 지난주 월요일~일요일.

```typescript
type GenerateWeeklyReportsJobInput = {
  weekStart?: string; // YYYY-MM-DD, 수동 재실행/테스트용. 없으면 지난주 월요일
  dryRun?: boolean;
  forceRegenerate?: boolean;
};
```

**처리 로직**:

1. `weekStart`, `weekEnd`를 KST 기준으로 계산한다.
2. `deletedAt == null`인 active child를 조회한다.
3. 자녀별로 해당 주의 completed/early_completed `MissionExecution`을 `completedAt` 기준으로 조회한다.
4. 수행 이력이 0건이면 생성하지 않고 skip한다.
5. 수행 이력이 1건 이상이면 `childId + weekStart` unique 기준으로 기존 리포트 존재 여부를 확인한다. 정기 배치에서 이미 리포트가 있으면 skip하고, 수동 `forceRegenerate=true`일 때만 기존 리포트를 교체한다.
6. `WeeklyReportDay`는 월~일 7개 row를 만들고 요일별 완료 수를 저장한다.
7. `totalMissionDurationSeconds`는 `MissionExecution.actualDurationSeconds` 합계다. null이면 해당 미션의 `Mission.durationMinutes * 60`을 사용한다.
8. `childPositiveReactionRate`는 피드백이 있는 수행 중 `childReaction >= 4` 비율이다. 피드백이 0건이면 0으로 둔다.
9. `WeeklyReportKeyword`는 `MissionFeedbackKeyword.keyword`를 trim하고 연속 공백을 하나로 정리한 뒤 빈도순 Top 3으로 저장한다. 집계 비교 키는 한글 원문을 보존하되 영문자는 lowercase로 정규화한다. 동률이면 최초 입력 시각이 빠른 키워드를 우선한다.
10. 키워드가 0건이면 `WeeklyReportKeyword` row를 만들지 않는다.
11. `psychologicalEnergy`는 해당 주 `MentalBatteryCheck.level` 평균을 0~100으로 환산한다. 체크가 없으면 피드백의 `parentEnergy` 평균을 fallback으로 사용하고, 둘 다 없으면 50으로 둔다.
12. `headline`, `headlineBody`, `bestMoments`, `aiActionSuggestion`은 집계 데이터와 자녀 컨텍스트를 LLM에 전달해 생성한다. LLM 호출 실패 시 1분 → 5분 → 15분 간격으로 최대 3회 재시도한다.
13. LLM 재시도 3회가 모두 실패해도 리포트는 생성한다. 이 경우 집계 수치 기반 fallback 문구를 저장하고, 실패 원인은 서버 로그에 남긴다.
14. 생성 완료 후 `Notification(type='weekly_report_ready', actionType='open_report', targetType='weekly_report', targetId=report.id)` 알림을 생성한다.

**중복 실행 방지**:

- `WeeklyReport @@unique([childId, weekStart])`를 기준으로 같은 자녀·같은 주차 리포트는 1건만 존재한다.
- 정기 배치에서 이미 리포트가 있으면 재생성하지 않고 skip한다.
- 일반 사용자 화면에서는 생성된 리포트를 불변 데이터로 취급한다.
- 수동 재생성이 필요한 운영/개발 상황에서만 `forceRegenerate=true`로 기존 report와 `days`, `topKeywords`, `bestMoments`, `improvementTips`를 교체한다.

**초기 배치 실행 방식**:

- API 서버는 외부 cron이 호출할 internal endpoint만 제공한다.
- GitHub Actions schedule을 초기 cron provider로 사용한다.
- schedule은 `0 15 * * 0`이다. 이는 **일요일 15:00 UTC = 월요일 00:00 KST**다.
- GitHub Actions는 `POST /internal/weekly-reports/generate`를 호출한다.
- internal endpoint는 `x-cron-secret` 헤더와 API 서버의 `WEEKLY_REPORT_CRON_SECRET` 환경변수가 일치할 때만 실행한다.
- GitHub repository secrets:
  - `YOUGABELL_API_URL`: API production base URL
  - `WEEKLY_REPORT_CRON_SECRET`: API 서버의 `WEEKLY_REPORT_CRON_SECRET`과 같은 값
- `workflow_dispatch`로 수동 실행할 수 있으며 `weekStart`, `dryRun`, `forceRegenerate`를 입력할 수 있다.
- 장기적으로 API 호스팅이 확정되면 해당 호스팅의 managed cron/queue로 대체할 수 있다.

#### 엔드포인트 — `GET /weekly-reports/current`

현재 사용자가 확인해야 할 **직전 완료 주차**의 자녀별 주간 리포트를 조회한다. 예를 들어 2026-05-13 수요일에 진입하면 2026-05-04(월)~2026-05-10(일) 리포트를 조회한다.

**인증**: `Authorization: Bearer <Supabase JWT>` 필수. `JwtAuthGuard` + `OnboardingCompleteGuard` 적용.

**Query**:

```typescript
type GetCurrentWeeklyReportQuery = {
  childId?: string; // 없으면 displayOrder 가장 앞 active child
  weekStart?: string; // YYYY-MM-DD, 과거 주차 조회용. 없으면 직전 완료 주차
};
```

**Response 200**:

```typescript
type WeeklyReportCurrentResponse = {
  selectedChild: {
    id: string;
    name: string;
    ageLabel: string;
  };
  report: WeeklyReportDetail | null;
  emptyState: null | {
    reason:
      | 'no_mission_yet'
      | 'no_mission_for_week'
      | 'report_generation_pending';
    title: string;
    description: string;
    ctaLabel: '미션 시작하기';
    ctaHref: '/mission';
  };
};

type WeeklyReportDetail = {
  id: string;
  weekStart: string; // YYYY-MM-DD
  weekEnd: string; // YYYY-MM-DD
  generatedAt: string;
  headline: {
    question: '나는 잘하고 있는가?';
    title: string; // "지금 충분히 잘하고 계십니다."
    body: string | null;
  };
  missionSummary: {
    days: Array<{
      weekday: 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun';
      label: '월' | '화' | '수' | '목' | '금' | '토' | '일';
      completedCount: number;
      completed: boolean;
    }>;
    totalDurationSeconds: number;
    totalDurationLabel: string; // "1시간 17분"
    childPositiveReactionRate: number; // 0..100
  };
  topKeywords: Array<{
    rank: 1 | 2 | 3;
    keyword: string;
  }>;
  keywordEmptyState: null | {
    title: '아직 키워드가 충분하지 않아요';
    description: string;
  };
  bestMoments: Array<{
    id: string;
    order: number;
    label?: string; // 예: "순수한 기쁨"
    title: string;
    body: string;
  }>;
  innerState: {
    psychologicalEnergy: number; // 0..100
    tipTitle: string;
    tipBody?: string;
  };
  aiActionSuggestion: {
    title: '미래 행동 제안 (AI 기반)';
    body: string;
  };
};
```

**emptyState 정책**:

| 상황                                      | `report` | `emptyState.reason`         | 화면                                         |
| ----------------------------------------- | -------- | --------------------------- | -------------------------------------------- |
| 사용자가 앱 설치 후 미션을 한 번도 안 함  | `null`   | `no_mission_yet`            | Figma `2183:3895` 기준                       |
| 조회 대상 주차에 미션이 없어 리포트 없음  | `null`   | `no_mission_for_week`       | 같은 empty layout, 문구만 주차 기준으로 조정 |
| 리포트는 있으나 키워드 입력이 0건         | report   | `null`                      | 데이터 있음 화면 + 키워드 섹션 empty state   |
| 월요일 00:00 직후 배치가 아직 끝나지 않음 | `null`   | `report_generation_pending` | 준비 중 안내                                 |

`report_generation_pending` copy:

```text
title: 리포트를 준비 중이에요
description: 준비가 완료되면 적당한 시간에 알림으로 알려드릴게요.
ctaLabel: 미션 시작하기
```

**키워드 empty copy**:

```text
title: 아직 키워드가 충분하지 않아요
description: 미션 후 피드백에서 아이가 자주 말한 단어를 남겨보세요. 다음 리포트에서 아이의 관심사가 더 선명하게 보여요.
```

**에러 응답**:

| 상태 | code                  | 의미                                    |
| ---- | --------------------- | --------------------------------------- |
| 400  | `VALIDATION_ERROR`    | `childId` 형식 오류                     |
| 401  | `UNAUTHORIZED`        | JWT 없음/만료                           |
| 403  | `ONBOARDING_REQUIRED` | 온보딩 미완료                           |
| 404  | `CHILD_NOT_FOUND`     | 자녀 없음 또는 사용자 소유 자녀가 아님  |
| 409  | `NO_CHILD_PROFILE`    | 온보딩 완료 상태이나 active 자녀가 없음 |
| 500  | `INTERNAL_ERROR`      | 조회/집계 실패                          |

#### 엔드포인트 — `GET /weekly-reports/:id`

알림 딥링크나 과거 리포트 상세 진입을 위해 id 조회를 제공한다.

- 인증/소유권 검증 필수
- 응답 타입은 `WeeklyReportDetail`
- report가 존재하지 않거나 소유자가 아니면 `404 WEEKLY_REPORT_NOT_FOUND`

#### OpenAPI export

- `GET /weekly-reports/current`
- `GET /weekly-reports/:id`
- 배치 수동 실행 endpoint를 만들 경우 운영자 guard를 적용하고 OpenAPI에는 admin tag로 분리

### 4.2 yougabell-web 상세 스펙

#### 라우트 구조

```
app/
└── (main)/
    └── weekly-report/
        └── page.tsx

components/
└── weekly-report/
    ├── weekly-report-screen.tsx
    ├── weekly-report-empty.tsx
    ├── mission-week-summary.tsx
    ├── weekly-keyword-section.tsx
    ├── best-moment-card.tsx
    ├── inner-state-card.tsx
    └── ai-action-suggestion-card.tsx
```

#### 상태 스키마

```typescript
type WeeklyReportClientState = {
  selectedChildId: string | null;
  isLoading: boolean;
  error: WeeklyReportError | null;
};
```

- 선택 자녀는 홈과 같은 localStorage 키(`home:selected-child-id`)를 재사용한다.
- 리포트 화면에서 자녀 피커를 바로 제공할지 여부는 후속 디자인에서 확정한다. 초기 구현은 홈에서 선택된 자녀 기준으로 조회한다.

#### 훅 인터페이스

```typescript
function useWeeklyReport(initialChildId?: string): {
  data: WeeklyReportCurrentResponse | null;
  refetch: () => Promise<void>;
  isLoading: boolean;
  error: WeeklyReportError | null;
};
```

#### 컴포넌트 인터페이스

```typescript
type WeeklyReportScreenProps = {
  data: WeeklyReportCurrentResponse;
  onBack: () => void;
  onOpenNotifications: () => void;
  onStartMission: () => void;
};

type WeeklyReportEmptyProps = {
  reason:
    | 'no_mission_yet'
    | 'no_mission_for_week'
    | 'report_generation_pending';
  title: string;
  description: string;
  ctaLabel: string;
  onStartMission: () => void;
};

type WeeklyKeywordSectionProps = {
  keywords: WeeklyReportDetail['topKeywords'];
  emptyState: WeeklyReportDetail['keywordEmptyState'];
};
```

#### UI 상태

| 상태        | 기준 디자인/동작                                                                                          |
| ----------- | --------------------------------------------------------------------------------------------------------- |
| 리포트 있음 | `2183:6775`. 상단 LNB, "나는 잘하고 있는가?", 이번주 요약, 키워드, 베스트 모먼트, 내면 상태, AI 제안 순서 |
| 리포트 없음 | `2183:3895`. 중앙 empty illustration, "아직 주간 리포트가 없습니다", 설명, "미션 시작하기" CTA            |
| 키워드 없음 | 데이터 있음 화면 안에서 "아이의 관심 키워드 Top 3" 제목 유지. 칩 대신 안내 카드 표시                      |
| API 실패    | 토스트 또는 inline error + 재시도. 에러 안내와 재시도 버튼을 보여준다.                                    |
| 로딩        | 상단 LNB는 유지하고 본문 skeleton 표시                                                                    |
| 알림 클릭   | 상단 bell은 홈과 같은 알림 모달을 열거나 `/notifications` 흐름으로 이동. 홈 구현과 통일                   |

#### 키워드 없음 화면 문구

```text
키워드가 충분하지 않아요
미션 후 피드백에서 아이가 자주 말한 단어를 남겨보세요. 다음 리포트에서 아이의 관심사가 더 선명하게 보여요.
```

#### navigation

- 뒤로가기: 이전 화면 history back. history가 없으면 `/` 홈으로 이동
- "미션 시작하기": `/mission`
- 하단 탭 "주간 리포트": `/weekly-report`
- 알림 `targetType='weekly_report'`: `/weekly-report?reportId=<id>`로 진입한다.

### 4.3 yougabell-mobile 상세 스펙

홈과 동일하게 UI는 web이 담당한다.

| 항목           | 책임   | 요구 사항                                                                  |
| -------------- | ------ | -------------------------------------------------------------------------- |
| Safe area      | web    | iOS home indicator와 CTA/본문이 겹치지 않도록 `safe-area-inset-bottom`     |
| Android back   | mobile | web history 우선. 리포트 화면에서 back 시 이전 화면 또는 홈으로 이동       |
| Push 알림      | mobile | `weekly_report_ready` 푸시 수신 시 WebView를 `/weekly-report?reportId=...` |
| WebView cookie | mobile | Supabase 세션 유지                                                         |

### 4.4 엣지 케이스

| 상황                                      | 처리                                                                                                                    |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 앱 설치 후 미션 수행 0건                  | Figma `2183:3895` 기준 empty state                                                                                      |
| 지난주 미션 수행 0건                      | 리포트 row 없음. "지난주에는 리포트로 만들 기록이 없었어요. 이번 주 미션을 시작해보세요." 표시                          |
| 미션은 했지만 피드백 키워드 0건           | 리포트 표시. 키워드 섹션은 empty state                                                                                  |
| 미션은 했지만 MissionFeedback 0건         | 아이 반응 긍정률 0%, 키워드 없음. AI 문구에는 피드백 부족 상태 반영                                                     |
| MentalBatteryCheck 0건                    | `parentEnergy` fallback. 둘 다 없으면 심리적 에너지 50%                                                                 |
| LLM 생성 실패                             | 1분 → 5분 → 15분 간격으로 최대 3회 재시도. 모두 실패해도 fallback 문구로 리포트 생성                                    |
| 다자녀 중 A는 미션 있음, B는 미션 없음    | A는 리포트 있음, B는 empty state                                                                                        |
| 삭제된 자녀                               | 조회/생성 대상에서 제외. `current` 조회와 상세 id 조회 모두 active child만 허용                                         |
| 배치 중복 실행                            | 정기 배치는 기존 리포트가 있으면 skip. 수동 `forceRegenerate=true`일 때만 기존 리포트와 하위 집계 교체                  |
| 월요일 00:00 직후 아직 배치가 끝나지 않음 | `report_generation_pending` empty state. "리포트를 준비 중이에요. 준비가 완료되면 적당한 시간에 알림으로 알려드릴게요." |

---

## 5. UI/디자인 참조

| 화면/상태          | Figma 노드  | 상태 | 비고                                                                   |
| ------------------ | ----------- | ---- | ---------------------------------------------------------------------- |
| 리포트 있음        | `2183:6775` | 기준 | `Weekly Report_v03`. 전체 화면 구조 기준                               |
| 리포트 없음        | `2183:3895` | 기준 | `미션 최초 수행 전`. 미션 수행 이력이 없는 사용자 empty state          |
| 상단 LNB           | `2183:6788` | 기준 | back, title `주간 리포트`, bell                                        |
| 격려 카드          | `2183:6795` | 기준 | `나는 잘하고 있는가?`, `지금 충분히 잘하고 계십니다.`                  |
| 이번주 요약        | `2183:6803` | 기준 | 미션 요일 row, 누적 수행시간, 아이 반응 긍정률                         |
| 키워드 Top 3       | `2183:6855` | 기준 | `공룡`, `우주`, `아이스크림` 샘플. 실제 데이터는 feedback keyword 집계 |
| 베스트 모먼트      | `2183:6876` | 기준 | 여러 개일 수 있으며 carousel indicator 포함                            |
| 사용자의 내면 상태 | `2183:6886` | 기준 | 심리적 에너지 bar와 팁                                                 |
| AI 행동 제안       | `2183:6899` | 기준 | `미래 행동 제안 (AI 기반)`                                             |
| empty CTA          | `2183:3911` | 기준 | `미션 시작하기`                                                        |

### 디자인에서 가져올 것 / 재해석할 것

| 가져올 것                                         | 재해석할 것                                                                |
| ------------------------------------------------- | -------------------------------------------------------------------------- |
| 리포트 섹션 순서와 정보 구조                      | Figma의 absolute 좌표, iOS status bar asset                                |
| 카드 단위 구성과 여백감                           | 색상·radius는 `yougabell-web/DESIGN.md` role token 기준                    |
| 미션 수행 요일 row, 누적 시간, 긍정률의 요약 구조 | 요일 아이콘은 직접 export asset보다 lucide/icon token 또는 CSS 상태로 구현 |
| 키워드 chip 구조                                  | 키워드별 색상은 rank 기반 variant로 정의                                   |
| empty state의 중앙 정렬과 CTA                     | empty illustration은 임시 shape 또는 디자인 asset 확정 후 교체             |
| AI 제안 카드의 독립 섹션                          | 문구는 LLM 생성 + fallback copy 사용                                       |

### LLM fallback copy

LLM 호출이 3회 모두 실패하면 아래 문구를 저장한다. 리포트 생성 자체는 실패시키지 않는다.

```text
headline.title: 이번 주도 아이와의 시간을 잘 쌓아가고 있어요.
headline.body: 짧은 시간이라도 꾸준히 함께한 기록은 아이에게 안정감을 줍니다. 이번 주의 미션 기록을 바탕으로 다음 주에도 부담 없이 이어가보세요.

bestMoments[0].label: 이번 주의 순간
bestMoments[0].title: 함께한 시간이 쌓였어요
bestMoments[0].body: 이번 주에 완료한 미션 기록을 바탕으로 아이와 연결된 시간을 확인했어요.

aiActionSuggestion.body: 다음 미션 후 피드백에 아이가 자주 말한 단어나 기억에 남는 반응을 남겨보세요. 다음 리포트에서 아이의 관심사와 변화를 더 자세히 보여드릴게요.
```

---

## 6. 비기능 요구

### 저장 전략

**서버 생성 + 서버 저장 + web 조회.**

```
[월요일 00:00 KST 배치]
MissionExecution / MissionFeedback / MentalBatteryCheck
  └─ aggregate + LLM
      └─ WeeklyReport + WeeklyReportDay + WeeklyReportKeyword 저장

[사용자 화면 진입]
web /weekly-report
  └─ GET /weekly-reports/current?childId=...
      └─ report 있음/없음 상태 렌더
```

- **서버 DB**: `WeeklyReport*` 테이블에 생성 결과 저장
- **로컬 저장**: 선택 자녀 id만 홈과 같은 localStorage 키 재사용
- **단계별 저장**: 없음. 배치 생성은 자녀별 atomic transaction
- **영속성 등급**: 리포트는 히스토리 데이터이므로 사용자 삭제 전까지 보존
- **멀티 디바이스**: 서버 조회이므로 지원
- **캐시**: report는 생성 후 불변에 가깝다. `reportId` 상세는 장기 cache 가능. current 조회는 childId/weekStart 기준 짧은 TTL 또는 tag revalidation

### 그 외

- **성능**:
  - 화면 조회는 `GET /weekly-reports/current` 1회 호출
  - 배치는 자녀별 transaction으로 분리해 일부 실패가 전체 실패로 번지지 않게 한다.
- **보안**:
  - 모든 조회는 userId + child ownership 검증
  - 배치 수동 실행 endpoint를 만들 경우 운영자 guard 필수
  - LLM 프롬프트에는 필요한 주간 요약 데이터와 자녀 컨텍스트만 전달
- **접근성**:
  - back/bell/CTA는 button 요소
  - 미션 요일 row는 요일별 `aria-label` 제공
  - progress bar는 `role="progressbar"` + `aria-valuenow`
  - 키워드 chip은 텍스트만으로 의미 전달
- **분석 이벤트**:
  - `weekly_report_view`
  - `weekly_report_empty_view`
  - `weekly_report_start_mission_click`
  - `weekly_report_keyword_empty_view`
  - `weekly_report_ai_suggestion_view`
  - `weekly_report_notification_click`

---

## 7. 리스크·미해결 질문

- [x] ~~주간 리포트 생성 트리거~~ → **월요일 00:00 KST에 지난주 월~일 기준으로 생성** (2026-05-13)
- [x] ~~미션 수행 0건인 주의 리포트 생성 여부~~ → **생성하지 않음. 화면은 empty state** (2026-05-13)
- [x] ~~다자녀 리포트 단위~~ → **자녀별 주간 리포트** (2026-05-13)
- [x] ~~키워드 입력이 0건일 때 처리~~ → **리포트는 표시하고 키워드 섹션만 empty state** (2026-05-13)
- [x] ~~리포트 기본 조회 주차~~ → **직전 완료 주차를 기본으로 조회. 과거 주차는 `weekStart` query로 조회** (2026-05-13)
- [x] ~~배치 실패/지연 시 사용자 안내~~ → **`report_generation_pending` empty state로 "리포트를 준비 중이에요. 준비가 완료되면 적당한 시간에 알림으로 알려드릴게요." 표시** (2026-05-13)
- [x] ~~베스트 모먼트 개수~~ → **여러 개 가능. API는 `bestMoments[]`, web은 carousel로 표시** (2026-05-13)
- [x] ~~LLM 생성 실패 fallback 문구 세트~~ → **최대 3회 재시도 후 집계 기반 fallback 문구로 리포트 생성** (2026-05-13)
- [x] ~~리포트 상세 라우트~~ → **`/weekly-report?reportId=<id>` query route로 확정** (2026-05-13)

---

## 8. Phase별 작업 todo

> 진행 시 `- [ ]` → `- [x]`로 갱신. PR 머지 시 본 섹션을 진행 추적의 단일 소스로.

### Phase 0 — 기획 확정 (선행)

- [x] 데이터 있음/없음 Figma 노드 확인
- [x] 생성 트리거 확정 — 월요일 00:00 KST
- [x] 미션 수행 0건이면 리포트 생성 안 함
- [x] 키워드 없음 상태 정책 확정
- [x] current 조회 기준 확정 — 직전 완료 주차
- [x] 베스트 모먼트 개수 확정 — 여러 개 가능

### Phase 1 — `yougabell-api` (선행, 다른 레포 시작 차단)

- [x] `WeeklyReportDetail` DTO 정의
- [x] Prisma schema 갱신: `WeeklyReport.headlineBody`, `WeeklyReportBestMoment`
- [x] 마이그레이션 실행 (`weekly_report_best_moments`)
- [x] `GET /weekly-reports/current` endpoint 구현
- [x] `GET /weekly-reports/:id` endpoint 구현
- [x] active child 선택/소유권 검증
- [x] 주간 리포트 생성 서비스 구현
- [x] 월요일 00:00 KST 배치 트리거 구현 — GitHub Actions external cron (`0 15 * * 0`)
- [x] 자녀별 중복 실행 방지 구현 — 정기 배치 skip, 수동 force 재생성
- [x] `WeeklyReportDay` 생성
- [x] `WeeklyReportKeyword` Top 3 집계
- [x] 키워드 없음 응답 상태 구현
- [x] `psychologicalEnergy` 산식 구현
- [x] LLM 기반 `headline`/`bestMoments`/`aiActionSuggestion` fallback 구현
- [x] `weekly_report_ready` 알림 생성
- [x] OpenAPI 스펙 export 갱신
- [x] 테스트: 미션 0건이면 report 미생성
- [x] 테스트: 키워드 0건이면 report 생성 + `topKeywords=[]`
- [x] 테스트: child ownership

### Phase 2 — `yougabell-web` (api 완료 후)

- [ ] `/weekly-report` route 구현
- [ ] `WeeklyReportScreen` 구현
- [ ] `WeeklyReportEmpty` 구현
- [ ] `MissionWeekSummary` 구현
- [ ] `WeeklyKeywordSection` 구현
- [ ] 키워드 없음 empty card 구현
- [ ] `BestMomentCard` 구현
- [ ] `InnerStateCard` 구현
- [ ] `AiActionSuggestionCard` 구현
- [ ] `useWeeklyReport()` 또는 data loader 구현
- [ ] API 로딩/에러/빈 상태 처리
- [ ] "미션 시작하기" CTA `/mission` 연결
- [ ] 알림 bell 동작을 홈과 통일
- [ ] 분석 이벤트 발사
- [ ] WebView safe area 적용

### Phase 3 — `yougabell-mobile` (web 후속)

- [ ] push/deeplink으로 `/weekly-report?reportId=...` 진입 확인
- [ ] Android back 버튼 동작 확인
- [ ] iOS safe-area 확인

### Phase 4 — `yougabell-admin` (해당 없음)

- [ ] —

### Phase 5 — 통합 검증

- [ ] 골든 패스: 미션 수행 + 피드백 + 마음 체크 → 월요일 배치 → 리포트 표시
- [ ] 미션 0건 사용자 → empty state + 미션 시작 CTA
- [ ] 미션은 있으나 키워드 0건 → 키워드 empty state
- [ ] 다자녀: 자녀별 리포트 분리
- [ ] 알림 클릭 → 해당 리포트 화면 진입
- [ ] 다른 사용자 reportId 조회 시 404/403
- [ ] mobile WebView safe-area 확인
- [ ] LLM 실패 시 fallback 문구로 리포트 생성

---

## 9. 구현 결과 (구현 완료 후 채움)

- 관련 PR: [`api#…`], [`web#…`], [`mobile#…`]
- 마이그레이션 이름: —
- 스펙 변경점: —
- 후속 과제: —
