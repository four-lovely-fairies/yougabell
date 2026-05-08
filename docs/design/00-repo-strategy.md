# Repo Strategy — Youth (yougabell)

> 4개 레포 분리 구조. 각 레포 독립 배포 + Prisma/타입은 코드젠 또는 패키지로 공유.
> 작성일: 2026-05-03

---

## 0. 결정 요약

| 항목 | 결정 | 비고 |
|---|---|---|
| 레포 구조 | **완전 분리 (4 레포)** | 모노레포 X. `four-lovely-fairies` org 산하 |
| DB | **Supabase Postgres** | Prisma로 컨트롤 |
| ORM | **Prisma** | API에 마스터, 다른 곳은 클라이언트/타입만 |
| 배포 (web/admin) | Vercel | Next.js 16 |
| 배포 (api) | TBD | Fly.io / Railway / Render 후보 |
| 배포 (app) | EAS Build | Expo |
| 인증 | **Supabase Auth** | DB와 같은 벤더로 통일. NestJS가 JWT 검증 |

---

## 1. 레포 구성

| GitHub 레포 | 역할 | 스택 | 호스팅 |
|---|---|---|---|
| [`four-lovely-fairies/yougabell-api`](https://github.com/four-lovely-fairies/yougabell-api) | 도메인 API · 챗봇 · LLM 게이트웨이 | NestJS, Prisma, TS | TBD |
| [`four-lovely-fairies/yougabell-web`](https://github.com/four-lovely-fairies/yougabell-web) | 사용자용 웹 (Expo WebView 타깃) | Next.js 16, Tailwind, TS | Vercel |
| [`four-lovely-fairies/yougabell-admin`](https://github.com/four-lovely-fairies/yougabell-admin) | 운영자 CMS (콘텐츠/미션/리포트) | Next.js 16, Tailwind, TS | Vercel |
| [`four-lovely-fairies/yougabell-mobile`](https://github.com/four-lovely-fairies/yougabell-mobile) | RN 셸 (푸시·인증·WebView 컨테이너) | Expo, TS | EAS |

### 의존 그래프

```mermaid
flowchart TB
    DB[(Supabase Postgres)]
    API[yougabell-api<br/>NestJS + Prisma]
    WEB[yougabell-web<br/>Next.js]
    ADMIN[yougabell-admin<br/>Next.js]
    APP[yougabell-mobile<br/>Expo RN]
    LLM[LLM Provider<br/>via AI Gateway]

    API -- Prisma --> DB
    WEB -- HTTPS / OpenAPI client --> API
    ADMIN -- HTTPS / OpenAPI client --> API
    APP -- WebView --> WEB
    APP -- Native API direct --> API
    API --> LLM
```

---

## 2. DB 전략 — Supabase + Prisma

### 연결 설정 (모든 환경 공통)

```env
# .env (NestJS)
# Pooled connection — 런타임 쿼리
DATABASE_URL="postgresql://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1"

# Direct connection — prisma migrate 전용
DIRECT_URL="postgresql://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:5432/postgres"
```

```prisma
// schema.prisma
datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}
```

### 운영 원칙

1. **Prisma가 스키마 마스터** — Supabase 대시보드에서 DDL 직접 실행 금지
2. **마이그레이션 흐름**
   - 로컬: `prisma migrate dev` → 검증 후 commit
   - 배포: CI에서 `prisma migrate deploy`
3. **RLS 정책** — 1차에는 끄고 NestJS의 권한 로직에 의존. RLS는 보조 안전망으로 추후 도입 검토.
4. **백업** — Supabase 자동 백업 + 주요 마이그레이션 전 수동 스냅샷

### Prisma 클라이언트 공유 전략

> `youth-shared` 같은 별도 패키지는 만들지 **않는다** (org이 분리 레포 정책). 대신 ↓

| 소비처 | 받아오는 방식 |
|---|---|
| `yougabell-api` | Prisma 본가. `schema.prisma` + `prisma generate` |
| `yougabell-web` | API에서 OpenAPI 스펙 자동 export → 클라이언트에서 codegen (`openapi-typescript` 또는 `orval`). **Prisma 직접 import 안 함.** |
| `yougabell-admin` | 동일. OpenAPI 코드젠. (단, admin은 추후 Prisma direct 검토 가능 — DB에 직접 붙는 운영 화면이 필요하면) |
| `yougabell-mobile` | OpenAPI 코드젠. Prisma는 RN 런타임 미지원이므로 **DB 직접 접근 X**. |

> 이전 사용자 요청에 web/app/admin에 Prisma를 두는 안이 있었으나, 실제 의도는 **타입 공유**로 해석되어 OpenAPI 코드젠으로 대체. Prisma 자체는 API에만 둠.

### 환경별 Supabase 프로젝트 분리

| 환경 | Supabase 프로젝트 | 용도 |
|---|---|---|
| local | (선택) Supabase CLI 로컬 / Docker | 개발자 머신 |
| dev | `youth-dev` | PR 프리뷰 |
| staging | `youth-staging` | 스테이지 검증 |
| prod | `youth-prod` | 운영 |

---

## 3. 인증 결정 — **Supabase Auth 확정** (2026-05-03)

DB와 같은 벤더로 통일. 추후 정책 복잡해지면 Clerk 이전 옵션 열어둠.

### 책임 분리

| 영역 | 담당 |
|---|---|
| 회원가입·로그인·비밀번호 재설정·소셜 로그인 | Supabase Auth (web/mobile에서 SDK로 호출) |
| JWT 발급·갱신 | Supabase |
| **JWT 검증·권한 체크** | **NestJS** (Guard에서 Supabase JWT 검증) |
| `User` 도메인 행 생성 | NestJS (Supabase Auth `auth.users.id`를 `User.id`로 매핑) |
| 푸시 토큰 보관 | NestJS `User` 테이블 (`pushToken` 컬럼 추가 예정) |

### Supabase Auth → 도메인 User 매핑

```mermaid
flowchart LR
    Signup[회원가입] --> SBA[(Supabase auth.users)]
    SBA -- trigger or webhook --> APIcreate[NestJS: User row 생성]
    APIcreate --> DOMAIN[(public.User)]
    Login[로그인] --> SBA
    SBA -- JWT --> Client[Web/Mobile]
    Client -- Bearer token --> APIcall[NestJS API]
    APIcall -- verify JWT --> APIverify[NestJS Guard]
```

> 신규 가입 시 `auth.users` → `public.User` 동기화는 (a) Supabase DB trigger 또는 (b) 첫 API 호출 시 NestJS가 lazy-create. 1차는 (b) lazy-create 채택 (관리 단순).

---

## 4. 호스팅 결정 (NestJS)

> **Vercel은 NestJS에 부적합** (검토 결과):
> - 챗봇 SSE 스트리밍이 Function 실행 시간 제한에 걸림
> - WebSocket 사실상 불가
> - NestJS 부트 무거워 cold start ↑
> - 항시 켜둘 API에 Function 호출당 과금은 비효율
> → 항시 떠있는 서버 호스팅이 필요.

| 후보 | 장점 | 단점 |
|---|---|---|
| **Fly.io** | Edge 지역(도쿄 가능), Docker 기본, Supabase와 같은 리전 배치 가능 | 약간의 러닝커브 |
| **Railway** | 셋업 가장 빠름, GitHub 자동 배포 | 가격 트래픽 따라 변동 |
| **Render** | 무난, GitHub 자동 배포 | cold start, 스케일 제한 |

> **추천**: **Fly.io** (`ap-northeast-1`/도쿄 리전 — Supabase와 동일 리전 → DB 레이턴시 최소화). Supabase 계정 생성 후 리전 확정하고 함께 결정.

---

## 5. 환경 변수 매트릭스

| 변수 | api | web | admin | mobile |
|---|:-:|:-:|:-:|:-:|
| `DATABASE_URL` | ✅ | — | — | — |
| `DIRECT_URL` | ✅ | — | — | — |
| `SUPABASE_URL` | ✅ | ✅ | ✅ | ✅ |
| `SUPABASE_ANON_KEY` | — | ✅ | ✅ | ✅ |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ | — | — | — |
| `JWT_SECRET` (Supabase) | ✅ | — | — | — |
| `OPENAI_API_KEY` / `AI_GATEWAY_KEY` | ✅ | — | — | — |
| `API_BASE_URL` | — | ✅ | ✅ | ✅ |
| `EXPO_PUBLIC_*` | — | — | — | ✅ |

> Vercel: 프로젝트별 환경변수에 등록. 로컬은 `vercel env pull`.
> Fly.io: `flyctl secrets set`.
> Expo: `app.config.ts` + EAS secrets.

---

## 6. 초기화 순서 (실행 계획)

### Phase 1 — 인프라 셋업 (선행)
- [x] `yougabell-moblie` → `yougabell-mobile` 레포명 변경
- [ ] Supabase 프로젝트 생성 (`youth-dev` 우선)
- [ ] Vercel 팀/프로젝트 셋업 (web, admin)
- [ ] Fly.io / Railway 계정 셋업 (api 호스팅 결정 후)
- [ ] 인증 결정 (Supabase Auth 추천)

### Phase 2 — API 부트스트랩 (기준점)
- [ ] `yougabell-api` 클론 → NestJS + Prisma 초기화
- [ ] `prisma/schema.prisma` 작성 (docs/schema/01~10 도메인 옮김)
- [ ] 첫 마이그레이션 → Supabase dev 반영
- [ ] OpenAPI 스펙 export 셋업 (`@nestjs/swagger`)
- [ ] CI: lint, build, prisma migrate deploy

### Phase 3 — 클라이언트 부트스트랩 (병렬 가능)
- [ ] `yougabell-web` — Next.js 16, Tailwind, OpenAPI 코드젠
- [ ] `yougabell-admin` — Next.js 16, Tailwind, OpenAPI 코드젠, 인증 게이트
- [ ] `yougabell-mobile` — Expo, WebView 셸, OpenAPI 코드젠

### Phase 4 — 통합
- [ ] web ↔ api 동작 확인 (1개 도메인 — 예: `/users/me`)
- [ ] mobile ↔ web WebView 통합
- [ ] admin ↔ api 콘텐츠 등록 플로우

---

## 7. 각 레포 공통 구조 (제안)

```
.
├── .github/
│   ├── workflows/
│   │   ├── ci.yml            # lint, build, test
│   │   └── deploy.yml        # 환경별 배포
│   └── PULL_REQUEST_TEMPLATE.md
├── .vscode/
│   └── settings.json
├── src/
├── CLAUDE.md                 # 레포별 컨벤션 (전역 ~/.claude/CLAUDE.md 보완)
├── README.md
├── .env.example
├── .gitignore
├── .nvmrc                    # Node 22 LTS
├── package.json
├── pnpm-lock.yaml
└── tsconfig.json
```

> 패키지 매니저: **pnpm** 통일.
> Node: **24 LTS** 통일.
> TS: `strict: true` 통일.

---

## 8. 미해결 / 추후 결정

- [ ] 인증 솔루션 (Supabase Auth 추천 → 확정 필요)
- [ ] NestJS 호스팅 (Fly.io 추천 → 확정 필요)
- [ ] CMS 솔루션 vs 자체 admin (현재 자체 admin 방향)
- [ ] CI/CD 디테일 (GitHub Actions vs Vercel 자동)
- [ ] 도메인/서브도메인 구조 (`app.youth.kr`, `admin.youth.kr`, `api.youth.kr` 등)
- [ ] 모니터링 (Sentry, Vercel Analytics, Supabase Logs)
- [ ] OpenAPI 코드젠 도구 선택 (`openapi-typescript` vs `orval` vs `kubb`)

---

## 변경 이력

- 2026-05-03 — 초안. 4 레포 완전 분리 + Supabase/Prisma 전략 + OpenAPI 기반 타입 공유.
