# Knowledge Base 시드 콘텐츠

> RAG (Phase 4) 초기 시드. 챗봇 응답에 인용할 발달·육아 가이드.
> 기획: [`../../features/20260525-ai-integration.md`](../../features/20260525-ai-integration.md) §3.3.

---

## 파일명 규칙

```
<source>__<slug>.md
```

`source` ∈ `cdc` / `mohw` / `internal`

예: `cdc__milestones-4mo.md`, `mohw__aisarang-4mo.md`

`slug`는 사람이 읽기 쉬운 식별자 (kebab-case).

---

## 파일 포맷 (frontmatter + 본문)

```
---
title: 4개월 발달 마일스톤 (CDC Act Early)
sourceUrl: https://www.cdc.gov/ncbddd/actearly/milestones/milestones-4mo.html
license: Public Domain (CDC)
language: ko
---

<본문 — Markdown 또는 plain text>
```

### frontmatter 필드

| 필드        | 필수 | 설명                                                                                  |
| ----------- | :--: | ------------------------------------------------------------------------------------- |
| `title`     |  ✓   | DB에 저장되는 문서 제목 (사용자에게 출처로 노출)                                      |
| `sourceUrl` |  ?   | 원문 URL (있으면 챗 응답에 출처 링크로 노출). dedupe 기준                             |
| `license`   |  ✓   | 라이선스 명시 (감사용). 예: `Public Domain (CDC)`, `공공저작물 자유이용 (보건복지부)` |
| `language`  |  ?   | 기본 `ko`. en/ja 등 (현재 모두 ko 권장)                                               |

---

## 라이선스·출처 확인 (필수)

| source              | 라이선스 근거                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------ |
| CDC Act Early       | 미 연방 정부 저작물 → Public Domain. cdc.gov 정책: "May be reproduced without permission." |
| 보건복지부 아이사랑 | 공공저작물 자유이용 (대한민국). 출처 표기 권장. childcare.go.kr 콘텐츠                     |
| internal            | 운영자 직접 작성. License는 `Internal (육아벨)` 표기                                       |

다른 외부 콘텐츠(AAP·도서 등)는 라이선스 검증 후 추가. 라이선스 불명 콘텐츠 추가 금지.

---

## Ingestion (수동)

```bash
cd yougabell-api
pnpm exec ts-node scripts/ingest-knowledge.ts
```

스크립트 동작:

1. 본 디렉토리(`docs/seed-data/knowledge/*.md`) 읽기 + frontmatter 파싱
2. char 기반 chunking (target ~650자 = 500 토큰 근사, overlap ~130자)
3. 50개 단위 batch embedMany (Gemini text-embedding-004, 768d)
4. `KnowledgeDocument` upsert (sourceUrl 기준)
5. 기존 chunks 삭제 + 신규 chunks `INSERT ... vector::vector` raw SQL

### 사전 조건

- Supabase 대시보드 SQL editor에서 1회: `CREATE EXTENSION IF NOT EXISTS vector;`
- `pnpm prisma:migrate:deploy` 또는 `db push` (KnowledgeDocument/Chunk/MessageRetrieval 테이블 생성)
- `.env`의 `GOOGLE_GENERATIVE_AI_API_KEY` 설정

### 재실행 안전

- 같은 sourceUrl이 있으면 document 갱신 + chunks 전체 교체. 새로 추가만 하려면 새 파일·새 URL.
- ingestion 실패해도 챗봇은 정상 동작 (retrieve 빈 결과 → 기존 응답 흐름).

---

## v1 시드 (초기)

- `cdc__milestones-4mo.md` — 4개월 CDC 발달 마일스톤
- `cdc__milestones-6mo.md` — 6개월
- `cdc__milestones-9mo.md` — 9개월
- `cdc__milestones-12mo.md` — 12개월
- `mohw__aisarang-toddler-tantrum.md` — 영유아 떼쓰기 (보건복지부 가이드)
- `mohw__aisarang-sleep-routine.md` — 영유아 수면 루틴

> v1 시드는 챗봇 검증·시연 용도. 운영자가 콘텐츠를 직접 큐레이션·확장하면 됨.
> 추가 시 본 README의 시드 목록 갱신.
