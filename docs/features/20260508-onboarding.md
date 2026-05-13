# 온보딩 (Onboarding v2)

> 작성일: 2026-05-08 · 작성자: — · 상태: `draft`
> Figma 파일: [Yougabell OS Figma](https://www.figma.com/design/sKdG5GEBZPdMjFY9nYj5g0)
>
> **해당 Figma 노드는 와이어프레임** — 색상·간격·폰트 등 시각 디자인은 미확정. **기능·컴포넌트 위치·필드 구성만 참고**한다. 최종 비주얼은 `yougabell-web/DESIGN.md` 토큰 적용 시점에 별도 디자인 단계에서 확정.

---

## 1. 배경 (Why)

육아밸의 핵심 가치는 **사용자 정보 기반 맞춤 답변**(`AGENTS.md` L7). 이를 위해 첫 진입 시 부모·자녀의 기본 정보와 양육 환경을 수집해야 한다.

기존 온보딩 v1(`docs/schema/01-user.md`)은 인트로 → 본인 정보 → 자녀 정보 3단계였으나, 새 디자인(2026-05-08, 노드 `2010:*`)은 다음 두 가지를 보강:

- **부모 직장 유무** (선택) — 워킹맘/대디 타깃 식별로 콘텐츠 큐레이션 분기에 사용. 2026-05-08 기획 변경으로 **필수 → 선택**.
- **앱 사용 시간대** (전 사용자) — 미션 알림·푸시 발송 시각 결정의 입력값. 직장 유무와 무관하게 모든 사용자가 입력. (당초 "아이와 함께 있는 시간"으로 표현됐으나 의미를 명확화)

v2 인트로 구성(화면 수·내용)은 **미정** — 와이어프레임의 페이지네이션 점에서 다화면 캐러셀일 가능성이 보이지만, 노드 1개(`2010:20343`)만 확보된 상태. 디자인 확정본에서 확인 예정.

---

## 2. 사용자 시나리오 (What)

- **누가**: 첫 회원가입(Supabase Auth) 직후의 사용자(워킹맘/대디)
- **언제**: 가입 후 자동 진입. 미완료 시 홈 진입 시 강제 리디렉션.
- **흐름**:
  1. 인트로 — 내용·화면 수 미정 (디자인 확정본에서 확인). 우상단 "건너뛰기" 패턴은 유지 가정.
  2. **본인 정보** — 이름, 생년월일, 성별(여성/남성). 직장 유무는 **선택**(일을 하고 있어요 / 전업 가정인이에요 / 미응답)
  3. **자녀 정보** — 이름, 생년월일, 성별(여아/남아), 특이사항. "자녀 추가" 버튼으로 다자녀 입력
  4. **앱 사용 시간대** — (v3, Figma `2146:4530`, 2026-05-12) **단일 시간대 선택 + 직접 입력**. 5개 카드(오전 08-09 / 오후 12-13 / 저녁 18-20 / 밤 22+ / 직접 입력) 중 1개 선택. preset 선택 시 시간 칩(예: 07:30/08:00/08:30/09:00)으로 세부 시각 변경 가능, custom 선택 시 `<input type="time">`로 HH:MM 입력. 기존 7×5 요일×시간대 매트릭스(v1/v2)는 폐기.
  5. 완료 → 홈
- **수용 기준**:
  - 필수(`*`) 필드: 본인 이름·생년월일·성별, 자녀 1명 이상의 이름·생년월일·성별. 직장 유무는 **선택**
  - 인트로 "건너뛰기"는 본인 정보까지만 스킵, 자녀 정보·앱 사용 시간대는 필수
  - 다자녀 N명 등록 가능 (최소 1명)
  - 앱 사용 시간대 검증 룰은 새 디자인 수령 후 확정

---

## 3. 도메인 영향

새 화면이 요구하는 모델 변경.

| 엔티티                           | 변경 종류                                                                                    | 비고                                                                                                          |
| -------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `User.workStatus`                | 필드 추가 — `enum('working','full_time_caregiver') NULLABLE` (**선택**)                      | 새 화면 `2010:20364` "직장 유무". 2026-05-08 기획 변경으로 nullable 확정. 미응답 시 콘텐츠 분기 X.            |
| `User.notificationSlot` (**v3**) | 필드 추가 — `NotificationSlot? enum('morning','afternoon','evening','night','custom')`       | Figma `2146:4530`. 단일 선택. v2 `appUsageSlots[]` 매트릭스 폐기.                                             |
| `User.notificationTime` (**v3**) | 필드 추가 — `String?` `"HH:MM"`                                                              | custom일 때 필수, preset일 때 선택(미지정 시 시간대 디폴트: 오전 08:00 / 오후 12:00 / 저녁 18:00 / 밤 22:00). |
| `User.onboardedAt`               | 필드 추가 — `DateTime?`. 온보딩 완료 시각 1회 기록                                           | 강제 리디렉션 판단(서버 측 단일 boolean 역할). 단계 진척은 클라이언트가 추적                                  |
| `Child`                          | 변경 없음 (기존 `01-user.md`/`02-child.md` 명세와 일치)                                      | name / birthDate / gender / **notes (자유 텍스트, AI 챗봇 컨텍스트 입력)**                                    |
| ~~`UserAppUsageSlot`~~ (**v3**)  | **폐기** — v2 요일×시간대 1:N 테이블. v3에서 `User.notificationSlot/notificationTime`로 흡수 | Prisma 모델·`TimeSlot` enum 삭제. `Weekday` enum은 `WeeklyReportDay`에서 계속 사용.                           |
| ~~`OnboardingProgress`~~         | **불필요** — 단계 진척은 디바이스 로컬에서만 추적. DB는 완료 여부(`User.onboardedAt`)만 보유 | 부분 데이터로 DB 점유하지 않음                                                                                |

> 도메인 변경 반영: [`../schema/01-user.md`](../schema/01-user.md) 참조.

### 알림 시간대 모델 — v3 (단일 선택)

> v2의 `UserAppUsageSlot` 1:N 매트릭스는 폐기. **User 1행에 알림 시간대 1건**을 직접 저장한다 (Figma `2146:4530`).

```prisma
model User {
  // ...
  notificationSlot NotificationSlot?  // 미선택 = null (온보딩 미완료)
  notificationTime String?            // "HH:MM" — custom 필수, preset 선택
  // ...
}

enum NotificationSlot {
  morning   // 디폴트 08:00 (08:00-09:00)
  afternoon // 디폴트 12:00 (12:00-13:00)
  evening   // 디폴트 18:00 (18:00-20:00)
  night     // 디폴트 22:00 (22:00 이후)
  custom    // notificationTime 직접 지정
}
```

검증 룰:

- `notificationSlot`이 `custom`이면 `notificationTime` 필수.
- preset(`morning/afternoon/evening/night`)이면 `notificationTime`은 시간 칩 중 하나 또는 null(디폴트 사용).
- `notificationTime` 포맷: `^([01]\d|2[0-3]):[0-5]\d$`.

---

## 4. 레포별 작업 분해

| 레포               | 작업                                                                                                                                                                                                                                     | 의존성       |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ |
| `yougabell-api`    | Prisma — `User.workStatus` (nullable), `User.onboardedAt: DateTime?`, **v3**: `User.notificationSlot/notificationTime` (v2 `UserAppUsageSlot`·`TimeSlot` 제거), 마이그레이션                                                             | 선행 (1순위) |
|                    | Onboarding 컨트롤러 — **`POST /onboarding/complete`** (Parent + Child[] + Notification 단건 atomic) + `GET /me`(onboardedAt 포함)                                                                                                        | 1순위        |
|                    | Auth Guard — `User.onboardedAt == null` 사용자 식별 (보호 라우트에서 401/403 또는 redirect 힌트 응답)                                                                                                                                    | 1순위        |
|                    | OpenAPI export 갱신                                                                                                                                                                                                                      | 1순위 후속   |
| `yougabell-web`    | 라우트 — `app/onboarding/intro/`, `parent/`, `children/`, `app-usage/`, `done/`                                                                                                                                                          | api 완료 후  |
|                    | 컴포넌트 — `IntroScreen`(intro 인라인), `DateInput`(단일 입력 + chevron 네이티브 피커), `SegmentedToggle`(직장 유무 allowDeselect), `ChildCardForm`+`ChildRow`(편집/알약 토글), `NotificationSlotPicker`(5카드 + 시간 칩 + custom HH:MM) | api 후속     |
|                    | **로컬 저장소 훅** — `useOnboardingDraft()`: localStorage `onboarding:draft:v3` read/write/clear. 단계 이동 시 자동 저장, 완료 응답 200 후 clear                                                                                         | api와 병행   |
|                    | **재개 UX** — `/(onboarding)/intro` 진입 시 draft 존재하면 "이어서 작성하기 / 처음부터" 다이얼로그                                                                                                                                       | api 후속     |
|                    | `proxy.ts` — 인증된 사용자 중 `me.onboardedAt == null`이면 `/onboarding/...` 외 차단                                                                                                                                                     | api 후속     |
| `yougabell-admin`  | 운영자 화면에서 `workStatus`(nullable), `notificationSlot`/`notificationTime` 표시(읽기 전용, 마스킹 룰 따름)                                                                                                                            | api 후속     |
| `yougabell-mobile` | WebView 컨테이너 + 인증 토큰 브릿지 + `ONBOARDING_COMPLETE` postMessage 수신 후 푸시 권한 요청                                                                                                                                           | api/web 병행 |

---

### 4.1 yougabell-api 상세 스펙

#### Prisma schema diff (`yougabell-api/prisma/schema.prisma`)

```prisma
// User: v2(두 Float 필드)에서 workStatus/onboardedAt 추가 → v3에서 algorithmic notification 흡수
model User {
  // ... 기존 필드 유지
- weekdayHoursWithChild Float?
- weekendHoursWithChild Float?
+ workStatus            WorkStatus?       // nullable (선택 입력)
+ notificationSlot      NotificationSlot? // v3: 단일 시간대 선택 (Figma 2146:4530)
+ notificationTime      String?           // v3: "HH:MM" (custom 필수, preset 선택)
+ onboardedAt           DateTime?         // nullable. 온보딩 완료 시각 1회 기록
- appUsageSlots         UserAppUsageSlot[] // v3에서 폐기
}

// 신규 enum (lowercase — 기존 schema 컨벤션)
enum WorkStatus {
  working               // "일을 하고 있어요"
  full_time_caregiver   // "전업 가정인이에요"
}

// v3 신규 enum — v2의 TimeSlot/UserAppUsageSlot 대체
enum NotificationSlot {
  morning   // 디폴트 08:00 (08:00-09:00)
  afternoon // 디폴트 12:00 (12:00-13:00)
  evening   // 디폴트 18:00 (18:00-20:00)
  night     // 디폴트 22:00 (22:00 이후)
  custom    // notificationTime 직접 지정
}

// 폐기 (v3): UserAppUsageSlot, TimeSlot enum.
// Weekday enum은 WeeklyReportDay에서 계속 사용하므로 유지.
```

- 마이그레이션: v3 도입 시 `pnpm prisma:migrate:dev --name onboarding_v3_notification`
- `Child` 모델은 변경 없음. 다만 `displayOrder`가 필수 필드라 서비스에서 **입력 순서 idx로 자동 할당**
- 명명 컨벤션: 기획서 초안의 PascalCase 대신 기존 schema의 **lowercase**를 따름 (`docs/schema/AGENTS.md` "Prisma가 코드 진실의 소스" 원칙)

#### 엔드포인트 — `POST /onboarding/complete`

**인증**: `Authorization: Bearer <Supabase JWT>` 필수. `JwtAuthGuard`로 검증.

**Request body** (`CompleteOnboardingDto`):

```typescript
{
  parent: {
    name: string;            // required, 1~30자
    birthDate: string;       // required, "YYYY-MM-DD"
    gender: 'female' | 'male'; // required
    workStatus?: 'working' | 'full_time_caregiver' | null; // optional
  };
  children: Array<{          // required, 최소 1개. 입력 순서대로 displayOrder 자동 할당
    name: string;            // required, 1~30자
    birthDate: string;       // required, "YYYY-MM-DD"
    gender: 'female' | 'male'; // required
    notes?: string;          // optional, 자유 텍스트, 최대 1000자
  }>;
  notification: {            // required (v3 단건)
    slot: 'morning'|'afternoon'|'evening'|'night'|'custom';
    time?: string;           // "HH:MM" — custom 필수, preset 선택(미지정 시 시간대 디폴트)
  };
}
```

**검증 룰** (`class-validator` 사용):

- `parent.name`: `@IsString() @Length(1,30)`
- `parent.birthDate`: `@IsDateString()`. 미래 날짜 거부, 1900-01-01 이후
- `parent.gender`: `@IsIn(['female','male'])`
- `parent.workStatus`: `@IsOptional() @IsIn([...])`
- `children`: `@IsArray() @ArrayMinSize(1) @ValidateNested({ each: true })`
- `children[].notes`: `@IsOptional() @IsString() @MaxLength(1000)`
- `notification.slot`: `@IsEnum(['morning','afternoon','evening','night','custom'])`
- `notification.time`: `@IsOptional() @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)`. `slot === 'custom'`이면 필수 (서비스 레이어 추가 검증).

**처리 로직** (Prisma 트랜잭션 — atomic):

```typescript
await prisma.$transaction(async (tx) => {
  // 1. 멱등성: 이미 완료한 사용자는 409
  const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
  if (user.onboardedAt)
    throw new ConflictException({
      code: "ONBOARDING_ALREADY_COMPLETED",
      onboardedAt: user.onboardedAt,
    });

  // 2. User 갱신 (parent 정보 + workStatus + onboardedAt)
  await tx.user.update({
    where: { id: userId },
    data: {
      name: dto.parent.name,
      birthDate: new Date(dto.parent.birthDate),
      gender: dto.parent.gender,
      workStatus: dto.parent.workStatus ?? null,
      onboardedAt: new Date(),
    },
  });

  // 3. Child[] insert
  await tx.child.createMany({
    data: dto.children.map((c) => ({
      userId,
      name: c.name,
      birthDate: new Date(c.birthDate),
      gender: c.gender,
      notes: c.notes ?? null,
    })),
  });

  // 4. 알림 시간대 단건 적용 (v3: User 컬럼에 직접 저장)
  await tx.user.update({
    where: { id: userId },
    data: {
      notificationSlot: dto.notification.slot,
      notificationTime: dto.notification.time ?? null,
    },
  });
});
```

**Response 200** — 갱신된 `me` 객체 그대로 반환 (클라이언트가 별도 GET /me 호출 안 해도 됨):

```typescript
{
  id: string;
  email: string;
  name: string;
  birthDate: string;     // ISO 8601
  gender: 'female' | 'male';
  workStatus: 'working' | 'full_time_caregiver' | null;
  onboardedAt: string;   // ISO 8601
  children: Child[];
  notificationSlot: 'morning'|'afternoon'|'evening'|'night'|'custom' | null;
  notificationTime: string | null; // "HH:MM"
}
```

**에러 응답**:

| 상태 | code                           | 의미                                              |
| ---- | ------------------------------ | ------------------------------------------------- |
| 400  | `VALIDATION_ERROR`             | 검증 실패 (필드별 메시지는 표준 NestJS 응답 형태) |
| 401  | `UNAUTHORIZED`                 | JWT 없음/만료                                     |
| 409  | `ONBOARDING_ALREADY_COMPLETED` | 이미 완료한 사용자가 재호출. body에 `onboardedAt` |
| 500  | `INTERNAL_ERROR`               | 트랜잭션 실패                                     |

#### 엔드포인트 — `GET /me`

기존 응답에 `onboardedAt`, `workStatus`, `notificationSlot`, `notificationTime` 추가. 미완료 사용자는 `onboardedAt: null`로 응답 (라우트 자체는 `JwtAuthGuard`만, 온보딩 가드 적용 X).

#### Auth Guard 분기 (`OnboardingCompleteGuard`)

`JwtAuthGuard` 다음에 적용. 다음 라우트는 **온보딩 미완료여도 통과**:

- `POST /onboarding/complete`
- `GET /me`
- `POST /auth/*` (로그아웃 등)

그 외 도메인 라우트(`/missions`, `/chat`, `/reports`, …)는 `user.onboardedAt == null`이면 **403** + body:

```typescript
{
  statusCode: 403,
  code: 'ONBOARDING_REQUIRED',
  redirectTo: '/onboarding'
}
```

구현 옵션: 라우트 단위 `@SkipOnboardingCheck()` 데코레이터 + 글로벌 가드. 또는 화이트리스트 경로를 가드 내부에서 정적 매칭.

#### OpenAPI export

- `@nestjs/swagger`가 자동으로 DTO·Response 타입 export
- 빌드 산출물: `dist/openapi.json` 또는 런타임 `/openapi.json`
- 클라이언트 코드젠은 web/admin/mobile에서 별도로 (이 기획 범위 밖)

---

### 4.2 yougabell-web 상세 스펙

#### 라우트 구조

```
app/
└── onboarding/           # 일반 segment (route group 아님 — URL에 onboarding 포함)
    ├── layout.tsx        # 모바일 뷰 컨테이너 + safe-area
    ├── intro/page.tsx    # 디자인 확정 전 placeholder
    ├── parent/page.tsx
    ├── children/page.tsx
    ├── app-usage/page.tsx
    └── done/page.tsx     # 완료 후 홈으로 redirect
```

> 초안에서 `(onboarding)` route group으로 표기했으나 URL이 `/intro`로 잡혀 의도와 어긋남 — 일반 segment(`onboarding/`)로 변경하여 `/onboarding/*` 경로를 보장.

#### localStorage draft 스키마

키: `onboarding:draft:v2`

```typescript
type OnboardingDraft = {
  schemaVersion: 2;
  lastStep: "intro" | "parent" | "children" | "app-usage";
  parent?: {
    name?: string;
    birthDate?: string; // "YYYY-MM-DD"
    gender?: "female" | "male";
    workStatus?: "working" | "full_time_caregiver" | null;
  };
  children?: Array<{
    tempId: string; // 클라이언트 측 임시 ID
    name?: string;
    birthDate?: string;
    gender?: "female" | "male";
    notes?: string;
  }>;
  notification?: {
    // v3: 단건 (custom 선택 시 time 필수)
    slot: "morning" | "afternoon" | "evening" | "night" | "custom";
    time?: string; // "HH:MM"
  };
  updatedAt: string; // ISO 8601 (마지막 갱신 시각)
};
```

> v3에서 localStorage 키는 `onboarding:draft:v3`, `schemaVersion: 3`. v2 키(`:v2`)는 hook에서 폐기 처리.

#### `useOnboardingDraft()` 훅 인터페이스

```typescript
function useOnboardingDraft(): {
  draft: OnboardingDraft | null;
  setStep: <K extends keyof OnboardingDraft>(
    key: K,
    value: OnboardingDraft[K],
  ) => void;
  clear: () => void;
  isDirty: boolean; // draft가 존재하는가
};
```

- 내부적으로 `useSyncExternalStore` 또는 단순 `useState` + `useEffect` 패턴
- 단계별 `onChange` → debounce 200ms → localStorage 저장
- `clear()`는 완료 응답 200 직후 호출

#### web → API payload 매핑

`done` 페이지 마운트 시점에 draft를 검증·정규화 후 `POST /onboarding/complete` 호출.

```typescript
async function submitOnboarding(draft: OnboardingDraft) {
  const payload: CompleteOnboardingDto = {
    parent: {
      name: draft.parent!.name!,
      birthDate: draft.parent!.birthDate!,
      gender: draft.parent!.gender!,
      workStatus: draft.parent?.workStatus ?? null, // 미입력은 명시적으로 null
    },
    children: (draft.children ?? []).map(({ tempId, ...rest }) => rest),
    notification: draft.notification!, // 검증 단계에서 존재 보장 (custom이면 time 포함)
  };

  const res = await api.post("/onboarding/complete", payload);
  clearDraft();
  notifyMobile({ type: "ONBOARDING_COMPLETE" }); // mobile WebView 일 때
  return res;
}
```

#### Proxy (`proxy.ts`, Next.js 16)

Next.js 16에서 `middleware.ts` → `proxy.ts`로, 함수도 `proxy`로 변경됨.

```typescript
// proxy.ts
import { NextResponse } from "next/server";

export function proxy() {
  // 인증 체크 후 me.onboardedAt 분기 (placeholder — Supabase 세션 통합은 후속)
  // if (user && !me.onboardedAt && !pathname.startsWith("/onboarding")) → redirect "/onboarding/intro"
  // if (user && me.onboardedAt && pathname.startsWith("/onboarding"))   → redirect "/"
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next|favicon.ico|.*\\.).*)"],
};
```

- `me.onboardedAt`은 SSR 단계에서 캐시 (cookie 또는 짧은 TTL revalidate)
- 미인증 사용자는 `/login`으로 리디렉트 (기존 룰 유지)

#### 컴포넌트 인터페이스

```typescript
// IntroScreen — 디자인 확정 전 placeholder. 캐러셀 결정되면 IntroCarousel로 교체
type IntroScreenProps = { onNext: () => void; onSkip: () => void };

// DateTriple — 년/월/일 분리 입력
type DateTripleProps = {
  value?: string; // "YYYY-MM-DD"
  onChange: (iso: string) => void;
};

// SegmentedToggle — 직장 유무는 미선택 허용
type SegmentedToggleProps<T> = {
  options: { value: T; label: string }[];
  value: T | null;
  onChange: (v: T | null) => void;
  allowDeselect?: boolean; // 직장 유무에서 true
};

// ChildCardForm — 인라인 편집 모드 (저장 전)
type ChildCardFormProps = {
  index: number;
  child: ChildDraft;
  onChange: (next: ChildDraft) => void;
};

// ChildRow — 알약 행 (저장 후 표시 모드, 편집/삭제 아이콘 포함)
type ChildRowProps = {
  child: ChildDraft;
  onEdit: () => void;
  onDelete: () => void;
};

// NotificationSlotPicker — v3 (Figma 2146:4530). 단일 선택 + 시간 칩 + custom HH:MM
type NotificationSlotPickerProps = {
  value: NotificationPreference | null;
  onChange: (next: NotificationPreference) => void;
};
```

---

### 4.3 yougabell-mobile WebView 통합 상세

#### 역할 분담 (web vs mobile)

| 책임             | web                                              | mobile (Expo)                   |
| ---------------- | ------------------------------------------------ | ------------------------------- |
| 온보딩 UI        | 전부 담당                                        | —                               |
| 인증 (로그인)    | `@supabase/ssr` 쿠키 기반                        | —                               |
| 데이터 수집·저장 | 전부 담당                                        | —                               |
| 푸시 권한 요청   | 시각적 안내 가능, 실제 권한 호출은 mobile에 위임 | 안내 → OS 다이얼로그 표시       |
| WebView 호스팅   | —                                                | `react-native-webview` 컨테이너 |
| Deep link 진입   | 라우팅 로직 (web)                                | URL 파싱 후 WebView로 전달      |

→ **모바일에서 인증을 별도 처리하지 않음**. WebView 내부에서 web의 `@supabase/ssr`이 쿠키 세션 관리. Mobile은 단순 셸.

#### WebView 컨테이너 (`yougabell-mobile/app/(tabs)/index.tsx` 또는 `webview/container.tsx`)

```tsx
import { WebView } from "react-native-webview";
import { useRef } from "react";

const WEB_URL = process.env.EXPO_PUBLIC_WEB_URL!; // https://app.yougabell.kr 등

export default function MainWebView() {
  const ref = useRef<WebView>(null);

  return (
    <WebView
      ref={ref}
      source={{ uri: WEB_URL }}
      onMessage={(event) =>
        handleWebMessage(JSON.parse(event.nativeEvent.data))
      }
      sharedCookiesEnabled // iOS — Supabase 세션 쿠키 공유
      thirdPartyCookiesEnabled // Android
      javaScriptEnabled
      domStorageEnabled // localStorage 활성
      injectedJavaScriptBeforeContentLoaded={`window.__YOUGABELL_NATIVE__ = true;`}
    />
  );
}
```

- **localStorage 영속성**: iOS `WKWebView` / Android `WebView` 모두 앱 내부에 저장됨. **앱 삭제·OS 캐시 클리어 시 유실** (수용 가능)
- **쿠키 영속성**: `sharedCookiesEnabled` + `thirdPartyCookiesEnabled` 설정 시 Supabase 세션 쿠키 유지
- `window.__YOUGABELL_NATIVE__` — web이 자신의 호스트 환경을 감지해 native 전용 동작(예: postMessage) 활성

#### web → mobile 메시지 (`postMessage` 프로토콜)

| type                      | payload              | 발생 시점                                 | mobile 처리                        |
| ------------------------- | -------------------- | ----------------------------------------- | ---------------------------------- |
| `ONBOARDING_COMPLETE`     | `{ userId: string }` | `POST /onboarding/complete` 200 응답 직후 | 푸시 권한 요청 다이얼로그 표시     |
| `REQUEST_PUSH_PERMISSION` | —                    | (옵션) 푸시 안내 화면에서 명시 요청 시    | OS 권한 다이얼로그                 |
| `LOGOUT`                  | —                    | 로그아웃 시                               | SecureStore 토큰 정리, splash 진입 |

**web 측 호출 헬퍼**:

```typescript
function notifyMobile(msg: { type: string; payload?: unknown }) {
  if (typeof window === "undefined") return;
  if (
    (window as any).__YOUGABELL_NATIVE__ &&
    (window as any).ReactNativeWebView
  ) {
    (window as any).ReactNativeWebView.postMessage(JSON.stringify(msg));
  }
}
```

**mobile 측 수신 (`handleWebMessage`)**:

```typescript
async function handleWebMessage(msg: { type: string; payload?: unknown }) {
  switch (msg.type) {
    case "ONBOARDING_COMPLETE":
      await requestPushPermission();
      break;
    case "REQUEST_PUSH_PERMISSION":
      await requestPushPermission();
      break;
    case "LOGOUT":
      await SecureStore.deleteItemAsync("expo_push_token");
      break;
  }
}
```

#### 푸시 권한 요청 흐름

```
web /onboarding/done 도착
  → POST /onboarding/complete 200
  → notifyMobile({ type: 'ONBOARDING_COMPLETE' })
                    ↓
mobile handleWebMessage
  → expo-notifications: getPermissionsAsync()
    → status === 'undetermined' → requestPermissionsAsync()
    → granted: getExpoPushTokenAsync() → 서버에 등록 (별도 endpoint, 본 기획 범위 밖)
    → denied: 무시 (사용자 설정에서 변경 안내는 별도 화면)
  → web으로 redirect는 자동 (postMessage는 단방향, web은 자기 흐름대로 홈으로 이동)
```

#### Android 하드웨어 back 버튼

- 기본: WebView가 history pop. 인트로에서 더 뒤로 가면 앱 종료 → 일반 anti-pattern이지만 첫 진입이라 수용
- 단계 사이(parent → children) 뒤로 가기는 web의 router back으로 처리, mobile은 개입 X
- 구현: `BackHandler` listener + WebView `canGoBack()` 활용

---

### 4.4 엣지 케이스

| 상황                                                                  | 처리                                                                      |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `POST /onboarding/complete` 네트워크 실패                             | 토스트 + 재시도 버튼. draft는 유지(clear 안 함)                           |
| `POST /onboarding/complete` 409 (이미 완료)                           | draft clear + 홈으로 강제 리디렉트                                        |
| 사용자가 인트로에서 "건너뛰기" 후 자녀 정보까지 와서 다시 인트로 진입 | draft 존재하므로 "이어서 작성하기 / 처음부터" 다이얼로그                  |
| 다른 디바이스로 이어서 작성                                           | 미지원. 새 디바이스는 처음부터 (draft가 디바이스 로컬)                    |
| draft가 schemaVersion 1 (구버전)                                      | clear + 처음부터 (마이그레이션 X — 첫 1회 온보딩 데이터라 손실 영향 미미) |
| Mobile WebView에서 web 도메인 인증서 오류                             | WebView `onError`로 mobile splash에서 재시도 안내                         |
| 푸시 권한 거부 후 온보딩 종료                                         | 홈 진행. 푸시 안내 배너로 후속 권한 요청 가능                             |
| 자녀 0명으로 제출 시도                                                | API에서 400 `VALIDATION_ERROR`. web에서 사전 검증으로 차단                |

---

## 5. UI/디자인 참조

| 화면        | Figma 노드                | 상태                    | 비고                                                                                                                              |
| ----------- | ------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 인트로      | `2146:4252`               | v3 (Figma 와이어프레임) | 헤드라인 2줄 + 중앙 일러스트 자리 + 검정 "Apple로 계속하기" CTA. (Supabase Auth 미구현이라 현재 동작은 /parent 이동 placeholder.) |
| 본인 정보   | `2146:4265`               | v3                      | 이름·생년월일(chevron)·성별·직장 유무. 직장 유무는 **선택**(Figma `*`표시는 와이어프레임 상태, 기획상 선택).                      |
| 자녀 정보   | `2146:5015` / `2146:4912` | v3 (행+편집 2단)        | 알약 행(여아 김유스 1999.01.01 + 편집/삭제) ↔ 카드 폼(저장 모드) 토글. 삭제 시 모달 확인 (`2146:5045`).                           |
| 알림 시간대 | `2146:4530` / `2146:4703` | v3 (단일 선택)          | 5개 카드(오전/오후/저녁/밤/직접 입력). preset 선택 시 시간 칩 펼침. custom은 `<input type="time">`. v2 매트릭스 폐기.             |
| 로딩(완료)  | `2146:4771`               | v3                      | 2줄 카피 + 4도트 펄스 인디케이터. `POST /onboarding/complete` 진행 중·완료 화면 겸용.                                             |

> Figma 14개 화면 그룹: `2146:4251` (umbrella). 본 표는 기존 5개 라우트 매칭만 다룸. 신규 화면(관심 주제 `2146:4467`, 서비스 동의 `2146:4786`, 자녀정보-06 카드 폼 진입 분리)은 별도 PR로 분리.

> 사용자가 함께 보낸 8개 노드 중 4개(`2010:20609,20610,20611,20612`)는 Figma 캔버스의 **connector 선**(예: "선택 이후 '다음' 누르면")으로, 화면이 아닌 흐름 표시.

### 와이어프레임에서 가져올 것 / 무시할 것

| 가져올 것 (Spec)                                                       | 무시할 것 (Wireframe noise)                   |
| ---------------------------------------------------------------------- | --------------------------------------------- |
| 화면별 필수/선택 필드 구성                                             | 색상, 그라데이션, hex 값                      |
| 컴포넌트 종류 (Text Input / Date Picker / Segmented / Chip / Carousel) | 구체적 폰트(Inter), 폰트 크기, letter-spacing |
| 상대적 배치·계층 (헤더 → 본문 → 하단 액션)                             | 절대 좌표(`top: 131.99px` 등), 정확한 패딩    |
| 페이지네이션 패턴 (1/3 dots)                                           | 점·바의 정확한 사이즈                         |
| 액션 버튼 위치(하단 풀폭, 이전/다음 페어)                              | 버튼 색·그림자                                |
| 자녀 추가 점선 카드 패턴                                               | 점선 색·간격                                  |

> 시각 디자인은 별도 단계에서 `yougabell-web/DESIGN.md` 토큰을 적용해 확정. 본 기획서는 **무엇을 어디에 둘지**만 합의.

---

## 6. 비기능 요구

### 저장 전략 (확정 2026-05-08)

**디바이스 로컬 임시 저장 + 완료 시 서버 일괄 atomic POST.** 단계별 DB 저장 안 함.

```
[온보딩 단계]                            [디바이스]                       [서버]
인트로/본인/자녀/앱사용시간             localStorage                     —
   (각 화면 onChange)                    onboarding:draft:v2 갱신
                                              ↓
완료 버튼 클릭                         payload 생성                  POST /onboarding/complete
                                                                          ↓
                                                                     Prisma 트랜잭션
                                                                     - User.workStatus / notificationSlot / notificationTime / onboardedAt = now()
                                                                     - Child[] insert
                                                                          ↓ 200
완료 화면                              draft clear                       —
```

- **localStorage 키**: `onboarding:draft:v3` (v2 → v3 변경, 알림 시간대 모델 변경에 따라 schemaVersion bump), 값은 단계별 입력 객체(JSON)
- **TTL**: 사실상 무제한. 완료 시 명시적 clear
- **민감정보**: 비밀번호·토큰 같은 민감정보 없음 (이름·생년월일·자녀 정보는 서버 저장 직전까지만 존재)
- **재진입**: 인트로 진입 시 draft 존재하면 "이어서 작성하기" 옵션 제공
- **디바이스 전환 케이스**: 다른 디바이스에서는 처음부터 — 첫 1회 온보딩 특성상 수용 가능

### 그 외

- **성능**: 단계 전환은 클라이언트 라우팅으로 즉각. 네트워크 호출은 완료 시 1회.
- **보안**: 가입 직후 발급된 Supabase JWT만 허용. 미인증 접근 시 로그인으로 리디렉트
- **접근성**: 칩·세그먼트 토글에 `role`, 키보드 포커스 흐름, "건너뛰기"는 `aria-label`
- **분석 이벤트**:
  - `onboarding_intro_view` (page 1/2/3 별)
  - `onboarding_skip` (인트로 단계)
  - `onboarding_step_complete` (parent / children / app_usage)
  - `onboarding_work_status_filled` (선택 필드 응답률 추적)
  - `onboarding_finish` (전체 완료)

---

## 7. 리스크·미해결 질문

- [x] ~~**앱 사용 시간대 화면 — 디자인 재검토 중 (2026-05-08)**~~ → **v3 확정 (2026-05-12)**: 단일 시간대 선택(오전/오후/저녁/밤) + custom HH:MM. § 3 모델·§ 4 web 컴포넌트(`NotificationSlotPicker`) 재정의 완료.
- [ ] **직장 유무 — 필수 → 선택 전환 (2026-05-08)**. 결정 후속:
  - 디자인에서 라벨에 "(선택)" 추가 또는 별표(`*`) 제거
  - 미응답값(`null`) 처리: 콘텐츠 큐레이션에서 "워킹맘 분기"는 `working`인 경우에만 적용, `null`/`full_time_caregiver`는 일반 분기
  - 직장 유무를 묻지 않을 가능성도 검토(완전 제거) — 기획자 확인 필요
- [ ] **인트로 화면 구성 미정** — 1장인지 N장 캐러셀인지, 점 3개가 의미하는 것이 무엇인지 (캐러셀 / step indicator / placeholder) **디자인 확정본에서 확인**
- [x] ~~특이사항 — 자유 텍스트 vs 카테고리+텍스트~~ → **자유 텍스트로 확정** (2026-05-08). AI 챗봇이 컨텍스트로 소비하므로 카테고리 강제 분류는 정보 손실·입력 마찰만 유발. 사후 분석 필요 시 LLM 추출.
- [x] ~~온보딩 단계별 즉시 저장 vs 일괄 저장~~ → **localStorage draft + 완료 시 서버 일괄 POST**로 확정 (2026-05-08)
- [ ] **이전 디자인(`851:*`)과의 호환** — 기존 명세 폐기 후 본 v2가 진실. `01-user.md` 흐름 다이어그램 갱신 필요

---

## 8. Phase별 작업 todo

> 진행 시 `- [ ]` → `- [x]`로 갱신. PR 머지 시 본 섹션을 진행 추적의 단일 소스로.

### Phase 0 — 기획 확정 (선행)

- [x] ~~인트로 화면 디자인 확정~~ → Figma `2146:4252` 단일 화면 + Apple 로그인 CTA (2026-05-12)
- [x] ~~앱 사용 시간대 화면 새 디자인 수령~~ → Figma `2146:4530` 단일 선택 + custom 입력 (2026-05-12)
- [ ] 직장 유무 라벨에 "(선택)" 표기 적용 또는 별표 제거 (디자이너 작업) — Figma는 여전히 `*` 표시 중
- [ ] 직장 유무 완전 제거 가능성 검토 (기획 결정)

### Phase 1 — `yougabell-api` (선행, 다른 레포 시작 차단)

- [x] Prisma schema 갱신 (v2): `User.workStatus`/`onboardedAt`, `UserAppUsageSlot`, `WorkStatus`/`TimeSlot` enum. 두 Float 필드 제거
- [x] **Prisma schema 갱신 (v3, 2026-05-12)**: `User.notificationSlot`/`notificationTime` 추가, `UserAppUsageSlot`·`TimeSlot` enum 제거, `NotificationSlot` enum 신규
- [ ] 마이그레이션 실행 (`pnpm prisma:migrate:dev --name onboarding_v3_notification`) — `.env` 셋업 후
- [x] `OnboardingModule` + `OnboardingController` (`POST /onboarding/complete`)
- [x] `CompleteOnboardingDto` + `class-validator` 룰 적용 (+ `@nestjs/swagger` 데코레이터) — v3에서 `notification` 단건으로 변경
- [x] 트랜잭션 처리 (`prisma.$transaction` + 멱등성 `409` 응답)
- [x] `GET /me` 응답에 `onboardedAt`/`workStatus`/`children`/`notificationSlot`/`notificationTime` 포함 (`UsersController`)
- [x] `OnboardingCompleteGuard` (글로벌 `APP_GUARD` + `@SkipOnboardingCheck()` 데코레이터 + `403 ONBOARDING_REQUIRED`)
- [△] OpenAPI 스펙 export — 코드 작성됨 (`main.ts`에 `SwaggerModule` + `OPENAPI_EXPORT_PATH`). 부팅 검증은 `.env` 셋업 후
- [ ] **별도 task**: `JwtAuthGuard`가 현재 placeholder(`x-user-id` 헤더). Supabase JWT 검증으로 교체 필요

### Phase 2 — `yougabell-web` (api 완료 후)

- [x] `app/onboarding/` route + layout (route group이 아닌 일반 segment — URL이 `/onboarding/*`)
- [x] 5개 페이지: `intro`, `parent`, `children`, `app-usage`, `done`
- [x] `OnboardingDraft` 타입 + `useOnboardingDraft()` 훅 (useSyncExternalStore + localStorage 구독)
- [x] 컴포넌트 (v3, 2026-05-12 Figma 매칭): `DateInput`(단일 입력 + chevron + 네이티브 피커), `SegmentedToggle`(allowDeselect), `ChildCardForm` + `ChildRow`(편집/알약 토글), `NotificationSlotPicker`(5카드 + 시간 칩 + custom). 공용 `Button`/`Input`/`IconButton` + DESIGN.md 토큰 + Pretendard. v2 `DateTriple`/`AppUsageMatrix`는 폐기.
- [x] `buildPayload()` 헬퍼 (done 페이지에서 useMemo로 검증)
- [x] `notifyMobile()` 헬퍼 + `isNativeWebView()` 감지
- [△] `proxy.ts` — Next.js 16에서 `middleware.ts` → `proxy.ts` (`export function proxy()`). 게이트 분기는 placeholder, Supabase 세션 통합은 후속
- [x] 재개 다이얼로그 ("이어서 작성하기 / 처음부터") — derived state 패턴
- [x] 분석 이벤트 5종 발사 (console.info placeholder, TODO 실제 트래커)

### Phase 3 — `yougabell-mobile` (web 후속, 또는 web와 병행)

- [x] `react-native-webview` 컨테이너 (`sharedCookiesEnabled`, `thirdPartyCookiesEnabled`, `domStorageEnabled`, `allowsBackForwardNavigationGestures`)
- [x] `injectedJavaScriptBeforeContentLoaded`로 `__YOUGABELL_NATIVE__` 플래그 주입
- [x] `handleWebMessage` (3종 type 처리: `ONBOARDING_COMPLETE` / `REQUEST_PUSH_PERMISSION` / `LOGOUT`)
- [x] `requestPushPermission` (expo-notifications)
- [ ] `expo_push_token` 서버 등록 (별도 endpoint — 본 기획 외, TODO 주석으로 표시)
- [x] Android `BackHandler` + WebView `goBack()` 처리 (iOS는 swipe gesture)

### Phase 4 — `yougabell-admin` (선택, 추후)

- [ ] 사용자 상세 화면에 `workStatus`(nullable) / `notificationSlot`·`notificationTime` 표시
- [ ] 개인정보 마스킹 룰 적용
- [ ] (선택) 검색 필터에 `workStatus`/`onboardedAt` 추가

### Phase 5 — 통합 검증

- [ ] 골든 패스: 가입 → 온보딩 4단계 → 홈
- [ ] 중도 이탈 → 같은 디바이스 재진입 시 draft 복원
- [ ] 다른 디바이스에서 진입 시 처음부터 시작
- [ ] `409` 멱등 처리: 이미 완료자 재호출 시 홈으로 강제
- [ ] 네트워크 실패 시 draft 유지 + 재시도
- [ ] 푸시 권한 거부 케이스 (홈 진행, 후속 배너로 재요청)
- [ ] 자녀 0명 제출 시 400 차단 (web 사전 + api 사후)
- [ ] mobile WebView에서 web `__YOUGABELL_NATIVE__` 플래그 인식 확인

---

## 9. 구현 결과 (구현 완료 후 채움)

- 관련 PR: [`api#…`], [`web#…`], [`admin#…`], [`mobile#…`]
- 마이그레이션 이름: `onboarding_v2`
- 스펙 변경점: …
- 후속 과제: —
