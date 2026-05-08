# `docs/` 작성 규칙

> 본 디렉토리는 umbrella 레포의 **기획·결정 진실의 소스**.
> AI 에이전트(Claude Code · Codex · Cursor 등)가 docs/\*를 작성·수정할 때 본 문서를 우선 룰로 따른다.
> 글로벌·워크스페이스 룰(`~/.claude/CLAUDE.md` + umbrella 루트 `AGENTS.md`)을 상속하며, **충돌 시 본 문서가 우선**한다.

---

## 0. 어디에 무엇을 쓰나 (라우팅)

새 문서를 작성할 때 다음 결정 트리:

```
변경 사항이 …
├── 워크스페이스 결정 (스택, 인증, 호스팅 등)
│   → umbrella 루트 `AGENTS.md` "현재 상태" 섹션 갱신 (별도 docs 파일 X)
│
├── 레포 분리 정책 / 인프라 결정 / 장기 아키텍처
│   → docs/design/NN-<topic>.md
│
├── 도메인 엔티티 (User, Child, Mission 등) 의미·관계·필드
│   → docs/schema/NN-<entity>.md
│
└── 새 기능 (사용자 시나리오 동반, multi-repo 영향)
    → docs/features/YYYYMMDD-<feature-slug>.md
```

각 sub-directory의 자체 `AGENTS.md`에 세부 규칙 명시.

---

## 1. 각 sub-directory 역할

| 디렉토리         | 역할                                                           | 명명              | 규칙 파일                                  |
| ---------------- | -------------------------------------------------------------- | ----------------- | ------------------------------------------ |
| `docs/design/`   | 워크스페이스·아키텍처·인프라 결정 (장기, 자주 안 바뀜)         | `NN-<topic>`      | [design/AGENTS.md](./design/AGENTS.md)     |
| `docs/schema/`   | 도메인 엔티티 의미 문서 (Prisma schema의 사람이 읽는 layer)    | `NN-<entity>`     | [schema/AGENTS.md](./schema/AGENTS.md)     |
| `docs/features/` | 새 기능 기획서 (사용자 시나리오 → 도메인 → 레포별 작업 → 구현) | `YYYYMMDD-<slug>` | [features/AGENTS.md](./features/AGENTS.md) |

---

## 2. 공통 작성 원칙

### 2.1 multi-repo 영향 즉시 인지

본 워크스페이스는 5개 레포(api/web/admin/mobile/umbrella)로 분리됨. **새 작업이 어느 레포에 영향을 주는지 작성 시작 전에 식별**.

| 신호                                 | 영향 레포             |
| ------------------------------------ | --------------------- |
| Prisma 모델·필드 변경                | `yougabell-api`       |
| 새 endpoint·Auth Guard·LLM 호출      | `yougabell-api`       |
| 사용자 화면 추가/수정                | `yougabell-web`       |
| 운영자가 봐야 할 데이터              | `yougabell-admin`     |
| 푸시·딥링크·카메라·생체·WebView 통신 | `yougabell-mobile`    |
| 본 기획·결정 문서                    | `yougabell`(umbrella) |

영향 레포가 2개 이상이면 **레포별 작업 분해 표** 필수.

### 2.2 self-contained

본 docs/\* 문서만 읽고 개발 시작이 가능해야 한다. 다른 docs 참조는 **보강용**이고 강제 X. 핵심 명세(스키마 diff, API 계약, 컴포넌트 인터페이스)는 본문에 직접 작성.

### 2.3 결정 vs 미해결 명시

- 결정된 항목: `**결정 (YYYY-MM-DD)**`로 마킹
- 미해결: `[ ]` 체크박스
- 폐기된 옵션: ~~취소선~~으로 보존 (왜 안 골랐는지 추적)

### 2.4 와이어프레임 vs 최종 디자인 구분

Figma 노드를 참조할 때:

- **와이어프레임이면 헤더에 명시**, "기능·구조만 참고, 색·hex·폰트 무시" 표 작성
- 최종 디자인은 `web/DESIGN.md` 토큰을 따름. docs에서 hex 직접 박지 말 것

### 2.5 AI 챗봇 컨텍스트 고려

본 제품은 사용자 입력 → AI 챗봇 컨텍스트 주입이 핵심 가치. 새 입력 필드 설계 시:

- 자유 텍스트 vs enum 분류 → **자유 텍스트 우선** (LLM이 사후 추출 가능)
- 단, 정형 입력이 자명한 곳(생년월일, 성별 등)은 정형 유지
- 카테고리화는 분석 요구가 명확해질 때만 도입

---

## 3. GitHub URL 절대 경로

다른 레포 파일 참조 시 GitHub URL 절대 경로 사용 (umbrella 루트 `AGENTS.md` "레포 간 참조 규칙" 동일). docs/\* 내부 상호 참조는 **상대 경로** 허용.

---

## 4. 포매팅·커밋

- 작성·수정 후 `pnpm dlx prettier@latest --write <file>` 의무
- 커밋: 한글 Conventional Commits, prefix·scope 영어
  - 예: `docs: 온보딩 v2 기획서 작성`
  - 예: `docs(schema): User에 workStatus·onboardedAt 반영`
- Claude 협력 문구 절대 포함 X
- 한 문서 1커밋 원칙. 여러 문서 동시 작성 시 의미 단위로 분리.
