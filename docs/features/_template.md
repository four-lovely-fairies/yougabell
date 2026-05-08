# <기능 이름>

> 작성일: YYYY-MM-DD · 작성자: <이름> · 상태: `draft` / `in-review` / `approved` / `in-progress` / `done`
>
> 작성 시작 전 [`AGENTS.md`](./AGENTS.md) 룰 확인 필수 — multi-repo 영향 식별, 필수 섹션, Phase별 todo 룰.

---

## 1. 배경 (Why)

이 기능을 왜 만드는가? 어떤 사용자 문제·비즈니스 요구를 푸는가?

---

## 2. 사용자 시나리오 (What)

- **누가**: (예: 워킹맘, 신생아 부모, 운영자)
- **언제**: 트리거 — 사용자 행동 또는 이벤트
- **흐름**:
  1. …
  2. …
  3. …
- **수용 기준**: 무엇이 만족되면 "구현 완료"인가?

---

## 3. 도메인 영향

새 기능이 영향을 주는 데이터 모델·관계.

| 엔티티           | 변경 종류                | 비고                   |
| ---------------- | ------------------------ | ---------------------- |
| (예: Mission)    | 필드 추가 (`shareCount`) | 기본값 0               |
| (예: ShareEvent) | 신규 테이블              | Mission 1:N ShareEvent |

> 도메인 변경이 있으면 [`../schema/`](../schema/) 도메인 문서도 함께 갱신.

---

## 4. 레포별 작업 분해

> 작성 시작 전 영향 레포 식별 (`AGENTS.md` §2 참조). 영향이 2개 이상이면 sub-section(§4.1, §4.2, ...) 분리.

| 레포               | 작업                                                | 의존성       |
| ------------------ | --------------------------------------------------- | ------------ |
| `yougabell-api`    | Prisma 스키마 갱신 + 마이그레이션 + 엔드포인트 추가 | 선행 (1순위) |
| `yougabell-web`    | UI 컴포넌트, API 호출, 페이지 추가                  | api 완료 후  |
| `yougabell-admin`  | 운영자 검수 화면 (필요 시)                          | api 완료 후  |
| `yougabell-mobile` | 네이티브 푸시·딥링크·WebView 통신 (해당 시)         | api 완료 후  |

### 4.1 yougabell-api (영향 시)

> Prisma schema diff / 마이그레이션 이름 / endpoint별 (Auth, Request DTO, 검증, 처리, Response, 에러) / Auth Guard 분기 / OpenAPI export.

…

### 4.2 yougabell-web (영향 시)

> 라우트 구조 / 상태 스키마 (localStorage·context 등 TS type) / 훅 인터페이스 / API payload 매핑 / middleware 분기 / 컴포넌트 인터페이스.

…

### 4.3 yougabell-mobile (영향 시)

> 역할 분담(web vs mobile) / WebView 컨테이너 설정 / postMessage 프로토콜 / 네이티브 권한 흐름 / Android back 처리.

…

---

## 5. UI/디자인 참조

- Figma 노드: `<file-key>` / `<node-id>`
- 디자인 토큰 변경 필요 여부: 있음/없음 → 있다면 `web/DESIGN.md` 동시 갱신

---

## 6. 비기능 요구

### 저장 전략

> 디바이스 로컬 vs 서버 DB / 단계별 vs 일괄 atomic / 영속성 등급 / 멀티 디바이스 지원 여부.

…

### 그 외

- 성능: (예: 응답 200ms 이하)
- 보안: (예: 운영자만 접근, 마스킹)
- 접근성: (예: aria, 키보드 포커스)
- 분석 이벤트: (이벤트 키 목록)

---

## 7. 리스크·미해결 질문

- [ ] 미해결 질문 1
- [ ] 미해결 질문 2

> 결정되면 `- [x] ~~원래 질문~~ → **결정 내용 (YYYY-MM-DD)**` 형태로 변환.

---

## 8. Phase별 작업 todo

> 진행 시 `- [ ]` → `- [x]`로 갱신. PR 머지 시 본 섹션을 진행 추적의 단일 소스로.

### Phase 0 — 기획 확정 (선행)

- [ ] 디자인 확정 항목
- [ ] 도메인 의문점 해결

### Phase 1 — `yougabell-api` (선행, 다른 레포 시작 차단)

- [ ] Prisma schema 갱신
- [ ] 마이그레이션
- [ ] 엔드포인트 구현
- [ ] Auth Guard 분기
- [ ] OpenAPI export 갱신

### Phase 2 — `yougabell-web` (api 완료 후)

- [ ] 라우트
- [ ] 컴포넌트
- [ ] 상태 관리·훅
- [ ] middleware

### Phase 3 — `yougabell-mobile` (해당 시)

- [ ] WebView·postMessage
- [ ] 네이티브 권한·기능

### Phase 4 — `yougabell-admin` (해당 시)

- [ ] 운영자 화면 노출
- [ ] 마스킹 적용

### Phase 5 — 통합 검증

- [ ] 골든 패스
- [ ] 엣지 케이스

---

## 9. 구현 결과 (구현 완료 후 채움)

- 관련 PR: [`api#…`], [`web#…`], [`admin#…`], [`mobile#…`]
- 마이그레이션 이름: `<feature-slug>`
- 스펙 변경점: …
- 후속 과제: …
