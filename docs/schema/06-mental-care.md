# Mental Care — 마음 케어

> 부모 본인의 정서를 회복하기 위한 5분 단위 케어 세션. `MentalBatteryCheck` 결과 → 카테고리 추천 → 세션 진행 → 칭찬 피드백.

---

## MentalCareCategory (카테고리 마스터)

> 출처: Mental Health Care Category (`851:5569`, `851:5794`)

| 필드           | 타입     | 필수 | 설명           | 출처       |
| -------------- | -------- | :--: | -------------- | ---------- |
| `id`           | `string` |  \*  | PK (slug)      | —          |
| `emoji`        | `string` |  \*  | 예: "🤏"       | `851:5569` |
| `name`         | `string` |  \*  | 예: "맨손 5분" | `851:5569` |
| `description`  | `string` |  ?   | 카테고리 설명  | TBD        |
| `displayOrder` | `number` |  \*  | 노출 순서      | —          |

### 시드 (디자인에 노출된 4종)

| id                  | emoji | name              |
| ------------------- | :---: | ----------------- |
| `bare-hand-5min`    |  🤏   | 맨손 5분          |
| `refresh-deep-dive` |  ⏳   | 리프레시 딥다이브 |
| `warmth-share`      |  👥   | 온기 나누기       |
| `place-bound`       |  📍   | 장소 한정 미션    |

### 관계 (Relations)

- 1:N → `contents: MentalCareContent[]`
- N:M ↔ `recommendingBatteryChecks: MentalBatteryCheck[]`

---

## MentalCareContent (카테고리 안의 콘텐츠 후보)

> 출처: Mental Health 5 mins Care (`851:6020`)

| 필드              | 타입                         | 필수 | 설명                                       | 출처                 |
| ----------------- | ---------------------------- | :--: | ------------------------------------------ | -------------------- |
| `id`              | `string`                     |  \*  | PK                                         | —                    |
| `categoryId`      | `FK → MentalCareCategory.id` |  \*  | —                                          | —                    |
| `prompt`          | `string`                     |  \*  | 안내 카피, 예: "지금 바로 찬물로 세수하기" | `851:6020`           |
| `durationMinutes` | `number`                     |  \*  | 디폴트 5                                   | `851:6020` "5분동안" |

### 관계 (Relations)

- N:1 ← `category: MentalCareCategory` _(via `categoryId`)_
- 1:N → `executions: MentalCareExecution[]`

---

## MentalCareExecution (수행 인스턴스)

> 출처: Timer (`851:6068`), Timer Resume (`851:6113`), Check Complete (`851:6155`), Praise Feedback (`851:6344`)

| 필드                    | 타입                                                         | 필수 | 설명                     | 출처                                            |
| ----------------------- | ------------------------------------------------------------ | :--: | ------------------------ | ----------------------------------------------- |
| `id`                    | `string`                                                     |  \*  | PK                       | —                                               |
| `userId`                | `FK → User.id`                                               |  \*  | —                        | —                                               |
| `batteryCheckId`        | `FK → MentalBatteryCheck.id`                                 |  ?   | 어떤 체크에서 시작됐는지 | —                                               |
| `contentId`             | `FK → MentalCareContent.id`                                  |  \*  | —                        | —                                               |
| `status`                | `enum('in_progress','paused','completed','early_completed')` |  \*  | —                        | `851:6068` "멈추기", `851:6113` "다시 시작하기" |
| `startedAt`             | `DateTime`                                                   |  \*  | —                        | —                                               |
| `completedAt`           | `DateTime`                                                   |  ?   | —                        | —                                               |
| `actualDurationSeconds` | `number`                                                     |  ?   | —                        | 타이머 `04:44` `851:6068`                       |

### 관계 (Relations)

- N:1 ← `user: User` _(via `userId`)_
- N:1 ← `content: MentalCareContent` _(via `contentId`)_
- N:1 ← `batteryCheck?: MentalBatteryCheck` _(via `batteryCheckId`, optional)_

---

**TBD**

- 카테고리별 콘텐츠 풀 운영 방식 (정적 시드 vs 관리자 CMS)
- 같은 콘텐츠 반복 시 셔플 로직
- 케어 종료 후 "멘탈 개선 Tips 보기"(`851:6344`) 진입 여부 기록 필요 시 별도 컬럼 추가 검토
