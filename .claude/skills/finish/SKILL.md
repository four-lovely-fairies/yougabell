---
name: finish
description: 현재 작업을 마무리합니다. 변경사항을 분석하여 문서를 업데이트하고 AGENTS.md 규칙에 맞게 한글 Conventional Commits로 커밋합니다.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# 작업 마무리 (구현 → 문서 → 포매팅 → 커밋)

## 중요: 워킹트리 전체가 대상

- 이번 세션 작업과 무관하게 **워킹트리의 모든 변경사항**을 분석하고 커밋
- 이전 세션에서 커밋하지 못한 변경사항도 포함
- staged/unstaged/untracked 모든 파일을 빠짐없이 처리
- 변경사항을 임의로 제외하지 않음

## 1단계: 변경사항 분석

```bash
git status
git diff --stat
git diff
```

각 변경 파일에 대해:

- 어떤 기능이 추가/수정되었는지 파악
- 관련 문서가 있는지 확인
- 다른 레포(`yougabell-api` / `web` / `admin` / `mobile`)에 전파 필요 여부 검토 (umbrella `AGENTS.md`의 "레포 의존 그래프" / "크로스 레포 작업 흐름" 참조)

## 2단계: 문서 업데이트

| 변경 유형                 | 문서 위치                                                                        |
| ------------------------- | -------------------------------------------------------------------------------- |
| 스택·아키텍처 결정        | umbrella `AGENTS.md`                                                             |
| 도메인/모듈 구조          | 해당 레포 `AGENTS.md`                                                            |
| 새 기능 기획              | umbrella `yougabell/docs/features/YYYYMMDD-<slug>.md` (`_template.md` 복사)      |
| 도메인 모델 변경 (의미)   | umbrella `yougabell/docs/schema/`                                                |
| Prisma 스키마 변경 (코드) | `yougabell-api/prisma/schema.prisma` + 마이그레이션                              |
| API 엔드포인트            | umbrella `yougabell/docs/features/` (계약·기획) + OpenAPI export (api 자동 생성) |
| 디자인 토큰·컴포넌트      | 해당 레포 `DESIGN.md` (web/admin/mobile)                                         |
| 새 기능 일지              | `docs/logs/YYYYMMDD-<title>.md` (해당 디렉토리 있는 경우)                        |
| 워크스페이스 진행 상태    | umbrella `AGENTS.md`의 "현재 상태" 체크리스트                                    |

문서가 이미 있으면 해당 섹션 갱신, 없으면 적절한 위치에 새로 작성.

## 3단계: Prettier 포매팅

커밋 전 변경된 파일 포매팅 (워크스페이스 컨벤션 — `.md` 포함 필수):

```bash
pnpm prettier --write . --ignore-unknown
# pnpm/prettier 미설정 레포(umbrella 등):
# npx --yes prettier@latest --write . --ignore-unknown
```

## 4단계: 커밋

### 커밋 규칙 (umbrella `AGENTS.md` "커밋 메시지 규칙" 기준)

- **Conventional Commits + 한글**
  - prefix·scope는 영어 (`feat`, `fix`, `chore`, `docs`, `refactor`, `perf`, `test`, `style`, `revert`)
  - 제목·본문은 한글
- **scope**: 레포 short form 또는 모듈명 — `feat(api):`, `chore(web):`, `refactor(mobile):`
- **Co-Authored-By / Claude 협력 문구 절대 포함 금지**
- 파일은 **기능별로 그룹핑**해서 커밋 (전체 묶음 커밋 금지)

### 커밋 순서

1. 기능 코드 → 2. 관련 문서 → 3. 포매팅 단독 변경

### 커밋 명령

```bash
git add <files>
git commit -m "$(cat <<'EOF'
<type>(<scope>): <한글 설명>

<필요 시 본문>
EOF
)"
```

### 예시

```
feat(api): Prisma 스키마에 마음 케어 모듈 추가
chore(api): jest 인프라 제거 (테스트 미작성)
refactor(web): src 폴더 제거하고 app/ 루트로 이동
docs: 레포 전략 문서에 Supabase Auth 결정 반영
```

## 5단계: 결과 보고

- 생성된 커밋 목록 (`git log --oneline -n <count>`)
- 업데이트된 문서 목록
- 다른 레포에 전파해야 할 변경사항 (있다면 명시)
- 남은 작업 여부
