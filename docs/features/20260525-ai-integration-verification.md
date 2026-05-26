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

### 2.1 챗 골든 패스 (자동 검증 완료 2026-05-26)

> 검증 방식: Supabase admin `generate_link` → action_link follow → `Location` 헤더에서 access_token 추출 → production Render API 직접 curl.

- [x] `GET /me/chat` (빈 세션) → `{ session: null, messages: [] }` ✅
- [x] `POST /me/chat/messages/stream` SSE — 11 token + 1 done + 0 error
- [x] done payload: 본문 889자 + cards 2건 + sources 3건
- [x] **새로고침 후 대화 복원** — 재 `GET /me/chat` 호출 시 session.id + user/assistant 메시지 2건 복원 확인
- [ ] 첫 토큰 latency (Render warm 상태 시 1초대 추정 — 브라우저 timing API 측정 항목)
- [ ] 시각 검증 (typing caret·카드 우르르) — 브라우저 필요

### 2.2 챗 RAG 검증 (자동 검증 완료 2026-05-26)

| 질문                                    | retrieve된 chunks (top 5)                                         | sources 노출                                         |
| --------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------- |
| "아이가 잠들기 전 한 번만 더 라고 해요" | 수면 루틴 ×3 + 떼쓰기 + 12개월 마일스톤                           | 수면 루틴·떼쓰기·12개월 (3건) ✅                     |
| "떼쓰기는 어떻게 다루는 게 좋을까요"    | 떼쓰기 + 수면 루틴 + 9개월 마일스톤                               | 떼쓰기·수면 루틴·9개월 (3건) ✅                      |
| "4개월 아이 발달이 정상인지"            | CDC 4개월 + 9개월 + 6개월 (모두 마일스톤)                         | CDC 4·9·6개월 (3건) ✅                               |
| "갈비찜 레시피" (miss)                  | top-5는 강제 가져오지만 LLM이 적합도 판단해 양육 코치 톤으로 우회 | sources 3건 표시 (similarity 임계 필터 v2 검토 필요) |

**DB 검증 (실 row)**:

- [x] `MessageRetrieval` 감사 row 5건 기록 — rank 1~5, similarity 0.65~0.74
- [x] `ChatMessage.tokensUsed` 채움 — assistant 5732 토큰 (streamText 본문 + cards 추출 generateText 합산)
- [x] `MessageCard` 2건 저장 (잠자리 약속·잠자리 티켓)
- [x] `SourceLink` 3건 저장 (childcare.go.kr 2·cdc.gov 1)
- [x] `ChatSession` lazy create — 첫 메시지 시점 자동 생성

### 2.3 챗 엣지 케이스 (브라우저 필요)

- [ ] **LLM 타임아웃**: Gemini API 키 임시 무효화 → mock typing(잠자리 티켓 카드)으로 graceful fallback
- [ ] **빈 메시지 전송**: send 버튼 disabled, 키보드 enter 무시
- [ ] **인증 만료**: localStorage Supabase 세션 삭제 → 에러 배너 + 빈 상태
- [ ] **네트워크 끊김**: fetch 중 wifi off → "스트림이 끊겼어요" 배너

### 2.4 분석 이벤트 (브라우저 devtools 필요)

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

## 4. 결과 기록

### 1차 자동 검증 (2026-05-26)

- **검증일**: 2026-05-26
- **검증자**: 자동 (Supabase admin → magic link → access_token → Render API + DB 검증)
- **환경**: production Render API (`yougabell-api.onrender.com`) + Supabase dev DB + 시드 콘텐츠 6 docs / 14 chunks
- **검증 사용자**: `hitedin@gmail.com` (안성진, 자녀 1명 ㅎㅎㅎ)

### 통과 항목

- ✅ 자동화 spec **41/41** pass (chat 4 + RAG 7 + weekly-report 30)
- ✅ Render API live, 인증 가드 정상 (401)
- ✅ DB 시드: KnowledgeBase 6 docs/14 chunks/768d, Mission 945, Milestone 159
- ✅ 챗 SSE 풀스택: 11 token + done + DB 영속화 (session·message·cards·sources·retrievals·tokensUsed)
- ✅ RAG 정확도: 3개 의도 질문 모두 적합 chunk top 매칭 + sourceUrl 환각 차단
- ✅ 새로고침 후 대화 복원

### 발견 이슈

1. **RAG miss 질문에 sources가 여전히 표시됨** — "갈비찜 레시피" 같이 양육 무관 질문에도 top-5 retrieved chunks의 sourceUrl이 응답에 노출. LLM은 양육으로 우회하지만 sources는 misleading.
   - **개선안 (v2)**: `KnowledgeRetrievalService.retrieve`에서 similarity 임계값(예: 0.55) 미만 chunk 필터링, 또는 LLM이 cards 추출 시 실 인용한 source만 sourceLink로 저장
   - 우선순위: 낮음 (LLM이 부적합 chunk를 무시하긴 함, but 사용자 신뢰도 영향)

### 자동 검증 불가 — 사용자 환경 필요

- 챗 엣지 (LLM 타임아웃·빈 메시지·인증 만료·네트워크 끊김) — 브라우저 + 강제 시나리오
- 분석 이벤트 6종 (chat\_\*) — devtools console
- 첫 토큰 latency 측정 — 브라우저 timing API
- 멀티 디바이스 (web ↔ mobile WebView) — 실 디바이스
- 시각 검증 (typing caret · 카드 우르르 · loading bubble)

### 주간 리포트 검증 — 환경 보강 후 진행

- 로컬 `.env`에 `WEEKLY_REPORT_CRON_SECRET` 빈 값 — Render에 등록된 값 복사 후 .env 갱신 시 자동 검증 가능
- 코드 흐름은 chat과 동일 ai 모듈 사용 — 챗 검증 완료로 LLM 호출 자체는 정합 (실 cron 호출만 별도 검증 필요)

### 추가 작업 항목

- [ ] similarity 임계값 필터 (v2) — `KnowledgeRetrievalService.retrieve`
- [ ] 주간 리포트 cron 실 검증 (사용자가 Render secret 갱신 후)
- [ ] 사용자 환경 검증 항목 (§2.3 / §2.4 / §2.7) — 사용자 진행 후 doc §4에 추가 기록
