# 육아밸

> 워킹맘/워킹대디를 위한 육아 정보·기록·AI 챗봇 서비스.
> 본 레포는 **워크스페이스 umbrella** — 5개 분리 레포의 인덱스/큰 그림만 보관합니다.
> 프로젝트 컨텍스트 전체는 [`AGENTS.md`](./AGENTS.md) 참조.

---

## 워크스페이스 셋업 (다른 PC / 신규 동료)

### 사전 요구사항

| 도구 | 버전 |
|---|---|
| Node | 24 LTS (`.nvmrc` 참조, `nvm install 24 && nvm use 24`) |
| pnpm | 10.x (`corepack enable && corepack prepare pnpm@latest --activate`) |
| Git | 최신 |
| `gh` CLI | 인증된 상태 권장 (`gh auth login`) |

### 한 번에 셋업 (권장)

워크스페이스 디렉토리에서 umbrella만 먼저 클론한 뒤 부트스트랩 스크립트 실행:

```bash
mkdir -p ~/Workspace/youth && cd ~/Workspace/youth
git clone https://github.com/four-lovely-fairies/yougabell.git
yougabell/scripts/bootstrap.sh
```

스크립트가 자동으로 처리하는 작업:
1. 4개 서비스 레포(api/web/admin/mobile) 병렬 클론
2. 워크스페이스 루트 `CLAUDE.md → yougabell/CLAUDE.md` 심볼릭 링크 생성
3. 4개 서비스 레포에서 `pnpm install` 병렬 실행
4. 각 `.env.example` → `.env` 복사

> 이미 클론된 레포·존재하는 심볼릭 링크·기존 `.env`는 건드리지 않습니다 (idempotent).
> 스크립트 본문: [`scripts/bootstrap.sh`](./scripts/bootstrap.sh)

### 수동 셋업 (스크립트 안 쓸 때)

<details>
<summary>단계별 수동 명령</summary>

#### 1. 워크스페이스 디렉토리

```bash
mkdir -p ~/Workspace/youth && cd ~/Workspace/youth
```

> 디렉토리 이름은 자유.

#### 2. 5개 레포 클론 (병렬)

```bash
for r in yougabell yougabell-api yougabell-web yougabell-admin yougabell-mobile; do
  git clone "https://github.com/four-lovely-fairies/$r.git" &
done
wait
```

#### 3. 워크스페이스 루트 심볼릭 링크

```bash
ln -s yougabell/CLAUDE.md CLAUDE.md
```

> Claude Code: 워크스페이스 루트의 `CLAUDE.md` 심볼릭 링크 → umbrella `CLAUDE.md` → `@AGENTS.md` import 체인으로 컨텍스트 로드.
> Codex: 각 레포의 `AGENTS.md`만 읽으므로 심볼릭 링크는 무관.

#### 4. 의존성 설치

```bash
for r in yougabell-api yougabell-web yougabell-admin yougabell-mobile; do
  (cd "$r" && pnpm install) &
done
wait
```

#### 5. 환경 변수

```bash
for r in yougabell-api yougabell-web yougabell-admin yougabell-mobile; do
  cp "$r/.env.example" "$r/.env" 2>/dev/null || true
done
```

</details>

### 환경 변수 채우기

| 레포 | 필수 키 |
|---|---|
| api | `DATABASE_URL` (Supabase pooled 6543), `DIRECT_URL` (5432), `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET` |
| web | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_API_BASE_URL` |
| admin | 동일 + `SUPABASE_SERVICE_ROLE_KEY` (서버 전용) |
| mobile | `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`, `EXPO_PUBLIC_API_BASE_URL` |

> Supabase 프로젝트 자격증명은 별도 채널로 공유. 레포에 push 금지.

### 개발 서버 실행

| 레포 | 명령 | 포트 |
|---|---|---|
| api | `pnpm start:dev` | 3000 |
| web | `pnpm dev` | 3001 (`PORT=3001 pnpm dev`) |
| admin | `pnpm dev` | 3002 (`PORT=3002 pnpm dev`) |
| mobile | `pnpm start` | Metro 8081 |

---

## 디렉토리 구조 (셋업 완료 후)

```
~/Workspace/youth/
├── CLAUDE.md → yougabell/CLAUDE.md  (심볼릭 링크)
├── yougabell/                       (umbrella, 본 레포)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── README.md  ← 지금 보고 있는 문서
├── yougabell-api/                   (NestJS + Prisma, anchor)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   ├── docs/
│   │   ├── design/00-repo-strategy.md
│   │   └── schema/                        (도메인 스키마 11개)
│   └── prisma/schema.prisma               (DB 진실의 소스)
├── yougabell-web/                   (Next.js, Vercel)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── DESIGN.md
├── yougabell-admin/                 (Next.js, Vercel)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── DESIGN.md
└── yougabell-mobile/                (Expo, EAS)
    ├── AGENTS.md
    ├── CLAUDE.md
    └── DESIGN.md
```

---

## 더 알아보기

- 워크스페이스 큰 그림·아키텍처·결정 사항: [`AGENTS.md`](./AGENTS.md)
- 도메인 스키마 11개: [`yougabell-api/docs/schema/`](https://github.com/four-lovely-fairies/yougabell-api/tree/main/docs/schema)
- 레포 전략·DB·인증 결정: [`yougabell-api/docs/design/00-repo-strategy.md`](https://github.com/four-lovely-fairies/yougabell-api/blob/main/docs/design/00-repo-strategy.md)
