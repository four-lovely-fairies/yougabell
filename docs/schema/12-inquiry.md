# Inquiry — 1:1 문의

> 사용자가 운영자에게 보내는 문의와 그 답변 1건. 기획: [`../features/20260819-inquiry.md`](../features/20260819-inquiry.md).
> 디자인 출처 없음 — 2026-08-19 기준 Figma 미제작. 기존 설정 화면 컴포넌트를 재사용해 구현한다.

---

## Inquiry

> **질문 1 + 답변 1**의 단일 Q&A. 재질문은 새 문의로 접수한다.
> 스레드형 대화가 필요해지면 `InquiryMessage`를 분리하고 기존 행을 첫 두 메시지로 옮긴다.

| 필드           | 타입              | 필수 | 설명                                        | 출처/메모                                               |
| -------------- | ----------------- | :--: | ------------------------------------------- | ------------------------------------------------------- |
| `id`           | `string`          |  \*  | PK                                          | —                                                       |
| `userId`       | `FK → User.id`    |  \*  | 문의 작성자                                 | —                                                       |
| `category`     | `InquiryCategory` |  ?   | 문의 유형. **선택 입력** — 미분류 제출 허용 | 운영자 트리아지 보조용                                  |
| `title`        | `string`          |  \*  | 문의 제목. 1~100자                          | 목록에 노출되는 유일한 본문성 필드                      |
| `body`         | `string`          |  \*  | 문의 내용. 10~2000자 자유 텍스트            | 카테고리로 대체하지 않는다 (features `AGENTS.md` §11)   |
| `contactEmail` | `string`          |  ?   | 답변 받을 이메일                            | 기본값은 로그인 이메일. 사용자가 바꿀 수 있어 별도 보관 |
| `status`       | `InquiryStatus`   |  \*  | 처리 상태. 기본 `received`                  | 클라이언트가 지정 불가 — 서버 고정                      |
| `answerBody`   | `string`          |  ?   | 운영자 답변. 1~4000자                       | `status = answered`일 때만 채워진다                     |
| `answeredAt`   | `DateTime`        |  ?   | 답변 저장 시각                              | 알림 중복 발송 판단 기준                                |
| `answeredBy`   | `string`          |  ?   | 답변한 운영자의 Supabase `auth.users.id`    | `User` FK 아님 — 운영자는 도메인 `User`가 아닐 수 있음  |
| `createdAt`    | `DateTime`        |  \*  | 접수 시각                                   | 목록 정렬 기준                                          |
| `updatedAt`    | `DateTime`        |  \*  | 최종 변경 시각                              | —                                                       |

### `InquiryCategory`

```ts
type InquiryCategory =
  | "service_error" // 오류·장애
  | "account" // 계정·로그인
  | "content" // 콘텐츠·미션·로드맵
  | "suggestion" // 개선 제안
  | "etc"; // 기타
```

> **선택 입력**인 이유: 유형 강제는 사용자 이탈을 만들고 오분류를 낳는다. 본문(`body`)이 자유 텍스트로 남아 있으므로 미분류 문의도 운영자가 읽고 판단할 수 있다.

### `InquiryStatus`

```ts
type InquiryStatus =
  | "received" // 접수됨 — 사용자 제출 직후
  | "in_progress" // 확인 중 — 운영자가 검토 시작
  | "answered"; // 답변 완료 — answerBody 채워짐
```

상태 전이는 **단방향**을 전제로 한다: `received → in_progress → answered`.
`in_progress`를 건너뛰고 `received → answered`도 허용한다 (간단한 문의).

### 파생 값 (저장 X, 계산)

| 필드               | 계산                                  | 사용처                      |
| ------------------ | ------------------------------------- | --------------------------- |
| `isAnswered`       | `status === 'answered'`               | 목록 뱃지, 사용자 알림 여부 |
| `openInquiryCount` | 사용자별 `status !== 'answered'` 건수 | 스팸 가드 (5건 제한)        |
| `waitingDays`      | `now - createdAt` (미답변 건에 한해)  | 어드민 정렬·SLA 모니터링    |

### 관계 (Relations)

- N:1 ← `user: User` _(via `userId`, `onDelete: Cascade`)_
- 알림 연동: 답변 저장 시 `Notification` 1건 생성
  - `type: inquiry_answered` · `targetType: inquiry` · `targetId: inquiry.id`
  - `actionType: url` · `targetUrl: /settings/inquiries/{id}`

### 인덱스

| 인덱스                | 목적                                 |
| --------------------- | ------------------------------------ |
| `[userId, createdAt]` | 내 문의 목록 (최신순)                |
| `[status, createdAt]` | 어드민 목록 — 미답변 우선, 오래된 순 |

**TBD**

- **첨부파일(스크린샷)** — 오류 문의에 결정적이지만 스토리지·용량 제한·악성 파일 검사가 선행돼야 한다. v1 제외
- **탈퇴 사용자 문의 보존** — `User` hard delete(30일 grace 후 cron) 시 `Cascade`로 문의도 삭제된다. 운영 기록 보존이 필요하면 `userId`를 nullable로 바꾸고 익명화하는 전략으로 전환해야 함
- **답변 알림 채널** — 인앱 알림은 확정. 푸시 발송 여부와 `NotificationPreference`에 문의 항목을 둘지는 미정
