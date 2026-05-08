# Chat — AI 챗봇

> 사용자의 행동 데이터·기록을 바탕으로 맞춤 답변을 제공하는 "AI Care Engine".
> 응답은 일반 텍스트가 아니라 **여러 카드**로 구성될 수 있고, **출처 링크**가 붙는다.

---

## ChatSession

> 출처: AI Chat Bot (`851:6427`)

| 필드        | 타입           | 필수 | 설명                            |
| ----------- | -------------- | :--: | ------------------------------- |
| `id`        | `string`       |  \*  | PK                              |
| `userId`    | `FK → User.id` |  \*  | —                               |
| `title`     | `string`       |  ?   | 자동 요약 (LLM) — 사이드바 표시 |
| `createdAt` | `DateTime`     |  \*  | —                               |
| `updatedAt` | `DateTime`     |  \*  | 마지막 메시지 시각              |

### 관계 (Relations)

- N:1 ← `user: User` _(via `userId`)_
- 1:N → `messages: ChatMessage[]`

---

## ChatMessage

| 필드          | 타입                       | 필수 | 설명                                                                             | 출처                                         |
| ------------- | -------------------------- | :--: | -------------------------------------------------------------------------------- | -------------------------------------------- |
| `id`          | `string`                   |  \*  | PK                                                                               | —                                            |
| `sessionId`   | `FK → ChatSession.id`      |  \*  | —                                                                                | —                                            |
| `role`        | `enum('user','assistant')` |  \*  | "user" / "AI Care Engine"                                                        | `851:6427`                                   |
| `content`     | `string`                   |  \*  | 본문 (마크다운/플레인)                                                           | `851:6427`                                   |
| `cards`       | `MessageCard[]`            |  ?   | 답변에 포함된 카드 (어시스턴트 메시지에만)                                       | `851:6427` "잠자리 티켓", "정서적 연결 고리" |
| `sourceLinks` | `SourceLink[]`             |  ?   | 출처 URL 목록                                                                    | `851:6427` "출처 링크 : ..."                 |
| `tags`        | `string[]`                 |  ?   | 카테고리/태그 (예: "수면 조언", "Morning Routine", "떼스는 아이 관리 및 교육법") | `851:6427`                                   |
| `sentAt`      | `DateTime`                 |  \*  | 표시 시각, 예: "8:42 PM", "방금전"                                               | `851:6427`                                   |

### 관계 (Relations)

- N:1 ← `session: ChatSession` _(via `sessionId`)_
- 1:N → `cards: MessageCard[]` _(`cards` 컬럼이 임베디드인지 별 테이블인지 TBD — 현 안: 별 테이블)_
- 1:N → `sourceLinks: SourceLink[]`

---

## MessageCard (어시스턴트 응답에 임베드되는 카드)

> 출처: `851:6427` — "잠자리 티켓" / "정서적 연결 고리" 같은 미니 카드

| 필드            | 타입                                                   | 필수 | 설명                          |
| --------------- | ------------------------------------------------------ | :--: | ----------------------------- |
| `id`            | `string`                                               |  \*  | PK                            |
| `messageId`     | `FK → ChatMessage.id`                                  |  \*  | —                             |
| `order`         | `number`                                               |  \*  | 메시지 내 순서                |
| `title`         | `string`                                               |  \*  | 예: "잠자리 티켓"             |
| `body`          | `string`                                               |  \*  | 카드 본문                     |
| `actionType`    | `enum('none','start_mission','open_link','follow_up')` |  ?   | 카드 CTA                      |
| `actionPayload` | `Record<string, unknown>`                              |  ?   | 액션 별 페이로드 (미션 ID 등) |

### 관계 (Relations)

- N:1 ← `message: ChatMessage` _(via `messageId`)_

---

## SourceLink (출처 링크)

> 출처: `851:6427` "www.naver.com/workingmom/youth ..."

| 필드        | 타입                  | 필수 | 설명                               |
| ----------- | --------------------- | :--: | ---------------------------------- |
| `id`        | `string`              |  \*  | PK                                 |
| `messageId` | `FK → ChatMessage.id` |  \*  | —                                  |
| `url`       | `string` (URL)        |  \*  | —                                  |
| `domain`    | `string`              |  \*  | 표시용 (naver.com, youtube.com 등) |
| `title`     | `string`              |  ?   | 메타 스크래핑 결과 (옵셔널)        |

### 관계 (Relations)

- N:1 ← `message: ChatMessage` _(via `messageId`)_

---

## 챗봇 컨텍스트 입력 (DB 컬럼 아님 — LLM 호출 시 합성)

`851:6427` "사용자의 행동 데이터와 패턴을 기반으로 대화합니다." 라는 카피로 보아, 챗 호출 시 다음을 시스템 프롬프트/컨텍스트로 합쳐서 전달한다.

- `User` (양육 유형, 함께 있는 시간)
- `Child[]` (월령, 성별, 특이사항)
- 최근 N개의 `MissionExecution` + `MissionFeedback`
- 최근 N개의 `MentalBatteryCheck`
- 최근 `WeeklyReport` 요약

**TBD**

- 모델 선택: Vercel AI Gateway 통해 라우팅 vs 단일 provider
- 스트리밍 (Server-Sent Events) 사용 여부 — 디자인상 카드 분할 응답이라 스트리밍 + 카드 단위 chunking 필요
- 출처 링크의 신뢰성 검증 (LLM 환각 방지) — RAG 인덱스 보유 여부
- 세션 메모리 정책 (짧은 컨텍스트 vs 장기 메모리)
- 대화 이력 보존 기간
