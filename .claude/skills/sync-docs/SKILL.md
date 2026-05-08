---
name: sync-docs
description: 특정 기간의 커밋을 분석하여 문서(AGENTS.md, DESIGN.md, docs/)에 반영되지 않은 변경사항을 찾고 문서를 업데이트합니다.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: "[기간: today, 3d, 1w, 2w, 또는 커밋해시]"
---

# 커밋 기반 문서 동기화

인자: `$ARGUMENTS`

## 1단계: 기간 파싱 및 커밋 조회

| 인자     | 의미           | git 명령                |
| -------- | -------------- | ----------------------- |
| `today`  | 오늘 커밋      | `--since="00:00"`       |
| `3d`     | 최근 3일       | `--since="3 days ago"`  |
| `1w`     | 최근 1주       | `--since="1 week ago"`  |
| `2w`     | 최근 2주       | `--since="2 weeks ago"` |
| `<hash>` | 특정 커밋 이후 | `<hash>..HEAD`          |
| (없음)   | 오늘 커밋      | `--since="00:00"`       |

```bash
git log --oneline --since="<기간>"
git log --stat --since="<기간>"
```

## 2단계: 변경사항 분류

| 변경 유형                 | 문서 필요 | 대상 문서                                                       |
| ------------------------- | --------- | --------------------------------------------------------------- |
| 스택·레포 결정            | O         | umbrella `AGENTS.md` (현재 상태 체크리스트 포함)                |
| 새 기능 (사용자 시나리오) | O         | umbrella `yougabell/docs/features/YYYYMMDD-<slug>.md`           |
| 새 도메인 모듈            | O         | 해당 레포 `AGENTS.md` + umbrella `yougabell/docs/schema/`       |
| 새 API 엔드포인트         | O         | umbrella `yougabell/docs/features/` (계약) + OpenAPI export     |
| Prisma 스키마 변경        | O         | umbrella `yougabell/docs/schema/` (의미) + api `prisma/` (코드) |
| 디자인 토큰·컴포넌트      | O         | 해당 레포 `DESIGN.md`                                           |
| 인증·미들웨어 변경        | O         | 해당 레포 `AGENTS.md`                                           |
| 단순 리팩토링             | △         | 구조·디렉토리 변경 시만                                         |
| 버그 수정·스타일 변경     | X         | -                                                               |

## 3단계: 기존 문서 확인

```bash
ls -la docs/ 2>/dev/null
cat AGENTS.md
cat DESIGN.md 2>/dev/null
```

각 변경사항이 이미 문서화되었는지 Grep으로 확인:

- 문서에 관련 내용이 있는지 검색
- 문서 최종 수정일과 커밋 날짜 비교

## 4단계: 누락 문서 작성/갱신

### 기존 문서 수정

- 해당 섹션 갱신
- 변경일 명시 (예: `> 갱신 2026-05-08`)

### 새 문서 작성

- 일지: `docs/logs/YYYYMMDD-<topic>.md` (해당 디렉토리가 있는 레포만)
- 설계: `docs/design/YYYYMMDD-<topic>.md`
- 관련 커밋 해시 본문에 참조

### AGENTS.md 갱신

- 디렉토리 구조 변경 반영
- 새 규칙·패턴 추가
- umbrella의 "현재 상태" 체크리스트도 동시 갱신

## 5단계: 문서 포매팅

```bash
pnpm prettier --write "**/*.md" --ignore-unknown
# 또는: npx --yes prettier@latest --write "**/*.md" --ignore-unknown
```

## 6단계: 결과 보고

### 분석 요약

```
분석 기간: <시작> ~ <끝>
총 커밋: N개
문서 갱신 필요: M개
```

### 갱신 내역

| 문서                     | 변경 유형 | 관련 커밋 |
| ------------------------ | --------- | --------- |
| AGENTS.md                | 수정      | abc1234   |
| docs/logs/20260508-\*.md | 신규      | def5678   |

### 미반영·판단 애매 항목

- 수동 확인 필요 항목 명시
