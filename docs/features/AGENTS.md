# `docs/features/` 작성 규칙

> 새 기능의 **기획서**를 작성하는 디렉토리. 한 문서 = 한 기능. 사용자 시나리오 → 도메인 → 레포별 작업 → 구현 phase까지 self-contained.
> 상위 룰: [`../AGENTS.md`](../AGENTS.md).

---

## 0. 다루는 것 / 다루지 않는 것

| 다룬다                                   | 다루지 않는다                            |
| ---------------------------------------- | ---------------------------------------- |
| 사용자 시나리오 + 수용 기준              | 인프라 결정 → `docs/design/`             |
| 도메인 모델 영향 (필드·테이블 추가)      | 도메인 엔티티 의미 정의 → `docs/schema/` |
| API 계약 (요청/응답 type, 검증 룰, 에러) | UI 디자인 토큰 → 각 레포 `DESIGN.md`     |
| UI 컴포넌트 인터페이스 (props 시그니처)  | 임시 작업 메모 → `docs/logs/` (별도)     |
| WebView·푸시·네이티브 통합 흐름          |                                          |
| Phase별 구현 todo (체크박스 진행 추적)   |                                          |

---

## 1. 명명·시작

- 파일명: `YYYYMMDD-<feature-slug>.md`
  - YYYYMMDD: **기획 시작일** (오늘 날짜). 구현 일정과 무관
  - slug: kebab-case, 5단어 이내, 영어
  - 예: `20260508-onboarding.md`, `20260601-mission-share.md`
- 작성 시작은 [`_template.md`](./_template.md) 복사 권장 — 모든 필수 섹션 포함

---

## 2. multi-repo 영향 식별 (작성 시작 전 필수)

**기획서 작성 시작 전에 영향 레포를 즉시 식별**한다. 본 워크스페이스의 5개 레포 중 어디가 건드려지는지 정한 뒤 §4 sub-section 구성.

| 영향 신호                                           | 레포                   | §4 sub-section 필요 |
| --------------------------------------------------- | ---------------------- | :-----------------: |
| Prisma 모델·필드 변경, 새 endpoint, Auth/Guard, LLM | `yougabell-api`        |         Yes         |
| 사용자 화면 추가·수정, BFF route, middleware        | `yougabell-web`        |         Yes         |
| 운영자가 봐야 할 데이터, 검수·필터                  | `yougabell-admin`      |       조건부        |
| 푸시·딥링크·카메라·생체 인증·WebView↔native 통신    | `yougabell-mobile`     |       조건부        |
| 본 기획 문서 자체                                   | `yougabell` (umbrella) |     항상(자명)      |

**영향 레포가 2개 이상**이면 §4에 `### 4.1 yougabell-api`, `### 4.2 yougabell-web` 식 sub-section 필수.

---

## 3. 본문 구조 (필수 섹션)

`_template.md`의 9개 섹션을 모두 채운다 (해당 없음은 `—`로):

1. **배경 (Why)** — 왜 만드는가
2. **사용자 시나리오 (What)** — 누가 / 언제 / 흐름 / 수용 기준
3. **도메인 영향** — 엔티티 변경 표 + 신규 테이블 후보 + `docs/schema/` 갱신 안내
4. **레포별 작업 분해** — 영향 레포별 sub-section 포함
5. **UI/디자인 참조** — Figma 노드 ID + 와이어프레임 vs 최종 구분 + 가져올/무시 표
6. **비기능 요구** — 성능·보안·접근성·분석 이벤트 + 저장 전략(local vs server)
7. **리스크·미해결 질문** — 체크박스로 진행 추적
8. **Phase별 작업 todo** — 구현 진행 추적 (자세한 룰 §4)
9. **구현 결과** — 완료 후 PR/migration 이름 등 채움

---

## 4. Phase별 todo 작성 (§8)

본 제품은 anchor(`yougabell-api`) → 클라이언트 순서가 거의 고정. 다음 phase로 분해:

- **Phase 0** — 기획 확정 (디자인·도메인 의문점 해소)
- **Phase 1** — `yougabell-api` (선행, 다른 레포 시작 차단)
- **Phase 2** — `yougabell-web`
- **Phase 3** — `yougabell-mobile` (해당 시)
- **Phase 4** — `yougabell-admin` (해당 시)
- **Phase 5** — 통합 검증 (골든 패스 + 엣지 케이스)

각 항목은 `- [ ]` 체크박스. 완료 시 `- [x]`. **구현 진행 추적의 단일 소스**가 되도록 유지.

---

## 5. API 계약 작성 룰 (§4.1)

api 영향이 있으면 §4.1에 다음을 모두 포함:

- **Prisma schema diff** — 코드 블록(```prisma)으로 추가/변경 부분만
- **마이그레이션 이름** — `pnpm prisma:migrate:dev --name <slug>`
- **endpoint별** — 인증 / Request DTO (TypeScript) / 검증 룰 / 처리 로직 / Response 200 type / 에러 응답 표
- **Auth Guard 분기** — 화이트리스트 경로 + 비통과 시 응답
- **OpenAPI export 갱신 의무**

---

## 6. web 명세 작성 룰 (§4.2)

web 영향이 있으면 §4.2에 다음:

- **라우트 구조** — App Router 트리
- **상태 스키마** — localStorage·context·cookie 등 관리 데이터의 TypeScript type
- **훅 인터페이스** — 시그니처
- **API payload 매핑** — draft → POST body 변환 함수
- **middleware 분기** — 인증·온보딩 등 게이트
- **컴포넌트 인터페이스** — props 시그니처

---

## 7. mobile 명세 작성 룰 (§4.3)

mobile 영향이 있으면 §4.3에 다음:

- **역할 분담 표** — web vs mobile (인증·UI·푸시 등)
- **WebView 컨테이너 설정** — `react-native-webview` props
- **postMessage 프로토콜** — type 별 payload·발생 시점·mobile 처리
- **네이티브 권한 흐름** (푸시·카메라·생체 등)
- **Android back / iOS swipe 처리**

---

## 8. 와이어프레임 vs 최종 디자인

Figma 참조가 와이어프레임이면 §1 또는 §5 헤더에 명시:

> **해당 Figma 노드는 와이어프레임** — 색·간격·폰트는 무시. 기능·구조만 참고.

§5에 **가져올 것 / 무시할 것** 표를 작성.

색상·hex·폰트는 와이어프레임에서 무시. 최종 디자인 또는 `web/DESIGN.md` 토큰을 따른다.

---

## 9. 결정 사항 추적

- §7(리스크·미해결)에 의문점을 `- [ ]`로 작성
- 결정되면 `- [x] ~~원래 질문~~ → **결정 내용 (YYYY-MM-DD)**` 형태로 변환
- 폐기된 옵션은 ~~취소선~~으로 보존 (왜 안 골랐는지 추적)

---

## 10. 저장 전략 명시 (§6)

데이터 저장 결정 시 다음 축을 모두 명시:

- 디바이스 로컬 vs 서버 DB
- 단계별 저장 vs 일괄 atomic POST
- 영속성 등급 (앱 삭제·캐시 클리어 시 손실 수용 여부)
- 멀티 디바이스 이어보기 지원 여부

---

## 11. AI 챗봇 컨텍스트 고려

본 제품의 핵심 가치는 사용자 정보 기반 맞춤 챗봇 답변. 새 입력 필드 설계 시:

- **자유 텍스트 우선** (LLM 사후 추출 가능). 카테고리 강제 분류는 정보 손실
- 자명한 정형(생년월일·enum)은 정형 유지
- 분석 요구가 명확해질 때만 카테고리화 도입

---

## 12. 커밋

- umbrella 레포에서: `docs:` 또는 `docs(scope):`
- 한 기획서 1커밋 (다른 문서와 묶지 않음)
- 큰 갱신은 의미 단위로 분리 커밋
- 메시지 한글, prefix 영어, Claude 협력 문구 X
