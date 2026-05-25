# AI 통합 (Chat + Weekly Report)

> 작성일: 2026-05-25 · 작성자: — · 상태: `approved` (Phase 0 결정 완료 2026-05-25)
> 관련 스키마: [`../schema/07-chat.md`](../schema/07-chat.md), [`../schema/08-report.md`](../schema/08-report.md)
> 관련 기능: [`20260513-weekly-report.md`](./20260513-weekly-report.md) (기존 구현된 weekly-report 화면·API)
>
> **두 곳에 LLM 도입**: ① AI 챗봇 페이지(`/chat`), ② 주간 리포트 일부 필드(headlineBody / bestMoments[].body / aiActionSuggestion). 모든 LLM 호출은 **`yougabell-api`(NestJS)** 가 처리. web/admin/mobile은 결과만 소비.

---

## 1. 배경 (Why)

육아밸 v0.1은 정적 데이터·집계 기반으로 사용자 경험을 구성한다. 진짜 가치는 **개인화된 답변과 회고**에서 나온다:

- **챗봇** — 부모는 "내 아이는 지금 왜 이러는지", "어떻게 해야 하는지" 즉답을 원함. 검색·블로그·맘카페로 흩어진 답을 한곳에서 맞춤 응답으로. 현재 `/chat` 페이지는 **데모 응답 시뮬레이션(1.5초 지연)** 만 구현된 상태.
- **주간 리포트** — 집계 수치(요일별 미션 완료·키워드 Top 3·심리 에너지)만으로는 "지난주 어땠지?"에 정서적 회고를 제공하지 못함. AI가 **격려 문장(headline body) / 베스트 모먼트 서사(bestMoment.body) / 다음 행동 제안(aiActionSuggestion)** 을 생성해 정량 → 정성 회고로 변환.

두 영역 모두 **사용자 맥락**(아이 정보·최근 미션·기록)을 system prompt로 합성해 일관된 톤·근거로 응답.

---

## 2. 사용자 시나리오 (What)

### 2.1 AI 챗봇 (`/chat`)

- **누가**: 온보딩 완료 후의 사용자
- **언제**: BottomNav `AI 상담` 탭, 홈 카드, 알림에서 진입
- **흐름**:

  ```mermaid
  flowchart LR
      H[홈/탭] --> C[/chat 페이지]
      C --> E[빈 상태 or 최근 대화 복원]
      E -- 입력/quick reply --> S[SSE stream 시작]
      S --> T[토큰 단위 typing effect]
      S --> F[완료 → cards + sources 우르르]
      F --> H2[메시지 DB 저장]
      H2 --> C
  ```

- **수용 기준**:
  - 페이지 재진입 시 직전 대화 복원 (단일 영속 세션)
  - 응답은 **streaming** 노출 — 첫 토큰 ≤ 1.5초, 끝까지 ≤ 8초 목표
  - 응답 끝나면 카드/출처 링크가 한꺼번에 나타남
  - 사용자 메시지·어시스턴트 응답 모두 DB 영속화
  - 세션은 사용자당 1개만 유지 (lazy create on first message)

### 2.2 주간 리포트 AI 필드

- **누가**: WeeklyReport 생성 시점 (월요일 00:00 KST cron — 기존 [`20260513-weekly-report.md`](./20260513-weekly-report.md))
- **언제**: cron이 집계 완료 후 3개 AI 필드 1회 호출로 생성
- **흐름**: 집계 데이터 + 사용자 컨텍스트 → LLM → JSON 응답 → 3개 필드 채워 DB 저장
- **수용 기준**:
  - LLM 실패 시 fallback 텍스트("이번 주도 함께해주셔서 감사해요" 등)로 row는 항상 생성
  - 한 자녀당 1주에 1회만 호출 (재실행 시 skip — `generatedAt` 체크)

---

## 3. 도메인 영향

### 3.1 챗 도메인 (schema/07-chat.md 모델 확정)

스키마 문서엔 이미 모델 설계가 있지만 Prisma 코드에 미구현. 본 기능으로 실제 테이블 추가.

| 엔티티        | 변경 종류   | 비고                                                               |
| ------------- | ----------- | ------------------------------------------------------------------ |
| `ChatSession` | 신규 테이블 | userId 1:1 lazy create. title은 자동 요약(LLM) 또는 첫 메시지 요약 |
| `ChatMessage` | 신규 테이블 | role(user/assistant), content, sentAt, tokensUsed?                 |
| `MessageCard` | 신규 테이블 | assistant 메시지 임베드 카드. actionType / actionPayload(jsonb)    |
| `SourceLink`  | 신규 테이블 | 어시스턴트 응답 출처 URL                                           |

#### Prisma schema diff

```prisma
model ChatSession {
  id        String   @id @default(uuid()) @db.Uuid
  userId    String   @unique @db.Uuid
  title     String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  user     User          @relation(fields: [userId], references: [id], onDelete: Cascade)
  messages ChatMessage[]

  @@index([userId])
}

model ChatMessage {
  id         String   @id @default(uuid()) @db.Uuid
  sessionId  String   @db.Uuid
  role       ChatRole
  content    String
  tokensUsed Int?
  sentAt     DateTime @default(now())

  session     ChatSession    @relation(fields: [sessionId], references: [id], onDelete: Cascade)
  cards       MessageCard[]
  sourceLinks SourceLink[]

  @@index([sessionId, sentAt])
}

enum ChatRole {
  user
  assistant
}

model MessageCard {
  id            String              @id @default(uuid()) @db.Uuid
  messageId     String              @db.Uuid
  order         Int
  title         String
  body          String
  actionType    MessageCardAction?
  actionPayload Json?

  message ChatMessage @relation(fields: [messageId], references: [id], onDelete: Cascade)

  @@index([messageId])
}

enum MessageCardAction {
  none
  start_mission
  open_link
  follow_up
}

model SourceLink {
  id        String @id @default(uuid()) @db.Uuid
  messageId String @db.Uuid
  url       String
  domain    String
  title     String?

  message ChatMessage @relation(fields: [messageId], references: [id], onDelete: Cascade)

  @@index([messageId])
}
```

마이그레이션 이름: `add_chat_models`.

### 3.2 주간 리포트 AI 필드 확장

[`20260513-weekly-report.md`](./20260513-weekly-report.md)는 이미 `WeeklyReport` / `WeeklyReportBestMoment` / `aiActionSuggestion` 컬럼을 정의했다. 본 기능은 다음 필드를 LLM이 채우도록 변경:

| 필드                                               | 변경 종류                               | 비고                                                      |
| -------------------------------------------------- | --------------------------------------- | --------------------------------------------------------- |
| `WeeklyReport.headlineBody`                        | LLM 생성                                | 기존 정적 텍스트 → 사용자별 격려 문장                     |
| `WeeklyReportBestMoment.body`                      | LLM 생성                                | 기존 mission `effect` 텍스트 → 사용자/자녀 맥락 반영 서사 |
| `WeeklyReport.aiActionSuggestion`                  | LLM 생성 (기존 schema에 이미 컬럼 존재) | 1단락 행동 제안                                           |
| `WeeklyReport.aiGeneratedAt`                       | 신규                                    | LLM 호출 성공 시각. fallback 사용 시 null                 |
| `WeeklyReport.aiPromptTokens`/`aiCompletionTokens` | 신규                                    | 비용 추적용. nullable                                     |

마이그레이션 이름: `add_weekly_report_ai_fields`.

### 3.3 RAG 인프라 (Phase 4 — 단계적 도입)

> **결정**: 전체 RAG (외부 + 내부) 도입. 단 v1엔 미적용 — 별도 Phase로 분리. v1은 LLM 도메인 지식 + system prompt context 만으로 운영.

| 엔티티              | 변경 종류   | 비고                                                       |
| ------------------- | ----------- | ---------------------------------------------------------- |
| `KnowledgeDocument` | 신규        | 외부/내부 콘텐츠 metadata (source, license, ingestedAt)    |
| `KnowledgeChunk`    | 신규        | 텍스트 청크 + embedding vector. Supabase **pgvector** 권장 |
| `MessageRetrieval`  | 신규 (감사) | 챗 응답이 어떤 chunk를 retrieve했는지 (감사·튜닝용)        |

> Vector DB·embedding 모델·ingestion pipeline 결정은 §7 미해결로 분리. v2 Phase 4 진입 직전 별도 의사결정.

---

## 4. 레포별 작업 분해

| 레포               | 작업                                                                                                                 | 의존성       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------- | ------------ |
| `yougabell-api`    | 챗 도메인 모델 + `POST /me/chat/messages` (SSE) + `GET /me/chat` + 주간 리포트 LLM 호출 통합 + `@ai-sdk/google` 셋업 | 선행 (1순위) |
| `yougabell-web`    | `/chat` 페이지 DB 영속화 연결 + SSE 수신 클라이언트 + 주간 리포트 화면(이미 구현, AI 필드 노출만 확인)               | api 완료 후  |
| `yougabell-admin`  | (Phase 4) RAG 콘텐츠 큐레이션 화면                                                                                   | 별도 단계    |
| `yougabell-mobile` | 변경 없음 (WebView로 `/chat` 자동 노출)                                                                              | —            |

### 4.1 `yougabell-api`

#### 의존성 추가

```bash
pnpm add ai @ai-sdk/google
```

#### 환경 변수

| 변수                           | 설명                                  |
| ------------------------------ | ------------------------------------- |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Gemini API 키 (Google AI Studio 발급) |
| `AI_CHAT_MODEL`                | 기본 `gemini-2.5-flash`               |
| `AI_REPORT_MODEL`              | 기본 `gemini-2.5-flash`               |

Render 대시보드 + `.env.example` 양쪽에 추가.

#### 디렉토리 구조

```
ai/
├── ai.module.ts              # @Global() — 다른 모듈에서 inject
├── ai-config.service.ts      # provider 인스턴스, model 키 노출
├── context-builder.service.ts # user+children+missions+battery+report → prompt context
└── prompts/
    ├── chat-system.ts        # 챗 system prompt 템플릿
    └── weekly-report.ts      # 주간 리포트 JSON schema 정의 + system prompt

chat/
├── chat.module.ts
├── chat.controller.ts        # GET /me/chat, POST /me/chat/messages (SSE)
├── chat.service.ts           # session lazy create, message 영속화, LLM 호출
├── chat.types.ts
└── dto/
    ├── chat-response.dto.ts
    └── chat-message-request.dto.ts
```

`weekly-reports/` 모듈은 기존 모듈에 LLM 호출 통합 (별도 ai/ 의존).

#### 엔드포인트

| 메서드 + 경로                  | 설명                                                                                | Auth |
| ------------------------------ | ----------------------------------------------------------------------------------- | ---- |
| `GET /me/chat`                 | 세션 + 최근 N개(기본 50) 메시지 조회. 세션 없으면 lazy create 안 함(빈 응답)        | JWT  |
| `POST /me/chat/messages` (SSE) | 사용자 메시지 입력 → AI 응답 SSE 스트리밍. 완료 후 cards/sources 포함 final payload | JWT  |
| `DELETE /me/chat`              | 세션·메시지 전체 삭제 (사용자 명시 요청 시)                                         | JWT  |

#### SSE 응답 형식

```
event: token
data: {"text":"그 "}

event: token
data: {"text":"'딱 "}

...

event: done
data: {"content":"...전체 본문...","cards":[{"title":"잠자리 티켓","body":"..."}],"sources":[{"url":"...","domain":"..."}],"messageId":"<uuid>"}
```

- `event: token` — 토큰 stream (UI typing effect)
- `event: done` — 완료. cards/sources는 별도 LLM 호출(structured output) 또는 stream된 raw text에서 파싱
- `event: error` — LLM 실패. retry 안내 또는 fallback 응답

#### 주간 리포트 LLM 통합

`WeeklyReportsService.generateForWeek()` 마지막 단계에:

```ts
const ctx = await contextBuilder.forReport({
  userId,
  childId,
  weekStart,
  weekEnd,
  aggregated,
});
const result = await generateObject({
  model: google(AI_REPORT_MODEL),
  schema: WeeklyReportAiSchema, // zod
  system: WEEKLY_REPORT_SYSTEM_PROMPT,
  prompt: serialize(ctx),
});
// result.object = { headlineBody, bestMoments: [{order, body}], aiActionSuggestion }
```

실패 시 zod parse error 또는 timeout → fallback 텍스트 + `aiGeneratedAt=null`.

### 4.2 `yougabell-web`

#### `/chat` 페이지 — DB 영속화 + 실제 SSE 수신

현재 `app/chat/page.tsx` 컴포넌트 그대로 유지, 다음만 변경:

1. **마운트 시 `GET /me/chat`** → 기존 메시지 hydrate (현재는 빈 상태에서 시작)
2. **send() 함수** — `fetch + EventSource` 또는 `openApiClient` POST → SSE 수신 → 토큰 누적 → 완료 시 cards/sources 적용
3. **demo simulation 제거** — DEMO_REPLY 상수 삭제
4. **에러 처리** — SSE error 시 사용자에게 토스트 + retry 버튼

#### 주간 리포트 화면

기존 구현(`components/weekly-report/weekly-report-screen.tsx`)이 `headlineBody`·`bestMoments[].body`·`aiActionSuggestion`을 이미 표시. **변경 없음** — api가 채워주는 값을 그대로 노출.

### 4.3 `yougabell-mobile`

- 변경 없음. WebView로 `/chat` 그대로 노출. 단 SSE는 WebView 환경에서 정상 작동 확인 필요 (`EventSource` polyfill 불필요 — Safari/Chrome 모두 native 지원).

### 4.4 `yougabell-admin` (Phase 4)

- RAG 도입 시 콘텐츠 큐레이션 화면 — 1차 범위 외.

---

## 5. UI/디자인 참조

| 노드 ID      | 화면 / 요소         | 비고                                                        |
| ------------ | ------------------- | ----------------------------------------------------------- |
| `2395:12602` | 챗 - 03 (응답 카드) | 어시스턴트 메시지 + 카드 2개(잠자리 티켓 / 정서적 연결고리) |
| `2395:13021` | Sub LNB             | "Ai 챗봇" 타이틀 + 닫기 X                                   |
| `2395:13019` | 부제                | "사용자의 행동 데이터와 패턴을 기반으로 대화합니다."        |
| `2395:13142` | Input               | placeholder "궁금한 점을 입력해주세요." + 전송 ↑            |
| `2396:4751`  | Quick replies       | 3개 칩 (떼스는 아이 / 수면 조언 / Morning Routine)          |
| `2396:5003`  | Empty state         | 마스코트 image 599 + "궁금한점을 모두 물어보세요."          |
| `2183:6775`  | 주간 리포트 v03     | headline body / best moments / aiActionSuggestion 위치      |

### 디자인 토큰 변경

- **없음**. 챗 페이지는 이미 보라색 카드(`#f1eaff`/`#a483ff`)와 quick reply 칩으로 구현. 주간 리포트도 v03 구조 사용 중.

---

## 6. 비기능 요구

### 비용 관리

- **모델**: gemini-2.5-flash — 무료 티어 RPM 15 / TPM 1M / RPD 1500 (Google AI Studio 기준).
  - 챗: 사용자당 평균 일 5-10 메시지 가정 시 무료 티어 내.
  - 리포트: 자녀당 주 1회 → MAU 1000 / 다자녀 평균 1.3 가정 시 주 1300 호출 = 일 ~186 → 무료 티어 내.
- 무료 티어 초과 시 유료 전환 자동 — 사전 알람 설정.

### 환각·신뢰도

- v1: 출처 링크는 LLM이 생성한 URL 검증 안 함 → **클릭 시 사용자 자체 판단** UI 표기.
- v2 Phase 4: RAG 도입으로 LLM이 retrieved chunk에 명시된 source만 인용하도록 system prompt 강제.

### 응답 지연

- 챗: 첫 토큰 ≤ 1.5초, 끝까지 ≤ 8초. Render Free 플랜 cold start ~50초 대비 — warm-api workflow가 이미 5분 ping으로 idle sleep 방지(`yougabell-api/.github/workflows/warm-api.yml`).
- 리포트: 자녀별 LLM 호출 ~3-5초. 주간 배치 cron에서 순차 실행 OK.

### 보안

- API 키는 Render 환경 변수만. 코드·git 절대 노출 X.
- 챗 메시지는 사용자 PII 포함 가능 — Gemini 데이터 사용 정책 검토 (Google AI Studio 무료 티어는 모델 학습에 입력 데이터 사용 가능 → 사용자 동의 또는 유료 티어 전환 필요).
- ChatMessage `content`는 LLM 입력 그대로 저장 — 향후 redaction 필요 시 별도 작업.

### 분석 이벤트

| 이벤트 키                    | 발생 시점                                |
| ---------------------------- | ---------------------------------------- |
| `chat_open`                  | `/chat` 페이지 진입                      |
| `chat_message_send`          | 사용자 메시지 전송                       |
| `chat_response_first_token`  | SSE 첫 토큰 수신 (지연 측정)             |
| `chat_response_complete`     | SSE done 수신                            |
| `chat_response_error`        | SSE error 수신                           |
| `chat_quick_reply_use`       | quick reply 칩 클릭                      |
| `chat_source_link_open`      | 출처 링크 클릭                           |
| `weekly_report_ai_generated` | LLM 호출 성공 (props: tokens, latency)   |
| `weekly_report_ai_fallback`  | LLM 실패로 fallback 사용 (props: reason) |

---

## 7. 리스크·미해결 질문

### Phase 0 결정 사항 (2026-05-25)

- [x] ~~**AI 호출 위치**~~ → **NestJS api 내부**. web/admin/mobile은 결과만 소비. api를 AI용으로 분리한 본래 의도와 일치.
- [x] ~~**AI provider**~~ → **Gemini** (초기 무료 토큰). 추후 전환은 abstraction layer로 한 줄 교체.
- [x] ~~**SDK abstraction**~~ → **`@ai-sdk/google`** (Vercel AI SDK). streamText / generateObject / tool calling 표준화. provider 교체 시 한 줄.
- [x] ~~**모델 SKU**~~ → **gemini-2.5-flash** (chat·report 공통). 무료 RPM 여유. v2에서 리포트만 pro 분리 재평가.
- [x] ~~**Streaming**~~ → **SSE streaming + 최종 구조화 payload**. 본문은 token stream, cards/sources는 완료 시 한꺼번에.
- [x] ~~**Context window**~~ → **중간** (user + children + 최근 20건 mission(+feedback) + 최근 7일 battery + lastWeeklyReport 요약 + chat history 최근 10개).
- [x] ~~**챗 세션 모델**~~ → **단일 영속 세션** (User 1:1 ChatSession lazy create). Figma 사이드바 없음 → 1개로 충분. 컨텍스트 누적은 최근 N개 trim.
- [x] ~~**주간 리포트 AI 범위**~~ → **3개 필드** (headlineBody + bestMoments[].body + aiActionSuggestion). single call · multi field with generateObject + zod schema.
- [x] ~~**RAG 도입**~~ → **전체 RAG (외부 + 내부)**. 단 **v1 미적용** — Phase 4 별도 단계로 분리. 결정 근거: 출처 신뢰도·환각 방지가 본 제품의 차별점.

### v1 진행 중 모니터링

- [ ] Gemini 무료 티어 RPM 한도 도달 시 알람·자동 전환 정책 (Phase 2 진입 후 첫 주 모니터링).
- [ ] 사용자 PII 데이터가 Gemini 학습 입력으로 사용되지 않도록 — Google AI Studio 정책 재확인 + 약관 갱신 필요 여부 검토.
- [ ] SSE on Render — Free 플랜 connection 제한·timeout 검증 (Phase 2 첫 배포 후 부하 테스트).
- [ ] 토큰 비용 추적 컬럼(`aiPromptTokens`/`aiCompletionTokens`) 정확성 — AI SDK가 노출하는 값 검증.

### Phase 4 (RAG) 진입 직전 결정 필요

- [ ] Vector DB: **Supabase pgvector** (이미 사용 중인 Supabase 활용) vs Pinecone vs Qdrant — 권장 pgvector.
- [ ] Embedding 모델: Gemini `text-embedding-004` (provider 일관) vs OpenAI `text-embedding-3-small` (성능·가격).
- [ ] 외부 콘텐츠 라이선싱: CDC Act Early(public domain) ✅ / 보건복지부 가이드(공공저작물) ✅ / AAP(유료 — 제외 검토) / 도서 인용 정책.
- [ ] Ingestion pipeline: 수동 일회성 upload (admin CMS) vs URL 입력 시 자동 fetch+parse+chunk+embed.
- [ ] 청크 크기·overlap: 500 토큰 · 100 overlap 권장 default. 검색 품질 보고 튜닝.

---

## 8. Phase별 작업 todo

> 진행 시 `- [ ]` → `- [x]`로 갱신. PR 머지 시 본 섹션을 진행 추적의 단일 소스로.

### Phase 0 — 기획 확정 (선행) ✅ 완료 (2026-05-25)

- [x] 9항목 결정 (§7 상단)
- [ ] 본 문서 PR 머지 (진행 중)

### Phase 1 — `yougabell-api` 챗 도메인 + UI 영속화 (AI 미연결)

> "AI 챗봇 페이지 컴포넌트만 먼저 만들고" 단계. 현재 chat 페이지는 demo simulation(1.5초). 본 단계에서 DB 영속화 + API endpoint만 추가, LLM 호출 X.

- [ ] Prisma schema: ChatSession + ChatMessage + MessageCard + SourceLink 모델 추가
- [ ] 마이그레이션: `add_chat_models`
- [ ] `chat/` 모듈 (controller + service + DTO)
- [ ] `GET /me/chat` — 세션 + 최근 메시지 (없으면 빈 응답)
- [ ] `POST /me/chat/messages` (1차 — SSE 아님, 일반 POST) — 사용자 메시지 저장 + **고정 mock 응답** 저장 (Phase 2에서 LLM 교체)
- [ ] `DELETE /me/chat`
- [ ] OpenAPI export 갱신
- [ ] **web**: `/chat` 페이지에서 demo simulation 제거 → 새 endpoint 호출 + 응답 수신·표시 + 마운트 시 hydrate

### Phase 2 — Gemini 통합 (챗 실제 AI 응답)

- [ ] `pnpm add ai @ai-sdk/google`
- [ ] `ai/` 모듈: `AiConfigService`, `ContextBuilderService`, prompts
- [ ] 환경 변수 등록 (Render 대시보드 + `.env.example`)
- [ ] `POST /me/chat/messages` SSE 전환 — `streamText` + token stream + 완료 시 structured cards/sources(`generateObject`) 동시 호출
- [ ] **web**: SSE 수신 클라이언트 (`EventSource` or `fetch + ReadableStream`)로 토큰 typing + 완료 시 cards 우르르
- [ ] 분석 이벤트 6종 (`chat_*`) 발행
- [ ] 토큰 사용량 컬럼 채우기 (`ChatMessage.tokensUsed`)

### Phase 3 — 주간 리포트 AI 필드 3개

- [ ] Prisma schema: `WeeklyReport.headlineBody` LLM 채움 (기존 컬럼)·`WeeklyReportBestMoment.body` LLM 채움·`aiActionSuggestion` LLM 채움
- [ ] `WeeklyReport.aiGeneratedAt`/`aiPromptTokens`/`aiCompletionTokens` 신규 컬럼
- [ ] 마이그레이션: `add_weekly_report_ai_fields`
- [ ] `WeeklyReportsService.generateForWeek()` — LLM 호출 통합 (`generateObject` + zod schema)
- [ ] 실패 시 fallback 텍스트 + `aiGeneratedAt=null`
- [ ] 분석 이벤트 2종 (`weekly_report_ai_*`)

### Phase 4 — RAG 도입 (별도 의사결정 후)

- [ ] §7 Phase 4 사전 결정 5항목 마감
- [ ] Supabase pgvector extension 활성화
- [ ] `KnowledgeDocument` / `KnowledgeChunk` / `MessageRetrieval` 모델
- [ ] Ingestion pipeline (스크립트 또는 admin CMS)
- [ ] CDC Act Early + 보건복지부 가이드 초기 시드
- [ ] 챗·리포트 prompt에 retrieved chunks 합성
- [ ] 출처 링크는 retrieved chunk의 sourceUrl 만 인용하도록 system prompt 강제
- [ ] `admin`: 콘텐츠 추가·제거 화면

### Phase 5 — 통합 검증

- [ ] 골든 패스: 챗 첫 메시지 → 영속화 → 새로고침 후 복원
- [ ] 골든 패스: 챗 SSE typing effect + cards 우르르
- [ ] 골든 패스: 주간 리포트 cron → 3 필드 LLM 채움 → 화면 노출
- [ ] 엣지: LLM timeout 시 챗 → 친화적 에러 / 리포트 → fallback 텍스트
- [ ] 엣지: 무료 티어 RPM 초과 시 429 처리
- [ ] 멀티 디바이스: web에서 챗 → mobile WebView 진입 시 동일 세션 복원

---

## 9. 구현 결과 (구현 완료 후 채움)

- 관련 PR: `umbrella#<doc>`, `api#…` (Phase 1·2·3), `web#…` (Phase 1·2)
- 마이그레이션 이름: `add_chat_models`, `add_weekly_report_ai_fields`, (Phase 4) `add_rag_models`
- 스펙 변경점: 챗 모델 4종 신규, 주간 리포트 AI 필드 3개 LLM 채움, `@ai-sdk/google` 의존 추가
- 후속 과제: Phase 4 RAG, Gemini 유료 티어 전환, 사용자 동의 약관, admin 콘텐츠 CMS
