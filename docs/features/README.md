# 기능 기획 (Feature planning)

> 새 기능은 본 디렉토리에서 **먼저 기획**하고, 그 후 각 서비스 레포(`yougabell-api`/`web`/`admin`/`mobile`)에서 구현한다.
> umbrella가 **기획·결정의 진실의 소스**, 각 레포는 **구현의 진실의 소스**.

---

## 파일 구조

```
docs/features/
├── README.md                                  # 본 문서
├── _template.md                               # 새 기능 작성 템플릿
└── YYYYMMDD-<feature-slug>.md                 # 개별 기능 기획서
```

- 파일명: `YYYYMMDD-<feature-slug>.md` (예: `20260512-mission-card-share.md`)
- `<feature-slug>`: kebab-case, 5단어 이내

---

## 작성 흐름

1. **기획 (umbrella)** — `docs/features/`에 본 템플릿 기반 문서 작성
   - 사용자 시나리오 / 도메인 영향 / 레포별 작업 분해 / 의존성·순서
2. **검토** — PR로 의견 수렴 (umbrella 레포)
3. **구현 분배** — 기획서의 "레포별 작업" 섹션이 각 레포에서의 작업 단위가 됨
4. **각 레포에서 구현** — 도메인 코드는 `yougabell-api`, UI는 `web`/`admin`, 네이티브는 `mobile`
5. **완료 후 갱신** — 기획서 하단의 "구현 결과" 섹션에 PR 링크와 결정 사항 메모

---

## 도메인·아키텍처 결정과의 차이

| 종류                 | 위치                             | 예                                               |
| -------------------- | -------------------------------- | ------------------------------------------------ |
| 워크스페이스 결정    | umbrella `AGENTS.md` "현재 상태" | 스택, 인증 방식, 호스팅                          |
| 레포 전략            | `docs/design/`                   | 레포 분리 정책, DB 소유권                        |
| 도메인 모델          | `docs/schema/`                   | User, Child, Mission 등 데이터 구조              |
| **기능 기획**        | `docs/features/` (본 디렉토리)   | "마음 배터리 위젯 추가", "주간 리포트 공유 기능" |
| 디자인 토큰·컴포넌트 | 각 레포 `DESIGN.md`              | 컬러·타이포·버튼                                 |
| API 스펙             | `yougabell-api` OpenAPI export   | 자동 생성                                        |

---

## 기능 기획 ↔ 도메인 스키마

새 기능이 **도메인 모델 변경**을 요구하면:

1. 기획서에 영향받는 엔티티 명시
2. `docs/schema/` 갱신 (umbrella, 의미·관계 문서)
3. `yougabell-api/prisma/schema.prisma` 변경 (구현)
4. `pnpm prisma:migrate:dev --name <feature-slug>`

---

## 작성 시작

새 기능을 기획할 때 [`_template.md`](./_template.md)를 복사해서 시작.
