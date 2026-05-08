# Parenting Style — 양육 유형 진단 (Future)

> **상태: 후속 기능 (Future)**
> 초기 온보딩에서는 받지 않는다. 추후 별도 진단 코스 또는 AI 챗봇이 누적 데이터를 기반으로 자동 추론하는 형태로 도입한다.
> 출처: 온보딩04~08 (`851:6941` ~ `851:7073`), 결과 화면 (`851:7106`, `871:3073`)

---

## 도입 시나리오 (택1, TBD)

| 시나리오              | 설명                                                                      | 장점                               | 단점                             |
| --------------------- | ------------------------------------------------------------------------- | ---------------------------------- | -------------------------------- |
| **명시적 진단 코스**  | 사용자가 마이페이지/홈에서 "양육 유형 진단" 진입, 5문항 응답 후 결과 받기 | 디자인 자산 그대로 사용, 결과 명확 | 사용자가 안 들어오면 데이터 없음 |
| **AI 자동 추론**      | 누적된 미션 피드백·마음 배터리·챗 메시지를 LLM이 분석해 스타일 라벨링     | 사용자 부담 0, 시간이 갈수록 정확  | 콜드 스타트, 결과 설명력 약함    |
| **하이브리드 (권장)** | 가입 N주 후 푸시로 진단 권유 + 챗봇 답변에서 추정 스타일 활용             | 콜드 스타트 → 명시 응답 후 정밀화  | 정책·UI가 가장 복잡              |

---

## 데이터 모델 (도입 시점에 적용)

### `AssessmentQuestion` (정적 마스터 데이터)

| 필드       | 타입                 | 필수 | 설명                                                              |
| ---------- | -------------------- | :--: | ----------------------------------------------------------------- |
| `id`       | `string`             |  \*  | 예: `q1`                                                          |
| `order`    | `number`             |  \*  | 1~5                                                               |
| `question` | `string`             |  \*  | 예: "바쁜 아침 출근 직전, 아이가 떨어지지 않으려 울며 매달릴 때?" |
| `choices`  | `AssessmentChoice[]` |  \*  | 4지선다                                                           |

### `AssessmentChoice`

| 필드          | 타입                                 | 필수 | 설명                             |
| ------------- | ------------------------------------ | :--: | -------------------------------- |
| `id`          | `string`                             |  \*  | 예: `q1-c1`                      |
| `label`       | `string`                             |  \*  | 선택지 텍스트                    |
| `styleWeight` | `Record<ParentingStyleType, number>` |  \*  | 각 스타일에 가중치 (산출 로직용) |

### `ParentingStyleType` (enum)

> 디자인에 명시된 결과는 2종(균형형·권위형)이지만, 5문항 4지선다 구조라 보통 4~5종으로 확장한다.

```ts
type ParentingStyleType =
  | "balanced" // 균형형 (851:7106)
  | "authoritative" // 권위형/든든한 울타리 (871:3073)
  | "permissive" // 허용형 (TBD)
  | "neglectful" // 방임형 (TBD)
  | "authoritarian"; // 독재형 (TBD)
```

### `ParentingStyle` (정적 마스터)

| 필드          | 타입                 | 필수 | 설명                             | 출처       |
| ------------- | -------------------- | :--: | -------------------------------- | ---------- |
| `id`          | `ParentingStyleType` |  \*  | enum                             | —          |
| `emoji`       | `string`             |  \*  | 예: "⚖️"                         | `851:7106` |
| `title`       | `string`             |  \*  | 예: "균형형 부모"                | `851:7106` |
| `subtitle`    | `string`             |  \*  | 예: "균형잡힌 양육자"            | `851:7106` |
| `description` | `string`             |  \*  | 한 단락 설명                     | `851:7106` |
| `traits`      | `string[]`           |  \*  | 주요 특징 (체크리스트), 길이 ≥ 3 | `851:7106` |
| `advice`      | `string`             |  \*  | "💡 조언" 한 단락                | `851:7106` |

### `UserParentingAssessment` (사용자 응답 기록)

| 필드            | 타입                                                 | 필수 | 설명                            |
| --------------- | ---------------------------------------------------- | :--: | ------------------------------- |
| `id`            | `string`                                             |  \*  | PK                              |
| `userId`        | `FK → User.id`                                       |  \*  | —                               |
| `source`        | `enum('explicit_quiz','ai_inferred')`                |  \*  | 명시 진단 / AI 자동 추론        |
| `answers`       | `{ questionId: string; choiceId: string }[]`         |  ?   | `source = explicit_quiz`일 때만 |
| `inferenceMeta` | `{ modelId: string; sourceWindowDays: number; ... }` |  ?   | `source = ai_inferred`일 때만   |
| `resultStyleId` | `FK → ParentingStyle.id`                             |  \*  | 산출 결과                       |
| `assessedAt`    | `DateTime`                                           |  \*  | 검사/추론 일시                  |

---

## 관계 요약 (future)

- `AssessmentQuestion` 1:N → `choices: AssessmentChoice[]`
- `AssessmentChoice` N:1 ← `question: AssessmentQuestion`
- `ParentingStyle` 1:N → `users: User[]` (`User.parentingStyleId` 역참조)
- `ParentingStyle` 1:N → `assessments: UserParentingAssessment[]` (`resultStyleId` 역참조)
- `UserParentingAssessment` N:1 ← `user: User`
- `UserParentingAssessment` N:1 ← `resultStyle: ParentingStyle`

---

## TBD

- 도입 시나리오 확정 (명시 / AI / 하이브리드)
- 재검사 가능 여부 (히스토리 보존? 마지막 1건만?)
- 가중치 산정 알고리즘 (단순 합계 vs 매핑 테이블)
- `permissive`/`neglectful`/`authoritarian` 결과 화면이 디자인에 없음 — 추가 필요
- `User.parentingStyleId`는 진단 전까지 `null`로 유지. 챗봇·미션 추천에서 `null` 처리 정책 필요
