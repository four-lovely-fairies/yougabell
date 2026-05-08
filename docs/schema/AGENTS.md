# `docs/schema/` 작성 규칙

> 도메인 엔티티의 **사람이 읽는 의미 문서**. Prisma schema가 코드 진실, 본 디렉토리는 의미 진실.
> 상위 룰: [`../AGENTS.md`](../AGENTS.md).

---

## 0. 다루는 것 / 다루지 않는 것

| 다룬다                                   | 다루지 않는다                                     |
| ---------------------------------------- | ------------------------------------------------- |
| 엔티티 의미·관계·필드의 인간 친화적 설명 | DDL·인덱스·마이그레이션 — `yougabell-api/prisma/` |
| Figma 노드와 필드 매핑 (출처 추적)       | 새 기능 기획 → `docs/features/`                   |
| 파생 값(저장 X, 계산) 정의               | UI 컴포넌트 명세 → 각 레포                        |
| TBD·미해결 의문 (필드 구조·정책)         | 인프라 결정 → `docs/design/`                      |

---

## 1. 명명·구조

- 파일명: `NN-<entity>.md` (또는 `NN-<domain>.md` for collection like `09-content.md`)
- 일련번호는 **도메인 의존도** 순서: 0=overview, 1=User, 2=Child, … 의존성 그래프 위에서 아래로
- entity는 단수형, kebab-case (`mental-battery`, `parenting-style` 등)

## 2. 본문 구조 (필수 섹션)

```markdown
# <Entity> — 한 줄 설명

> 한 줄 요약. 출처 Figma 노드 ID(있으면).

---

## <Entity>

> 출처: Figma 노드 + 화면명

| 필드        | 타입      | 필수 | 설명 | 출처/메모 |
| ----------- | --------- | :--: | ---- | --------- |
| `id`        | UUID      |  \*  | PK   | —         |
| `userId`    | FK → User |  \*  | …    | —         |
| `createdAt` | DateTime  |  \*  | —    | —         |

### 파생 값 (저장 X, 계산)

| 필드 | 계산 | 사용처 |

### 관계 (Relations)

- N:1 ← `user: User` _(via `userId`)_
- 1:N → `…`

**TBD**

- 미해결 질문 1
- 미해결 질문 2
```

## 3. Prisma schema와의 관계

- **Prisma schema가 코드 진실의 소스**. 본 docs는 의미·의도 layer.
- 필드 추가/변경 시:
  1. `docs/features/` 기획서에서 의도 정의 (해당하면)
  2. `docs/schema/<entity>.md`에 의미 갱신
  3. `yougabell-api/prisma/schema.prisma` 갱신 + `pnpm prisma:migrate:dev --name <slug>`
- 본 docs와 Prisma 사이 차이가 발견되면 **Prisma가 우선** (코드가 진실), docs는 즉시 동기화

## 4. Figma 노드 ID 인용

- 출처 명시는 노드 ID + 화면 라벨로 (`851:6805` "온보딩02")
- 디자인 변경으로 노드 ID가 바뀌면 갱신. 옛 ID는 ~~취소선~~으로 보존 가능
- 와이어프레임이면 명시 (다른 docs 룰 동일)

## 5. enum·정형 vs 자유 텍스트

본 제품은 AI 챗봇 컨텍스트로 데이터를 소비:

- **자유 텍스트** 권장 (LLM 사후 추출 가능). 카테고리 강제 분류는 정보 손실
- 자명한 정형(생년월일·성별·요일·시간대 등)은 정형 유지
- 새 필드 도입 시 위 트레이드오프를 본 문서에 명시

## 6. multi-repo 영향

도메인 변경은 anchor(`yougabell-api`) 우선이지만 영향:

- `api`: Prisma + 마이그레이션 + 엔드포인트 (필드 노출)
- `web/admin/mobile`: codegen 재실행 후 사용 코드 갱신
- `docs/features/`: 변경 동기 기획서가 있다면 그쪽 §8 Phase별 todo와 동기화

큰 변경은 `docs/features/`에 마이그레이션 기획서를 별도로 작성 권장.

---

## 7. 명명 컨벤션 빠른 표

| 용도              | 형식                                                         |
| ----------------- | ------------------------------------------------------------ |
| 엔티티명 (모델명) | PascalCase 단수 (`User`, `Child`)                            |
| 필드명            | camelCase (`birthDate`, `userId`)                            |
| enum 값           | UPPER_SNAKE (`WORKING`, `ALL_DAY`)                           |
| 외래키            | `<entity>Id` (`userId`, `missionId`)                         |
| Boolean 의미 필드 | `is*` / `has*` 또는 시각 nullable (`onboardedAt: DateTime?`) |

> Boolean 대신 nullable DateTime이 의미 보존상 우월한 경우(완료 시각 등) 후자 권장.
