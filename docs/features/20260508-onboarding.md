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
  4. **앱 사용 시간대** — (디자인 재검토 중, 2026-05-08) 요일별 × 시간대 입력. 직장 유무와 무관하게 **모든 사용자**가 입력. 현 v1은 7×5 칩 매트릭스이나 UX 과밀로 기획자에게 개선 요청. 새 안 수령 후 본 섹션 갱신.
  5. 완료 → 홈
- **수용 기준**:
  - 필수(`*`) 필드: 본인 이름·생년월일·성별, 자녀 1명 이상의 이름·생년월일·성별. 직장 유무는 **선택**
  - 인트로 "건너뛰기"는 본인 정보까지만 스킵, 자녀 정보·앱 사용 시간대는 필수
  - 다자녀 N명 등록 가능 (최소 1명)
  - 앱 사용 시간대 검증 룰은 새 디자인 수령 후 확정

---

## 3. 도메인 영향

새 화면이 요구하는 모델 변경.

| 엔티티                   | 변경 종류                                                                                    | 비고                                                                                               |
| ------------------------ | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `User`                   | 필드 추가 — `workStatus: enum('working','full_time_caregiver') NULLABLE` (**선택**)          | 새 화면 `2010:20364` "직장 유무". 2026-05-08 기획 변경으로 nullable 확정. 미응답 시 콘텐츠 분기 X. |
| `User.appUsageSlots`     | **신규 1:N** — 요일×시간대 매트릭스. 직장 유무와 독립적으로 전 사용자 수집                   | 새 화면 `2010:20415`. 정규화 테이블 권장 (`UserAppUsageSlot`). 의미: "앱 사용 시간대"              |
| `User.onboardedAt`       | 필드 추가 — `DateTime?`. 온보딩 완료 시각 1회 기록                                           | 강제 리디렉션 판단(서버 측 단일 boolean 역할). 단계 진척은 클라이언트가 추적                       |
| `Child`                  | 변경 없음 (기존 `01-user.md`/`02-child.md` 명세와 일치)                                      | name / birthDate / gender / **notes (자유 텍스트, AI 챗봇 컨텍스트 입력)**                         |
| ~~`OnboardingProgress`~~ | **불필요** — 단계 진척은 디바이스 로컬에서만 추적. DB는 완료 여부(`User.onboardedAt`)만 보유 | 부분 데이터로 DB 점유하지 않음                                                                     |

> 도메인 변경이 확정되면 [`../schema/01-user.md`](../schema/01-user.md) 갱신 + 신규 `UserAppUsageSlot` 섹션 추가.

### 신규 테이블 후보 — `UserAppUsageSlot`

> 이름은 "앱 사용 시간대"로 명시. 의미가 "아이와 함께 있는 시간"이 아니라 **사용자가 앱을 사용할(=알림을 받을) 시간대**임에 유의.

| 필드        | 타입                                                      | 비고                                      |
| ----------- | --------------------------------------------------------- | ----------------------------------------- |
| `id`        | UUID                                                      | PK                                        |
| `userId`    | FK → User                                                 |                                           |
| `dayOfWeek` | `enum('MON',…,'SUN')`                                     |                                           |
| `slot`      | `enum('MORNING','AFTERNOON','EVENING','NIGHT','ALL_DAY')` | 06–12 / 12–18 / 18–24 / 00–06 / 하루 종일 |

`(userId, dayOfWeek, slot)` UNIQUE.

---

## 4. 레포별 작업 분해

| 레포               | 작업                                                                                                                                                                       | 의존성       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ |
| `yougabell-api`    | Prisma — `User.workStatus` (nullable), `User.onboardedAt: DateTime?`, `UserAppUsageSlot` 테이블 신규, 마이그레이션                                                         | 선행 (1순위) |
|                    | Onboarding 컨트롤러 — **`POST /onboarding/complete`** (Parent + Child[] + AppUsageSlot[] 일괄 atomic) + `GET /me`(onboardedAt 포함)                                        | 1순위        |
|                    | Auth Guard — `User.onboardedAt == null` 사용자 식별 (보호 라우트에서 401/403 또는 redirect 힌트 응답)                                                                      | 1순위        |
|                    | OpenAPI export 갱신                                                                                                                                                        | 1순위 후속   |
| `yougabell-web`    | 라우트 — `app/(onboarding)/intro/`, `parent/`, `children/`, `app-usage/`, `done/` (인트로 하위 구조는 디자인 확정 후 결정)                                                 | api 완료 후  |
|                    | 컴포넌트 — `IntroScreen`(또는 캐러셀, 디자인 확정 후), `DateTriple`(년/월/일 분리 입력), `SegmentedToggle`(직장 유무는 미선택 허용), `ChildCard`(다자녀), `AppUsageMatrix` | api 후속     |
|                    | **로컬 저장소 훅** — `useOnboardingDraft()`: localStorage `onboarding:draft:v2` read/write/clear. 단계 이동 시 자동 저장, 완료 응답 200 후 clear                           | api와 병행   |
|                    | **재개 UX** — `/(onboarding)/intro` 진입 시 draft 존재하면 "이어서 작성하기 / 처음부터" 다이얼로그                                                                         | api 후속     |
|                    | 미들웨어 — 인증된 사용자 중 `me.onboardedAt == null`이면 `/(onboarding)/...` 외 차단                                                                                       | api 후속     |
| `yougabell-admin`  | 운영자 화면에서 `workStatus`(nullable), `appUsageSlots` 표시(읽기 전용, 마스킹 룰 따름)                                                                                    | api 후속     |
| `yougabell-mobile` | WebView 컨테이너 + 인증 토큰 브릿지 + `ONBOARDING_COMPLETE` postMessage 수신 후 푸시 권한 요청                                                                             | api/web 병행 |

---

### 4.1 yougabell-api 상세 스펙

#### Prisma schema diff (`yougabell-api/prisma/schema.prisma`)

```prisma
// User에 필드 추가
model User {
  // ... 기존 필드 유지
  workStatus    WorkStatus?            // nullable (선택 입력)
  onboardedAt   DateTime?              // nullable. 온보딩 완료 시각 1회 기록
  appUsageSlots UserAppUsageSlot[]
}

// 신규 enum
enum WorkStatus {
  WORKING               // "일을 하고 있어요"
  FULL_TIME_CAREGIVER   // "전업 가정인이에요"
}

// 신규 테이블
model UserAppUsageSlot {
  id        String    @id @default(uuid())
  userId   String
  user      User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  dayOfWeek DayOfWeek
  slot      TimeSlot
  createdAt DateTime  @default(now())

  @@unique([userId, dayOfWeek, slot])
  @@index([userId])
}

enum DayOfWeek {
  MON
  TUE
  WED
  THU
  FRI
  SAT
  SUN
}

enum TimeSlot {
  MORNING    // 06:00–12:00
  AFTERNOON  // 12:00–18:00
  EVENING    // 18:00–24:00
  NIGHT      // 00:00–06:00
  ALL_DAY
}
```

- 마이그레이션: `pnpm prisma:migrate:dev --name onboarding_v2`
- `Child` 모델은 변경 없음 (이미 `notes` 자유 텍스트 필드 보유)

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
  children: Array<{          // required, 최소 1개
    name: string;            // required, 1~30자
    birthDate: string;       // required, "YYYY-MM-DD"
    gender: 'female' | 'male'; // required
    notes?: string;          // optional, 자유 텍스트, 최대 1000자
  }>;
  appUsage: Array<{          // required (빈 배열 허용 여부는 디자인 확정 후)
    dayOfWeek: 'MON'|'TUE'|'WED'|'THU'|'FRI'|'SAT'|'SUN';
    slot: 'MORNING'|'AFTERNOON'|'EVENING'|'NIGHT'|'ALL_DAY';
  }>;
}
```

**검증 룰** (`class-validator` 사용):

- `parent.name`: `@IsString() @Length(1,30)`
- `parent.birthDate`: `@IsDateString()`. 미래 날짜 거부, 1900-01-01 이후
- `parent.gender`: `@IsIn(['female','male'])`
- `parent.workStatus`: `@IsOptional() @IsIn([...])`
- `children`: `@IsArray() @ArrayMinSize(1) @ValidateNested({ each: true })`
- `children[].notes`: `@IsOptional() @IsString() @MaxLength(1000)`
- `appUsage`: `@IsArray() @ValidateNested({ each: true })`
- `appUsage[]` 중복 (`dayOfWeek + slot` 조합): API에서 dedupe 후 insert (UNIQUE 제약 의존하지 않음)

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

  // 4. UserAppUsageSlot[] insert (dedupe 후)
  const slots = dedupe(dto.appUsage);
  await tx.userAppUsageSlot.createMany({
    data: slots.map((s) => ({ userId, dayOfWeek: s.dayOfWeek, slot: s.slot })),
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
  appUsageSlots: UserAppUsageSlot[];
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

기존 응답에 `onboardedAt`, `workStatus`, `appUsageSlots` 추가. 미완료 사용자는 `onboardedAt: null`로 응답 (라우트 자체는 `JwtAuthGuard`만, 온보딩 가드 적용 X).

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
└── (onboarding)/
    ├── layout.tsx        # 공통 컨테이너, 진행 상태 표시
    ├── intro/
    │   └── page.tsx      # 디자인 확정 후 캐러셀/단일 결정
    ├── parent/page.tsx
    ├── children/page.tsx
    ├── app-usage/page.tsx
    └── done/page.tsx     # 완료 후 홈으로 redirect
```

> `(onboarding)` route group으로 일반 레이아웃과 분리. layout.tsx는 인증 체크 + 단계 진행도 표시.

#### localStorage draft 스키마

키: `onboarding:draft:v2`

```typescript
type OnboardingDraft = {
  schemaVersion: 2;
  lastStep: 'intro' | 'parent' | 'children' | 'app-usage';
  parent?: {
    name?: string;
    birthDate?: string;       // "YYYY-MM-DD"
    gender?: 'female' | 'male';
    workStatus?: 'working' | 'full_time_caregiver' | null;
  };
  children?: Array<{
    tempId: string;           // 클라이언트 측 임시 ID
    name?: string;
    birthDate?: string;
    gender?: 'female' | 'male';
    notes?: string;
  }>;
  appUsage?: Array<{
    dayOfWeek: 'MON' | ... | 'SUN';
    slot: 'MORNING' | ... | 'ALL_DAY';
  }>;
  updatedAt: string;          // ISO 8601 (마지막 갱신 시각)
};
```

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
    appUsage: draft.appUsage ?? [],
  };

  const res = await api.post("/onboarding/complete", payload);
  clearDraft();
  notifyMobile({ type: "ONBOARDING_COMPLETE" }); // mobile WebView 일 때
  return res;
}
```

#### 미들웨어 (`middleware.ts`)

```typescript
// 인증 체크 후 me.onboardedAt 분기
if (user && !me.onboardedAt && !pathname.startsWith("/onboarding")) {
  return NextResponse.redirect(new URL("/onboarding", request.url));
}
if (user && me.onboardedAt && pathname.startsWith("/onboarding")) {
  return NextResponse.redirect(new URL("/", request.url));
}
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

// ChildCard — 다자녀 입력
type ChildCardProps = {
  child: Partial<ChildDraft>;
  onChange: (next: Partial<ChildDraft>) => void;
  onRemove?: () => void;
};

// AppUsageMatrix — 디자인 재검토 중. 임시 인터페이스
type AppUsageMatrixProps = {
  value: Array<{ dayOfWeek: DayOfWeek; slot: TimeSlot }>;
  onChange: (next: AppUsageMatrixProps["value"]) => void;
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

| 화면           | Figma 노드      | 상태                   | 비고                                                                                                                                              |
| -------------- | --------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| 인트로         | `2010:20343` 외 | **내용·구성 미정**     | 노드 1개만 확보(💝 + "워킹맘의 하루를 더 의미있게"). 페이지네이션 점 3개가 캐러셀인지 step indicator인지 미확정. **디자인 확정본에서 확인 예정.** |
| 본인 정보      | `2010:20364`    | OK (필드 변경 요청 중) | 이름·생년월일·성별·직장 유무. 직장 유무는 **선택**으로 전환 (2026-05-08 기획 변경). 디자인 라벨에 "(선택)" 추가 필요.                             |
| 자녀 정보      | `2010:20549`    | OK                     | 이름·생년월일·성별·특이사항, **자녀 추가** 점선 버튼                                                                                              |
| 앱 사용 시간대 | `2010:20415`    | **디자인 재검토 중**   | 직장 유무와 무관하게 전 사용자 수집. 요일 7행 × 시간대 5칩 매트릭스가 과밀 — UX 개선 요청 (2026-05-08).                                           |

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
                                                                     - User.workStatus / onboardedAt = now()
                                                                     - Child[] insert
                                                                     - UserAppUsageSlot[] insert
                                                                          ↓ 200
완료 화면                              draft clear                       —
```

- **localStorage 키**: `onboarding:draft:v2`, 값은 단계별 입력 객체(JSON)
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

- [ ] **앱 사용 시간대 화면 — 디자인 재검토 중 (2026-05-08)**. 현 매트릭스 UX 과밀. 새 안 수령 시:
  - 입력 모델이 여전히 `요일 × 시간대`인지, 아니면 다른 구조(예: 평일/주말 묶음, 단일 시간대 선택, 자유 입력)로 바뀌는지 확인
  - 본 기획서의 § 3 (`UserAppUsageSlot` 스키마)와 § 4 web 컴포넌트(`AppUsageMatrix`) 재정의 필요
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

- [ ] 인트로 화면 디자인 확정 (캐러셀 vs 단일, 점 의미)
- [ ] 앱 사용 시간대 화면 새 디자인 수령 — UX 매트릭스 대안
- [ ] 직장 유무 라벨에 "(선택)" 표기 적용 또는 별표 제거 (디자이너 작업)
- [ ] 직장 유무 완전 제거 가능성 검토 (기획 결정)

### Phase 1 — `yougabell-api` (선행, 다른 레포 시작 차단)

- [ ] Prisma schema 갱신: `User.workStatus`, `User.onboardedAt`, `UserAppUsageSlot`, enum 3종
- [ ] 마이그레이션 실행 (`pnpm prisma:migrate:dev --name onboarding_v2`)
- [ ] `OnboardingModule` + `OnboardingController` (`POST /onboarding/complete`)
- [ ] `CompleteOnboardingDto` + `class-validator` 룰 적용
- [ ] 트랜잭션 처리 (`prisma.$transaction` + 멱등성 `409` 응답)
- [ ] `GET /me` 응답에 `onboardedAt`/`workStatus`/`children`/`appUsageSlots` 포함
- [ ] `OnboardingCompleteGuard` (화이트리스트 + `403 ONBOARDING_REQUIRED`)
- [ ] OpenAPI 스펙 export 갱신

### Phase 2 — `yougabell-web` (api 완료 후)

- [ ] `app/(onboarding)/` route group + layout
- [ ] 5개 페이지: `intro`, `parent`, `children`, `app-usage`, `done`
- [ ] `OnboardingDraft` 타입 + `useOnboardingDraft()` 훅
- [ ] 컴포넌트 5종: `IntroScreen`, `DateTriple`, `SegmentedToggle`, `ChildCard`, `AppUsageMatrix`
- [ ] `submitOnboarding()` 헬퍼 (draft → API payload 변환)
- [ ] `notifyMobile()` 헬퍼 (`window.ReactNativeWebView.postMessage`)
- [ ] `middleware.ts` — `me.onboardedAt` 분기 (미완료 → /onboarding, 완료자 → /)
- [ ] 재개 다이얼로그 ("이어서 작성하기 / 처음부터")
- [ ] 분석 이벤트 5종 발사

### Phase 3 — `yougabell-mobile` (web 후속, 또는 web와 병행)

- [ ] `react-native-webview` 컨테이너 (`sharedCookiesEnabled`, `domStorageEnabled`)
- [ ] `injectedJavaScriptBeforeContentLoaded`로 `__YOUGABELL_NATIVE__` 플래그 주입
- [ ] `handleWebMessage` (3종 type 처리: `ONBOARDING_COMPLETE` / `REQUEST_PUSH_PERMISSION` / `LOGOUT`)
- [ ] `requestPushPermission` (expo-notifications)
- [ ] `expo_push_token` 서버 등록 (별도 endpoint — 본 기획 외)
- [ ] Android `BackHandler` + WebView `canGoBack()` 처리

### Phase 4 — `yougabell-admin` (선택, 추후)

- [ ] 사용자 상세 화면에 `workStatus`(nullable) / `appUsageSlots` 표시
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
