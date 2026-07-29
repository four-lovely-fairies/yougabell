# 약관 동의 저장 (Consent Storage)

> 작성일: 2026-07-29 · 작성자: — · 상태: `in-progress`
> 관련 문서: [`20260508-onboarding.md`](./20260508-onboarding.md) · [`20260519-settings.md`](./20260519-settings.md)
>
> 온보딩에서 **받고는 있지만 아무 데도 저장하지 않던** 약관 동의를 DB에 영속화한다.
> 기존 사용자 필수 동의는 온보딩 완료 시각 기준으로 소급 생성하고, **마케팅 수신동의는 미동의로 확정**한다.

---

## 1. 배경 (Why)

### 현재 상태 — 동의를 받지만 기록이 없다

| 단계               | 상태                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------ |
| 온보딩 UI 체크박스 | **있음** — `consent-bottom-sheet.tsx` (서비스 이용약관 / 개인정보 처리방침 / 마케팅) |
| 체크 결과 저장     | 브라우저 localStorage draft에만 (`mergeOnboardingDraft`)                             |
| 서버 전송          | **안 함** — `CompleteOnboardingDto`에 `consents` 필드 없음                           |
| DB 컬럼            | **없음** — `schema.prisma`에 동의 관련 모델·필드 0건                                 |

온보딩이 끝나면 draft와 함께 사라진다. 기기를 바꾸면 흔적이 0이다.

### 이게 막고 있는 것

- **입증 책임** — 동의는 사업자가 "받았음"을 입증해야 한다. 기록이 없으면 안 받은 것과 같다.
- **약관 개정 시 재동의** — 누가 어느 버전에 동의했는지 몰라서 대상을 못 고른다.
- **설정 화면** — [`20260519-settings.md`](./20260519-settings.md)가 `/me` 응답에 `consent: { service, privacy, marketing }`를 넣기로 해뒀으나 소스가 없어 구현 불가 상태.
- **마케팅 발송** — 동의자 목록을 만들 수 없어 이메일 마케팅이 전면 불가.
- **동의 철회** — 철회 UI를 만들어도 저장할 곳이 없다. 같은 문서의 `ConsentChangeLog` 검토 TODO도 여기서 함께 해소된다.

### 다행인 사실 — 전원이 동의 시트를 거쳤다

온보딩 완료자 **59명 전원이 동의 시트 도입(2026-05-15) 이후**에 온보딩했다 (2026-07-29 기준).

| 시기                           | 인원    |
| ------------------------------ | ------- |
| ~05-14 (동의 시트 이전)        | **0명** |
| 05-15 ~ 07-26 (독립 스텝 시기) | 58명    |
| 07-27 ~ (현재 바텀시트)        | 1명     |

온보딩 플로우가 **필수 2건 충족 전에는 다음 단계로 진행 불가**하도록 강제하고 있었으므로
(`requiredOk = state.service && state.privacy`), 완료자는 전원 필수 2건에 동의한 것이 논리적으로 성립한다.
→ 소급 생성의 근거가 실제로 존재한다.

---

## 2. 결정 사항 (What)

### 2.1 append-only 이력 테이블

`@@unique([userId, type])`로 현재 상태만 들고 있지 **않는다**. 마케팅 동의는 켰다 껐다 할 수 있어야 하고,
"언제 동의했다가 언제 철회했는지"가 분쟁 시의 근거다. 덮어쓰면 그 이력이 사라진다.

- 현재 값 = `type`별 `agreedAt` 최신 row
- 변경 = 새 row INSERT (UPDATE 아님)

### 2.2 소급분은 `source`로 구분해 표시한다

소급 row는 **실제로 캡처한 기록이 아니라 플로우 강제에서 역산한 값**이다.
감사·분쟁 시 이 둘을 구분하지 못하면 곤란해지므로 데이터 자체에 남긴다.

- `source: user_action` — 사용자가 실제로 체크한 것
- `source: backfill` — 온보딩 강제 플로우 기반 소급 생성

`agreedAt`은 **`User.onboardedAt`을 쓴다.** `createdAt`은 계정 생성(로그인) 시점이라 동의 시점과 다를 수 있다.
동의는 온보딩 안에서 일어났으므로 `onboardedAt`이 실제에 더 가깝다.

### 2.3 마케팅은 row를 만들지 않는다

체크박스는 있었지만 값이 서버로 온 적이 없어 **동의/거부를 구분할 방법 자체가 없다.**

`agreed: false` row를 만들면 "거부 의사를 표시했다"는 **잘못된 기록**이 된다.
row가 없는 상태가 "모른다"를 정확히 표현한다.

→ **이메일 마케팅 발송 대상 = 0명** (재동의 전까지)

### 2.4 재동의 경로 = 설정 화면 토글

온보딩은 이미 끝난 사용자들이라 별도 트리거가 필요하다. 앱 내 배너는 전환이 높지만 거슬리고,
현 규모(활동 사용자 40명)에서는 설정 토글로 충분하다.

### 2.5 온보딩 프로필 화면에 로그인 이메일 노출

마케팅 수신동의를 체크시키면서 **어느 주소로 받는지 안 보여주는 것**은 동의의 유효성 측면에서 약하다.
매직링크·소셜 로그인이라 사용자가 "내가 어느 계정으로 들어왔지?"를 확인할 지점도 현재 없다.

- `parent/page.tsx`는 이미 `supabase.auth.getUser()`를 호출 중(Apple 로그인 이름 자동 채움) → **신규 API 호출 0**
- `disabled`가 아니라 **`readOnly`** — `disabled`는 스크린리더가 건너뛰고 복사도 안 된다
- **Apple 비공개 릴레이 주소 주의** — `@privaterelay.appleid.com` 사용자가 실재한다. 날것으로 보여주면 당황하므로 보조 문구를 붙인다

---

## 3. 도메인 모델

```prisma
model UserConsent {
  id       String        @id @default(uuid()) @db.Uuid
  userId   String        @db.Uuid
  type     ConsentType
  agreed   Boolean
  version  String        // 약관 버전 (예: "2026-05-15")
  source   ConsentSource @default(user_action)
  note     String?       // 소급 생성 사유 등
  agreedAt DateTime      @default(now())
  createdAt DateTime     @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, type, agreedAt])
}

enum ConsentType {
  service   // 서비스 이용약관 (필수)
  privacy   // 개인정보 처리방침 (필수)
  marketing // 마케팅 수신동의 (선택)
}

enum ConsentSource {
  user_action // 사용자가 직접 체크
  backfill    // 온보딩 강제 플로우 기반 소급 생성
}
```

> 실무상 `ipAddress`·`userAgent`까지 남기는 곳도 있으나, 개인정보를 더 모으는 트레이드오프가 있어
> **버전 + 시각까지만** 둔다.

### 약관 버전

현재 약관 문서는 Notion에 있고 버전 개념이 없다. 우선 **동의 UI가 배포된 날짜**를 버전 문자열로 쓴다.

현재 버전은 `2026-05-15` 하나뿐이다 — 동의 시트가 최초 배포된 날. 소급분·신규분 모두 이 값을 쓴다.

약관을 개정하면 개정일을 새 버전 문자열로 쓰고, 이전 버전 동의자에게 재동의를 요청한다.
버전 상수는 api 한 곳(`consents/consent.constants.ts`)에서만 관리한다.

---

## 4. API 계약

### 4.1 `POST /onboarding/complete` — `consents` 추가

```jsonc
{
  "parent": { ... },
  "children": [ ... ],
  "consents": {
    "service": true,    // 필수 — false면 400
    "privacy": true,    // 필수 — false면 400
    "marketing": false  // 선택
  }
}
```

- `service`·`privacy`가 `true`가 아니면 **400**. 클라이언트 강제와 이중 방어.
- `marketing`은 `true`일 때만 row 생성. `false`/미지정이면 row 없음(= 미동의).
- 동의 row 생성은 온보딩 트랜잭션 안에서 처리 — 사용자 생성과 원자적으로.

> **하위 호환**: `consents` 미포함 요청도 당분간 허용한다(구버전 앱 WebView 캐시 대응).
> 이 경우 필수 2건을 `source: backfill`로 기록해 "받았는지 모름"과 구분한다.

### 4.2 `GET /me` — `consents` 포함

```jsonc
{
  "id": "...",
  "consents": {
    "service": { "agreed": true, "version": "2026-05-15", "agreedAt": "..." },
    "privacy": { "agreed": true, "version": "2026-05-15", "agreedAt": "..." },
    "marketing": null, // row 없음 = 미동의
  },
}
```

`type`별 최신 row 기준. row가 없으면 `null`.

### 4.3 `PATCH /me/consents/:type` — 재동의·철회

```jsonc
// PATCH /me/consents/marketing
{ "agreed": true }
```

- **`marketing`만 허용.** 필수 2건은 철회 대상이 아니다(철회 = 서비스 이용 불가) → 400
- 항상 새 row INSERT (append-only)
- 응답은 `/me` 전체 (기존 설정 PATCH들과 동일 규약)

---

## 5. 소급 생성 (Backfill)

일회성 스크립트 `yougabell-api/scripts/backfill-consents.ts`.

| 항목       | 값                                                        |
| ---------- | --------------------------------------------------------- |
| 대상       | `onboardedAt != null AND deletedAt IS NULL`               |
| 생성 type  | `service`, `privacy` **2건만** (marketing 제외)           |
| `agreed`   | `true`                                                    |
| `agreedAt` | `User.onboardedAt`                                        |
| `version`  | `2026-05-15`                                              |
| `source`   | `backfill`                                                |
| `note`     | `온보딩 필수동의 강제 플로우 기반 소급 생성 (2026-07-29)` |

**멱등성**: 같은 `(userId, type, source=backfill)` row가 이미 있으면 건너뛴다. 재실행해도 중복이 쌓이지 않는다.

**실행 순서**: `prisma db push`(테이블 생성) → 스크립트 실행 → api 배포.
테이블이 없으면 새 코드가 죽으므로 push가 먼저다.

---

## 6. 작업 분해

| 레포               | 작업                                                                                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `yougabell-api`    | `UserConsent` 모델 + enum 2종 · `db push` · `CompleteOnboardingDto.consents` · 온보딩 트랜잭션 저장 · `getMe` 확장 · `PATCH /me/consents/:type` · backfill 스크립트 |
| `yougabell-web`    | 온보딩 제출 payload에 `consents` · 프로필 화면 로그인 이메일 노출 · 설정 화면 마케팅 수신 토글                                                                      |
| `yougabell-admin`  | (후속) 사용자 상세에 동의 현황 표시                                                                                                                                 |
| `yougabell-mobile` | 변경 없음                                                                                                                                                           |

---

## 7. 체크리스트

- [x] `UserConsent` 모델 + `ConsentType` / `ConsentSource` enum
- [x] `prisma db push` (dev)
- [x] `CompleteOnboardingDto.consents` + 필수 2건 검증
- [x] 온보딩 트랜잭션에서 동의 row 생성
- [x] `GET /me` 응답에 `consents` 포함
- [x] `PATCH /me/consents/:type` (marketing 전용)
- [x] backfill 스크립트 + 실행 (59명 × 2건)
- [x] web — 온보딩 제출 payload에 `consents`
- [x] web — 프로필 화면 로그인 이메일 readOnly 노출
- [x] web — 설정 화면 마케팅 수신 토글
- [ ] admin — 사용자 상세 동의 현황 (후속)
- [ ] 약관 문서에 버전 표기 도입 (Notion → 정적 페이지 이관 검토)

---

## 8. 남는 이슈

- **약관 원문이 Notion에 있다** — `/policy/privacy`·`/policy/terms`가 Notion으로 redirect. 클라이언트 렌더링이라
  본문 확인·버전 관리가 어렵다. 개인정보 처리방침의 "수집 항목"·"이용 목적"에 이메일 발송 근거가 있는지
  **직접 확인 필요**. 근거가 없다면 마케팅 재동의만으로는 부족할 수 있다.
- **마케팅 재동의 전환율** — 설정 토글만으로는 대부분 켜지 않을 가능성이 높다. 이메일 마케팅이 실제로
  필요해지는 시점에 앱 내 1회 배너를 재검토한다.
- **헤비 유저 피드백 수집** — 현재로선 이메일이 불가하므로 푸시 + 앱 내 배너 경로를 쓴다.
  푸시 딥링크는 `actionType: url`을 mobile이 처리하지 않아(`push-notification-routing.ts`) 스토어 재배포가
  필요하다 → `open_home` + 홈 배너 조합으로 우회.
