# 어드민 — 온보딩 완료 사용자 관리

> 작성일: 2026-05-12 · 상태: `draft`
> 영향 레포: `yougabell-api`, `yougabell-admin`

---

## 1. 배경 (Why)

운영자가 가입·온보딩 완료 사용자를 일별로 확인하고, 검수·CS 대응 시점을 찾기 위한 기본 화면. 1단계는 **목록 + 검색 + 페이지네이션**까지. 상세·편집은 후속.

## 2. 사용자 시나리오

- **누가**: 운영자
- **흐름**:
  1. `/users` 접근
  2. 기본 필터 = "온보딩 완료자만"
  3. 검색(이름)으로 좁히기, 페이지네이션
  4. (후속) 행 클릭 → 상세 (본 기획 외)
- **수용 기준**:
  - 온보딩 미완료자(`onboardedAt == null`)는 기본 노출 X
  - 개인정보는 모두 **마스킹** 표시
  - 페이지네이션·검색·정렬 동작

## 3. 도메인 영향

- **스키마 변경 없음** — 기존 `User.onboardedAt`/`workStatus`/`children` 사용
- 어드민 role 확인은 **본 기획 외** (placeholder Guard로 별도 task)

## 4. 레포별 작업 분해

| 레포              | 작업                                                                         | 의존성      |
| ----------------- | ---------------------------------------------------------------------------- | ----------- |
| `yougabell-api`   | `GET /admin/users` 엔드포인트 + DTO + 마스킹은 클라이언트 책임 (서버는 원본) | 선행        |
| `yougabell-admin` | `/users` 페이지를 실 데이터로 교체, shadcn Table + 검색 + 페이지네이션       | api 완료 후 |

### 4.1 yougabell-api

**Endpoint**: `GET /admin/users`

**Query**:

```typescript
{
  onboarded?: 'true' | 'false' | 'all';  // default: 'true'
  q?: string;                             // 이름 검색 (LIKE %q%)
  page?: number;                          // 1-based, default 1
  limit?: number;                         // default 20, max 100
}
```

**Response 200**:

```typescript
{
  items: Array<{
    id: string;
    name: string;
    birthDate: string; // ISO
    gender: "female" | "male";
    workStatus: "working" | "full_time_caregiver" | null;
    onboardedAt: string | null;
    childrenCount: number;
    createdAt: string;
  }>;
  total: number;
  page: number;
  limit: number;
}
```

- 응답에 `email`은 포함 안 함 (Supabase `auth.users`에 있음 — Prisma 도메인엔 없음). 후속 task에서 admin API가 Supabase admin client로 별도 조회
- **마스킹은 admin 클라이언트가 표시 단계에서 처리** — 서버는 원본 반환(운영자 권한 검증된 라우트라 가정)
- Auth: `@SkipOnboardingCheck()` (운영자는 본인 온보딩과 무관) + 향후 **`AdminRoleGuard`** (별도 task)

### 4.2 yougabell-admin

- `app/(dashboard)/users/page.tsx`를 server component로 — `fetch(API_BASE_URL + /admin/users?...)` 직접 호출
- `searchParams`로 query 받기 (`?q=...&page=2`)
- shadcn `Table` + 필터 form (검색 input) + 페이지네이션
- 마스킹 유틸: `name 홍길동 → 홍**`, 향후 추가될 email은 `hong***@*.com`
- 정렬은 1단계에서 `onboardedAt desc` 고정 (UI 정렬 토글은 후속)

## 5. UI/디자인 참조

디자인 없음. shadcn `Table` 표준 + 어드민 일반 패턴:

- 상단 필터 바 (검색 input + 토글)
- 테이블 (id 마스킹/이름/성별/직장 유무/자녀 수/온보딩 완료일)
- 하단 페이지네이션 (이전/다음 + N of M)

## 6. 비기능 요구

- **개인정보 마스킹** (admin AGENTS.md 룰)
- 검색은 단순 LIKE — 인덱스 필요 없을 정도. 운영 규모 커지면 fulltext 검토
- 페이지네이션 최대 100건/페이지

## 7. 리스크·미해결

- [ ] **운영자 role 검증** — `AdminRoleGuard` 미구현. 현재 누구나 접근 가능 (placeholder). 별도 task
- [ ] **email 노출** — Supabase auth.users 조회 path 결정 필요 (별도 task)
- [ ] 상세 페이지 / 편집 / 자녀 정보 인라인 — 본 기획 외

## 8. Phase별 todo

### Phase 1 — api

- [x] `AdminModule` + `AdminController` — `GET /admin/users`
- [x] `ListUsersDto` (쿼리 검증, class-validator + Swagger)
- [x] Service — `prisma.$transaction`으로 `findMany` + `count`, `childrenCount`는 `_count.children`

### Phase 2 — admin

- [x] `/users` 페이지를 server component로 변환 (Promise<SearchParams>, cache: no-store)
- [x] 마스킹 유틸 (`lib/mask.ts`: `maskName`/`maskId`/`maskEmail`)
- [x] `UsersFilters` 클라이언트 컴포넌트 (검색 + useTransition + URL replace)
- [x] `UsersPagination` 컴포넌트 (URL 쿼리 기반, 이전/다음 + N of M)
- [x] API 호출 실패 시 인라인 에러 박스 (api 서버 안 떠있을 때 대비)

### Phase 3 — 검증

- [x] 빌드/lint 통과 (api: nest build · admin: next build, `/users`가 Dynamic ƒ로 잡힘)
- [ ] 실데이터 UI 확인 — api 부팅 + DB 데이터 필요
