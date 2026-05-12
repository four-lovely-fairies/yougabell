# Notification — 알림

> 홈 상단 알림 아이콘으로 확인하는 앱 안 알림 기록. Push 발송 추적은 후속 확장으로 분리한다.
> 출처: 홈 `2010:20731` 알림 버튼, 홈 기획 [`../features/20260510-home.md`](../features/20260510-home.md).

---

## Notification

> 사용자가 앱 안에서 확인하는 알림 1건. 초기 범위는 **in-app 알림 목록**이다.

| 필드         | 타입                                                                                     | 필수 | 설명                                                      | 출처/메모                     |
| ------------ | ---------------------------------------------------------------------------------------- | :--: | --------------------------------------------------------- | ----------------------------- |
| `id`         | `string`                                                                                 |  \*  | PK                                                        | —                             |
| `userId`     | `FK → User.id`                                                                           |  \*  | 알림 수신자                                               | —                             |
| `childId`    | `FK → Child.id`                                                                          |  ?   | 특정 자녀 맥락의 알림일 때만. 예: 미션·리포트·로드맵 알림 | 홈은 선택 자녀 기준 노출 가능 |
| `type`       | `NotificationType`                                                                       |  \*  | 알림 종류                                                 | 아래 enum                     |
| `title`      | `string`                                                                                 |  \*  | 목록/푸시에 표시할 제목                                   | —                             |
| `body`       | `string`                                                                                 |  \*  | 한두 줄 본문                                              | —                             |
| `actionType` | `enum('none','open_home','open_mission','open_roadmap','open_chat','open_report','url')` |  \*  | 탭/딥링크 액션                                            | 홈 알림 모달에서 탭 시 처리   |
| `targetType` | `NotificationTargetType`                                                                 |  ?   | 클릭 대상의 도메인 종류                                   | 아래 enum                     |
| `targetId`   | `string`                                                                                 |  ?   | 클릭 대상 id. 예: `missionId`, `executionId`, `reportId`  | JSON 대신 단일 id 사용        |
| `targetUrl`  | `string`                                                                                 |  ?   | 외부 링크 이동이 필요한 경우                              | `actionType = 'url'`          |
| `priority`   | `enum('normal','high')`                                                                  |  \*  | 기본 `normal`. 긴급 안내·실패 알림은 `high`               | 정렬/푸시 발송 정책 입력      |
| `readAt`     | `DateTime`                                                                               |  ?   | 사용자가 읽은 시각. `null`이면 미확인                     | 홈 badge count 산출           |
| `createdAt`  | `DateTime`                                                                               |  \*  | 생성 시각                                                 | 정렬 기준                     |
| `expiresAt`  | `DateTime`                                                                               |  ?   | 지나면 목록에서 숨길 수 있는 시각. 예: 오늘 미션 알림     | 오래된 CTA 방지               |

### `NotificationType`

```ts
type NotificationType =
  | "mission_reminder" // 오늘 미션 시작 유도
  | "mission_feedback" // 수행 후 피드백 요청
  | "weekly_report_ready" // 주간 리포트 생성 완료
  | "roadmap_update" // 새 발달 로드맵/단계 안내
  | "mental_check_reminder" // 마음 배터리 체크 유도
  | "chat_follow_up" // 챗봇 후속 답변/제안
  | "system_notice"; // 서비스 공지, 점검 등
```

### `NotificationTargetType`

```ts
type NotificationTargetType =
  | "mission"
  | "mission_execution"
  | "weekly_report"
  | "child"
  | "chat_session"
  | "url";
```

### 파생 값 (저장 X, 계산)

| 필드         | 계산                                         | 사용처                         |
| ------------ | -------------------------------------------- | ------------------------------ |
| `isUnread`   | `readAt == null`                             | 홈 알림 badge, 목록 bold 처리  |
| `isExpired`  | `expiresAt != null && now > expiresAt`       | 목록 필터, 액션 비활성화       |
| `targetPath` | `actionType + targetType/targetId/targetUrl` | web route 이동, WebView 딥링크 |

### 관계 (Relations)

- N:1 ← `user: User` _(via `userId`)_
- N:1 ← `child?: Child` _(via `childId`)_

### 조회 정책

- 홈 badge count: `userId = me`, `readAt IS NULL`, `expiresAt IS NULL OR expiresAt > now`
- 홈 알림 모달: 최신순(`createdAt DESC`)으로 20건 우선 조회
- `childId`가 있는 알림은 선택 자녀 필터에 종속시키지 않는다. 알림 목록은 사용자 전체 알림을 보여주되, 항목 안에 자녀명을 보조 표시한다.
- `childId`의 자녀가 soft delete 됐어도 알림 기록은 보존한다. 다만 액션은 `open_home` fallback 또는 비활성 처리한다.
- 예약 알림은 별도 `scheduledAt` 필드를 저장하지 않고, scheduler/queue가 노출 시점에 `Notification`을 생성하는 방식으로 시작한다.
- 알림은 무기한 보존한다. 보존 기간 기반 archive/delete 정책은 초기 범위에 넣지 않는다.

### 읽음 처리 정책

- 알림 모달을 열어 목록을 보는 것만으로는 `readAt`을 기록하지 않는다.
- 개별 알림을 클릭하면 해당 알림의 `readAt`을 기록한다.
- "모두 읽음" 액션을 제공하고, 현재 조회 가능한 미확인 알림의 `readAt`을 일괄 기록한다.

### 액션 매핑

`actionType`은 알림 클릭 시 수행할 동작 종류이고, `targetType`/`targetId`/`targetUrl`은 그 동작에 필요한 목적지다.

| 예시 type             | actionType     | targetType          | targetId/targetUrl 예시    | 결과                           |
| --------------------- | -------------- | ------------------- | -------------------------- | ------------------------------ |
| `mission_reminder`    | `open_mission` | `mission`           | `targetId = missionId`     | 오늘 미션 화면으로 이동        |
| `mission_feedback`    | `open_mission` | `mission_execution` | `targetId = executionId`   | 미션 피드백 입력 화면으로 이동 |
| `weekly_report_ready` | `open_report`  | `weekly_report`     | `targetId = reportId`      | 주간 리포트로 이동             |
| `roadmap_update`      | `open_roadmap` | `child`             | `targetId = childId`       | 해당 자녀 로드맵으로 이동      |
| `chat_follow_up`      | `open_chat`    | `chat_session`      | `targetId = chatSessionId` | 챗봇 대화로 이동               |
| `system_notice`       | `none` / `url` | `url`               | `targetUrl = https://...`  | 이동 없음 또는 외부 링크       |

액션이 필요 없는 안내성 알림은 `actionType = 'none'`, `targetType = null`, `targetId = null`, `targetUrl = null`로 둔다.

### 생성 주체

| type                    | 생성 주체             | 예시                               |
| ----------------------- | --------------------- | ---------------------------------- |
| `mission_reminder`      | API scheduler/queue   | "오늘의 10분 미션을 시작해볼까요?" |
| `mission_feedback`      | API domain event      | 미션 종료 후 피드백 미작성 알림    |
| `weekly_report_ready`   | report batch          | "이번 주 리포트가 준비됐어요"      |
| `roadmap_update`        | roadmap/monthly batch | 자녀 월령 변화에 따른 새 단계 안내 |
| `mental_check_reminder` | API scheduler/queue   | 마음 배터리 체크 유도              |
| `chat_follow_up`        | chat module           | 챗봇 답변 후 후속 질문/액션 제안   |
| `system_notice`         | admin/API             | 점검·공지                          |

---

## UserPushToken

> Expo push token 같은 디바이스별 push 수신 토큰. Push 발송을 도입할 때 사용한다. 한 사용자가 여러 기기를 가질 수 있으므로 `User.pushToken` 단일 컬럼보다 별도 테이블을 권장한다.

| 필드         | 타입                                    | 필수 | 설명                                        | 출처/메모                     |
| ------------ | --------------------------------------- | :--: | ------------------------------------------- | ----------------------------- |
| `id`         | `string`                                |  \*  | PK                                          | —                             |
| `userId`     | `FK → User.id`                          |  \*  | 토큰 소유자                                 | —                             |
| `provider`   | `enum('expo')`                          |  \*  | 초기 구현은 Expo만                          | Expo SDK 54                   |
| `token`      | `string`                                |  \*  | Expo push token                             | mobile 온보딩 후 등록         |
| `platform`   | `enum('ios','android','web','unknown')` |  \*  | 디바이스 플랫폼                             | —                             |
| `deviceId`   | `string`                                |  ?   | 앱 설치/기기 식별자. 재설치 시 바뀔 수 있음 | SecureStore/앱 생성 ID 후보   |
| `isActive`   | `boolean`                               |  \*  | 발송 실패·로그아웃 시 false                 | 기본 true                     |
| `lastUsedAt` | `DateTime`                              |  ?   | 마지막 발송 성공 또는 갱신 시각             | 토큰 정리                     |
| `createdAt`  | `DateTime`                              |  \*  | —                                           | —                             |
| `revokedAt`  | `DateTime`                              |  ?   | 로그아웃·권한 해제·토큰 무효화 시각         | `isActive=false` 시 함께 기록 |

### 관계 (Relations)

- N:1 ← `user: User` _(via `userId`)_

### 무결성 규칙

- `token`은 전역 unique 권장
- 같은 `deviceId`에서 새 token이 등록되면 기존 active token을 비활성화
- push 발송 실패가 영구 오류이면 `isActive=false`, `revokedAt=now()`

---

## NotificationDelivery (후속)

> push 발송 성공/실패 이력을 추적해야 할 때 도입한다. 초기 홈 알림 목록에는 필수 아님. `Notification.sentAt` 단일 필드 대신 채널/토큰별 발송 이력을 별도 기록한다.

| 필드                | 타입                                        | 필수 | 설명                   |
| ------------------- | ------------------------------------------- | :--: | ---------------------- |
| `id`                | `string`                                    |  \*  | PK                     |
| `notificationId`    | `FK → Notification.id`                      |  \*  | 어떤 알림을 발송했는지 |
| `pushTokenId`       | `FK → UserPushToken.id`                     |  ?   | push 발송 대상 토큰    |
| `channel`           | `enum('in_app','push')`                     |  \*  | 발송 채널              |
| `status`            | `enum('pending','sent','failed','skipped')` |  \*  | 발송 결과              |
| `providerMessageId` | `string`                                    |  ?   | Expo receipt/ticket id |
| `errorCode`         | `string`                                    |  ?   | 실패 코드              |
| `attemptedAt`       | `DateTime`                                  |  \*  | 발송 시도 시각         |

### 관계 (Relations)

- N:1 ← `notification: Notification`
- N:1 ← `pushToken?: UserPushToken`

---

## 홈 알림 모달 매핑

홈 `GET /home`은 첫 렌더 badge를 위해 최소값만 포함한다.

```ts
type HomeNotificationSummary = {
  unreadCount: number;
  latest: Array<{
    id: string;
    title: string;
    body: string;
    actionType:
      | "none"
      | "open_home"
      | "open_mission"
      | "open_roadmap"
      | "open_chat"
      | "open_report"
      | "url";
    targetType:
      | "mission"
      | "mission_execution"
      | "weekly_report"
      | "child"
      | "chat_session"
      | "url"
      | null;
    targetId: string | null;
    targetUrl: string | null;
    createdAt: string;
    readAt: string | null;
  }>;
};
```

알림 모달을 열 때는 `GET /notifications?limit=20`으로 상세 목록을 조회한다. 목록 항목 탭 시 `actionType`/`targetType`/`targetId`/`targetUrl`로 route를 결정하고, 읽음 처리(`readAt`)를 함께 수행한다.

### API endpoint 계약

| Method  | Path                      | 설명                                     |
| ------- | ------------------------- | ---------------------------------------- |
| `GET`   | `/notifications?limit=20` | 최신 알림 목록 조회                      |
| `PATCH` | `/notifications/:id/read` | 개별 알림 클릭 시 읽음 처리              |
| `PATCH` | `/notifications/read-all` | 현재 사용자의 미확인 알림 모두 읽음 처리 |

---

## TBD

- push 발송을 언제 도입할지. 도입 시 `UserPushToken`, `NotificationDelivery`를 실제 Prisma schema에 반영
- 관리자 공지(`system_notice`) 작성 UI를 `yougabell-admin`에 둘 시점
- 사용자별 알림 수신 설정(미션/리포트/마음 체크별 on/off) 도입 여부
