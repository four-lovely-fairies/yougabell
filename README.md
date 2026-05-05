# Working Mom Dad

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

### 1. 워크스페이스 디렉토리 만들기

```bash
mkdir -p ~/Workspace/youth
cd ~/Workspace/youth
```

> 디렉토리 이름은 자유. 본 문서는 `~/Workspace/youth/`를 가정.

### 2. 5개 레포 클론 (병렬)

```bash
gh repo clone youth-corp/working-mom-dad &
gh repo clone youth-corp/working-mom-dad-api &
gh repo clone youth-corp/working-mom-dad-web &
gh repo clone youth-corp/working-mom-dad-admin &
gh repo clone youth-corp/working-mom-dad-mobile &
wait
```

`gh` 없이 https로:
```bash
for r in working-mom-dad working-mom-dad-api working-mom-dad-web working-mom-dad-admin working-mom-dad-mobile; do
  git clone "https://github.com/youth-corp/$r.git" &
done
wait
```

### 3. 워크스페이스 루트 심볼릭 링크

워크스페이스 루트에서 사이블링 레포(api/web/admin/mobile)에서 작업 시 **부모 traversal로 umbrella 컨텍스트가 잡히도록** 심볼릭 링크를 만듭니다:

```bash
cd ~/Workspace/youth
ln -s working-mom-dad/CLAUDE.md CLAUDE.md
```

> Claude Code: 워크스페이스 루트의 `CLAUDE.md` 심볼릭 링크 → umbrella의 `CLAUDE.md` → `@AGENTS.md` import 체인으로 컨텍스트 로드.
>
> Codex: 각 레포의 `AGENTS.md`만 읽으므로 심볼릭 링크는 무관.

### 4. 의존성 설치 (5 레포 일괄)

```bash
for r in working-mom-dad-api working-mom-dad-web working-mom-dad-admin working-mom-dad-mobile; do
  (cd "$r" && pnpm install) &
done
wait
```

> `working-mom-dad`(umbrella)는 코드가 없어 `pnpm install` 불필요.

### 5. 환경 변수

각 레포의 `.env.example`을 `.env`(혹은 web/admin은 `.env.local`)로 복사한 뒤 채워 넣습니다.

```bash
for r in working-mom-dad-api working-mom-dad-web working-mom-dad-admin working-mom-dad-mobile; do
  cp "$r/.env.example" "$r/.env" 2>/dev/null || true
done
```

| 레포 | 필수 키 |
|---|---|
| api | `DATABASE_URL` (Supabase pooled 6543), `DIRECT_URL` (5432), `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET` |
| web | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_API_BASE_URL` |
| admin | 동일 + `SUPABASE_SERVICE_ROLE_KEY` (서버 전용) |
| mobile | `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`, `EXPO_PUBLIC_API_BASE_URL` |

> Supabase 프로젝트 자격증명은 별도 채널로 공유. 레포에 push 금지.

### 6. 개발 서버 실행

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
├── CLAUDE.md → working-mom-dad/CLAUDE.md  (심볼릭 링크)
├── working-mom-dad/                       (umbrella, 본 레포)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── README.md  ← 지금 보고 있는 문서
├── working-mom-dad-api/                   (NestJS + Prisma, anchor)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   ├── docs/
│   │   ├── design/00-repo-strategy.md
│   │   └── schema/                        (도메인 스키마 11개)
│   └── prisma/schema.prisma               (DB 진실의 소스)
├── working-mom-dad-web/                   (Next.js, Vercel)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── DESIGN.md
├── working-mom-dad-admin/                 (Next.js, Vercel)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── DESIGN.md
└── working-mom-dad-mobile/                (Expo, EAS)
    ├── AGENTS.md
    ├── CLAUDE.md
    └── DESIGN.md
```

---

## 더 알아보기

- 워크스페이스 큰 그림·아키텍처·결정 사항: [`AGENTS.md`](./AGENTS.md)
- 도메인 스키마 11개: [`working-mom-dad-api/docs/schema/`](https://github.com/youth-corp/working-mom-dad-api/tree/main/docs/schema)
- 레포 전략·DB·인증 결정: [`working-mom-dad-api/docs/design/00-repo-strategy.md`](https://github.com/youth-corp/working-mom-dad-api/blob/main/docs/design/00-repo-strategy.md)
