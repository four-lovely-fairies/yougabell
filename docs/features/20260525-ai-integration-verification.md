# AI 통합 v1 — Phase 5 통합 검증 체크리스트

> 작성일: 2026-05-26 · 작성자: — · 상태: `in-progress`
> 본 문서: 기획 [`20260525-ai-integration.md`](./20260525-ai-integration.md) §8 Phase 5 todo 실 사용 검증용.
> spec 자동화는 `yougabell-api` 내 `chat.service.spec.ts` / `knowledge-retrieval.service.spec.ts` / `weekly-reports.service.spec.ts`로 분리 (Phase 5 머지 PR).

---

## 1. 자동화된 검증 (✅ 코드 spec, `pnpm test`)

### `chat.service.spec.ts` (4건)

- [x] `getChat`: 세션 없음 시 빈 응답 반환
- [x] `getChat`: 세션 있음 시 메시지 정렬 (오래된 → 최신)
- [x] `streamMessage` mock fallback: 사용자/어시스턴트 메시지 영속화 + token/done 이벤트 + 카드 포함
- [x] `deleteChat`: 세션 cascade 삭제

### `knowledge-retrieval.service.spec.ts` (7건)

- [x] `retrieve`: embedding disabled → 빈 배열 (pgvector 호출 없음)
- [x] `retrieve`: embedding throws → 빈 배열
- [x] `retrieve`: pgvector throws → 빈 배열
- [x] `retrieve`: 성공 시 매핑된 chunks 반환 (similarity·source·sourceUrl)
- [x] `recordRetrievals`: 빈 배열 시 no-op
- [x] `recordRetrievals`: chunks 다건 시 rank 순으로 createMany
- [x] `recordRetrievals`: DB 실패 시 swallow (best-effort)

### `weekly-reports.service.spec.ts` (30건, 기존)

- [x] AI 비활성(`aiDisabled` stub) 상태에서 모든 spec pass — fallback 텍스트 경로 검증

**총 41/41 tests pass.**

---

## 2. dev 환경 수동 검증 (체크리스트)

> Render API + Supabase dev DB + 사용자 JWT 필요. Phase 4 RAG 시드 ingestion 완료 가정.

### 2.1 챗 골든 패스 (web)

- [ ] `/chat` 페이지 진입 — 빈 상태(마스코트) 노출
- [ ] 메시지 전송 → user bubble + loading dots 즉시 표시
- [ ] 첫 토큰 ≤ 1.5초 도달 → streaming bubble로 morph (점멸 caret)
- [ ] 토큰 누적 → typing effect 자연스러움 (200~600자, 끝까지 ≤ 8초)
- [ ] `done` 수신 → 본문 + 카드 2~3개 한꺼번에 표시
- [ ] 출처 링크 1~3개 표시 (RAG chunks의 sourceUrl)
- [ ] 새로고침 → 이전 대화 복원 (`loadChat()` hydrate)

### 2.2 챗 RAG 검증

질문 예시 (KnowledgeBase 시드와 매칭되는 주제):

- [ ] "아이가 잠들기 전 한 번만 더 라고 해요" → `mohw__aisarang-sleep-routine.md` chunks retrieve, source `childcare.go.kr`
- [ ] "떼쓰기 다루는 방법" → `mohw__aisarang-toddler-tantrum.md` chunks retrieve
- [ ] "4개월 아이 발달이 정상인지" → `cdc__milestones-4mo.md` chunks retrieve, source `cdc.gov`
- [ ] RAG miss 질문(예: "갈비찜 레시피") → sources 빈 배열 + 응답 일반 양육 상식 수준

**DB 검증** (psql):

```sql
SELECT m.role, m.content, COUNT(r.id) AS retrievals
FROM "ChatMessage" m
LEFT JOIN "MessageRetrieval" r ON r."messageId" = m.id
WHERE m."sessionId" = '<session-id>' AND m.role = 'assistant'
GROUP BY m.id, m.role, m.content
ORDER BY m."sentAt" DESC LIMIT 5;
```

- [ ] assistant 메시지마다 retrievals 1~5건 기록 확인
- [ ] `tokensUsed` 컬럼 채워짐

### 2.3 챗 엣지 케이스

- [ ] **LLM 타임아웃**: Gemini API 키 임시 무효화 → mock typing(잠자리 티켓 카드)으로 graceful fallback
- [ ] **빈 메시지 전송**: send 버튼 disabled, 키보드 enter 무시
- [ ] **인증 만료**: localStorage Supabase 세션 삭제 → 에러 배너 + 빈 상태
- [ ] **네트워크 끊김**: fetch 중 wifi off → "스트림이 끊겼어요" 배너

### 2.4 분석 이벤트 (브라우저 devtools)

- [ ] `chat_open`
- [ ] `chat_message_send` (length)
- [ ] `chat_response_first_token` (latencyMs)
- [ ] `chat_response_complete` (latencyMs, cardCount, sourceCount)
- [ ] `chat_quick_reply_use`
- [ ] `chat_response_error` (강제 에러 시)

### 2.5 주간 리포트 AI 필드

trigger:

```bash
curl -X POST 'https://yougabell-api.onrender.com/internal/weekly-reports/generate' \
  -H "X-Cron-Secret: $WEEKLY_REPORT_CRON_SECRET" \
  -H 'Content-Type: application/json' \
  -d '{"weekStart":"2026-05-18","forceRegenerate":true}'
```

- [ ] response `{processed, generated, skipped}` 정상
- [ ] DB 확인:

```sql
SELECT id, headline, "headlineBody", "aiActionSuggestion",
       "aiGeneratedAt", "aiPromptTokens", "aiCompletionTokens"
FROM "WeeklyReport"
ORDER BY "createdAt" DESC LIMIT 1;
```

- [ ] `aiGeneratedAt` 채워짐
- [ ] `headlineBody` LLM 격려 문장 (단정·과장 X)
- [ ] `aiActionSuggestion` 다음 한 주 행동 제안 1단락
- [ ] `WeeklyReportBestMoment.body` LLM 서사 (mission.effect 단순 인용 X)
- [ ] `aiPromptTokens`/`aiCompletionTokens` 정수 값

### 2.6 주간 리포트 엣지

- [ ] **Gemini 키 무효**에서 cron 실행 → row 생성 + `aiGeneratedAt=null` + fallback 텍스트
- [ ] **자녀 0명**: skipped 처리, row 생성 X

### 2.7 멀티 디바이스 / WebView

- [ ] web 데스크톱에서 챗 입력
- [ ] 모바일 (Expo WebView) 진입 → 동일 세션 메시지 복원
- [ ] 모바일에서 메시지 전송 → web 새로고침 시 mobile 메시지 노출

---

## 3. 모니터링 (Phase 5 이후 1주)

- [ ] Gemini 무료 티어 RPM/RPD 한도 도달 알람 채널 설정
- [ ] Render warm-api cron 정상 작동 (15분 idle sleep 회피 — 1시간마다 success)
- [ ] SSE on Render Free 플랜 connection drop 빈도
- [ ] 응답 첫 토큰 latency p95 분포
- [ ] cards 추출 실패율 (logger.warn 카운트)
- [ ] retrieval 0건 비율 (RAG 활용도)

---

## 4. 결과 기록 (검증 완료 후 채움)

- 검증일:
- 검증자:
- 환경:
- 발견 이슈 (issue 링크):
- 추가 작업 항목:
