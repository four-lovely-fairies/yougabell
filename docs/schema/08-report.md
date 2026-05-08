# Weekly Report — 주간 리포트

> 한 주 동안의 미션·피드백·마음 배터리를 집계해 만든 회고 리포트.
> 일부 항목은 AI로 생성된다.

---

## WeeklyReport

> 출처: Weekly Report_v02 (`851:6618`, `851:7219`)

| 필드                        | 타입                                 | 필수 | 설명                                           | 출처                                                           |
| --------------------------- | ------------------------------------ | :--: | ---------------------------------------------- | -------------------------------------------------------------- |
| `id`                        | `string`                             |  \*  | PK                                             | —                                                              |
| `userId`                    | `FK → User.id`                       |  \*  | —                                              | —                                                              |
| `childId`                   | `FK → Child.id`                      |  \*  | 자녀 단위. 다자녀면 자녀별 1건                 | `851:6618`                                                     |
| `weekStart`                 | `Date`                               |  \*  | 월요일 기준 (`@unique [childId, weekStart]`)   | —                                                              |
| `weekEnd`                   | `Date`                               |  \*  | 일요일                                         | —                                                              |
| `headline`                  | `string`                             |  \*  | "나는 잘하고 있는가?" 응답                     | `851:6618`                                                     |
| `dailyMissionCompletion`    | `Record<Weekday, boolean \| number>` |  \*  | 요일별 미션 수행 여부/개수                     | `851:6618` "월~일"                                             |
| `totalMissionDuration`      | `{ hours: number; minutes: number }` |  \*  | 누적 수행 시간                                 | `851:6618` "1시간 17분"                                        |
| `childPositiveReactionRate` | `number` (0~1)                       |  \*  | `MissionFeedback.childReaction` ≥ 4 비율       | `851:6618`                                                     |
| `bestMomentTitle`           | `string`                             |  ?   | 베스트 모먼트 제목                             | `851:6618` "Giggling during the 10-minute eye contact mission" |
| `bestMomentBody`            | `string`                             |  ?   | 베스트 모먼트 본문                             | `851:6618`                                                     |
| `topChildKeywords`          | `string[]` (length=3)                |  \*  | 관심 키워드 Top 3 (예: 공룡, 아이스크림, 우주) | `851:6618`                                                     |
| `psychologicalEnergy`       | `number` (0~100)                     |  \*  | 심리적 에너지 %                                | `851:6618` "75%"                                               |
| `improvementTipIds`         | `FK → ImprovementTip.id[]`           |  ?   | 추천 팁                                        | `851:6618`                                                     |
| `aiActionSuggestion`        | `string`                             |  \*  | "미래 행동 제안 (AI 기반)" — 한 단락           | `851:6618`                                                     |
| `generatedAt`               | `DateTime`                           |  \*  | 생성 시각 (배치 또는 주말 트리거)              | —                                                              |

### `Weekday`

```ts
type Weekday = "mon" | "tue" | "wed" | "thu" | "fri" | "sat" | "sun";
```

### 관계 (Relations)

- N:1 ← `user: User` _(via `userId`)_
- N:1 ← `child: Child` _(via `childId`)_
- N:M ↔ `improvementTips: ImprovementTip[]` _(via `improvementTipIds`)_

### 집계 산출 매핑

| 리포트 필드                 | 소스                                          |
| --------------------------- | --------------------------------------------- |
| `dailyMissionCompletion`    | `MissionExecution.completedAt` 요일별 group   |
| `totalMissionDuration`      | `MissionExecution.actualDurationSeconds` 합계 |
| `childPositiveReactionRate` | `MissionFeedback.childReaction`               |
| `topChildKeywords`          | `MissionFeedback.childKeywords` 빈도 Top 3    |
| `psychologicalEnergy`       | `MentalBatteryCheck.level` 평균 → 0~100 변환  |
| `aiActionSuggestion`        | LLM 호출 (위 모든 데이터 + Child 컨텍스트)    |

**TBD**

- 주간 리포트 생성 트리거 (일요일 23시 cron? 월요일 첫 진입?)
- 자녀가 여러 명일 때 통합 리포트 vs 자녀별 리포트 (현 안: 자녀별)
- "베스트 모먼트" 후보 선정 알고리즘 (수동 마킹? AI 자동 선정?)
- 영어 카피 (`Your Morning Rhythm`, `Meditation Pulse` 등)는 디자인 임시 텍스트로 보임 — 한글 카피 확정 필요
