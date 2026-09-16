# 홈 부가 요청 통합

> 작성일: 2026-09-10 · 상태: `accepted (PR 검증 완료, merge 전)`
> 관련 문서: [성능 기준선과 개선 실험](./02-performance-baseline.md),
> [홈](../features/20260510-home.md),
> [주간 리포트](../features/20260513-weekly-report.md)

## 0. 결정 요약

| 항목           | 결정                                                                                    | 비고                                                        |
| -------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| 목표           | 홈 문서 진입 후 클라이언트 API 요청을 3건에서 1건으로 축소                              | `/home`, `/me`, `/weekly-reports/unviewed-status` → `/home` |
| 알림 설정      | `/home`에 `playNotificationEnabled`를 추가                                              | 전체 `/me` 응답은 포함하지 않음                             |
| 새 리포트 상태 | `/home`에 `hasUnviewedWeeklyReport`를 추가                                              | 현재 선택 자녀와 직전 완료 주차 기준                        |
| web 공유       | 홈 응답의 부가 상태를 main shell의 client context에 저장                                | HomeDashboard와 BottomNav 간 prop drilling 방지             |
| 최신성         | 홈 최초 진입·같은 세션 내 이동은 `/home` 결과 재사용, 앱 복귀 시 작은 상태 API로 재검증 | 다음 TanStack Query 작업에서 캐시 정책으로 이전 가능        |
| 호환성         | API 필드 추가 → OpenAPI/codegen → web 적용 순서                                         | DB migration 및 mobile 변경 없음                            |
| 기준선         | 0번 계측의 운영 기준선을 확보한 뒤 main에 merge                                         | 개발·PR은 기준선 수집 전에 준비 가능                        |

**결정 (2026-09-10)**: `/home`은 홈 첫 화면을 결정하는 데 필요한 최소 상태를
한 번에 반환한다. 사용자 전체 설정이나 리포트 상세를 합치지 않고, 현재 홈이 실제로
소비하는 두 개의 boolean만 추가한다.

## 1. 컨텍스트

현재 로그인 사용자가 앱을 열어 홈에 도착하면 브라우저에서 다음 요청이 발생한다.

```text
/mobile-entry 문서
  1. GET /auth/session-ready
  2. GET /me                         # 온보딩 완료 여부와 이동 경로 확인

홈 문서
  3. GET /home                       # 홈 본문
  4. GET /me                         # 10분 놀이 알림 활성 여부 확인
  5. GET /weekly-reports/unviewed-status
                                      # 하단 리포트 툴팁 표시 여부 확인
```

이번 작업은 홈 문서의 3~5번을 `/home` 한 건으로 합친다. `/mobile-entry`의 `/me`는
인증·온보딩 라우팅을 결정하므로 범위에서 제외한다. Next main layout의 서버 `/me`
조회도 인증 guard이므로 유지한다.

현재 `/home`은 이미 선택 자녀의 직전 주간 리포트와 홈 알림 요약을 조회한다. 그런데
web은 같은 화면을 그리면서 `/me` 전체 응답에서 알림 설정 한 항목만 찾고, 별도
리포트 상태 API에서 boolean 한 항목만 추가로 받는다. 네트워크 왕복, JWT guard,
사용자 조회 및 JSON 처리가 화면마다 중복된다.

## 2. 목표와 비목표

### 2.1 목표

- 홈 최초 진입에서 클라이언트 API 요청을 `/home` 한 건으로 제한한다.
- 기존 알림 유도 카드와 새 주간 리포트 툴팁의 동작을 보존한다.
- 자녀 전환, 주간 리포트 확인, 앱 background → foreground 복귀에서 잘못된 상태를
  오래 표시하지 않는다.
- `/home` 자체가 무거워져 첫 데이터 표시가 늦어지는 회귀를 계측으로 차단한다.
- API와 web을 독립적으로 되돌릴 수 있게 additive contract로 구현한다.

### 2.2 비목표

- `/mobile-entry` hard reload 또는 인증 흐름 변경
- `/me` endpoint 제거
- `/weekly-reports/unviewed-status` endpoint 제거
- TanStack Query 도입 및 장기 client cache 정책
- 추천 놀이·연속일 계산 최적화
- 알림 설정 UI나 주간 리포트 정책 변경
- mobile native 코드, 앱 버전 또는 스토어 빌드 변경

## 3. API 계약

### 3.1 `GET /home` 응답 추가 필드

기존 `HomeDashboard`에 다음 필드를 추가한다.

```typescript
type HomeDashboard = {
  // 기존 필드 유지
  playNotificationEnabled: boolean;
  hasUnviewedWeeklyReport: boolean;
};
```

두 필드는 nullable로 만들지 않는다. 관련 row가 없으면 다음 기본값을 사용한다.

| 필드                      | `true` 조건                                                            | 기본값  |
| ------------------------- | ---------------------------------------------------------------------- | ------- |
| `playNotificationEnabled` | 현재 사용자의 `play_10min` 알림 preference가 존재하고 `enabled = true` | `false` |
| `hasUnviewedWeeklyReport` | 선택 자녀의 직전 완료 주차 리포트가 존재하고 `viewedAt IS NULL`        | `false` |

`hasUnviewedWeeklyReport`의 날짜·자녀 기준은 기존
`GET /weekly-reports/unviewed-status`와 같아야 한다. `/home?childId=...&date=...`에서
`date`가 주어지면 홈의 `reportSummary`를 구하는 기준 날짜와 동일한 날짜를 사용한다.

### 3.2 API 구현

`HomeService.getHome()`의 병렬 조회에 놀이 알림 preference 최소 조회를 추가한다.

```typescript
prisma.notificationPreference.findUnique({
  where: {
    userId_type: {
      userId,
      type: "play_10min",
    },
  },
  select: { enabled: true },
});
```

주간 리포트 상태 때문에 새 DB 조회를 추가하지 않는다. 현재 `/home`이 이미 조회하는
`latestWeeklyReport.viewedAt`으로 다음 두 값을 함께 만든다.

```typescript
reportSummary: latestWeeklyReport ? toReportSummary(latestWeeklyReport) : null,
hasUnviewedWeeklyReport: Boolean(
  latestWeeklyReport && latestWeeklyReport.viewedAt === null,
),
```

따라서 `/home`의 DB 조회는 알림 preference 1건만 늘고, 전체 사용자·자녀·동의·알림
설정을 읽는 별도 `/me`와 별도 주간 리포트 조회는 사라진다. 새 테이블이나 Prisma
migration은 없다.

### 3.3 OpenAPI

- `HomeDashboardDto`에 두 boolean의 `@ApiProperty()`를 추가한다.
- API 테스트 및 build로 `/openapi.json` 변경을 확인한다.
- `yougabell-web`의 OpenAPI schema와 generated type을 정식 codegen 명령으로 갱신한다.
- generated 파일을 직접 수정하지 않는다.

### 3.4 기존 endpoint 유지

다음 endpoint는 다른 화면 직접 진입과 foreground 재검증에 필요하므로 유지한다.

- `GET /me`
- `GET /weekly-reports/unviewed-status`
- `PATCH /weekly-reports/:id/viewed`

## 4. web 상태와 동작

### 4.1 main shell 공유 상태

HomeDashboard와 BottomNav는 sibling이므로 main shell 범위의 작은 client context를
둔다. 서버 데이터나 사용자 전체 객체를 저장하지 않는다.

```typescript
type MainShellReportState = {
  childId: string | null;
  hasUnviewedWeeklyReport: boolean;
  updatedAt: number;
};

type MainShellReportContextValue = {
  state: MainShellReportState | null;
  replaceFromHome(data: HomeDashboard): void;
  setHasUnviewedWeeklyReport(hasUnviewed: boolean): void;
};
```

비홈 화면 직접 진입 시 아직 localStorage에 선택 자녀가 없으면 `childId = null`로 기본
자녀의 상태를 임시 보관한다. 홈 응답을 받으면 실제 `selectedChild.id`로 즉시 교체한다.

- provider의 수명은 main shell이 유지되는 동안이다.
- localStorage에 새 상태를 영속화하지 않는다.
- `childId`가 현재 선택 자녀와 다르면 저장된 boolean을 사용하지 않는다.
- `updatedAt`은 이번 단계에서 TTL 판단에 사용하지 않고 진단·후속 Query 이전을 위해
  기록한다.

### 4.2 홈 최초 진입

HomeDashboard는 기존 `Promise.allSettled([loadHomeDashboard(), api.getMe()])`를 제거하고
`loadHomeDashboard()`만 호출한다.

응답이 오면 한 번의 state update 흐름에서 다음을 처리한다.

1. 홈 본문 데이터를 저장한다.
2. `showNotificationNudge = !data.playNotificationEnabled`로 설정한다.
3. `replaceFromHome(data)`로 main shell의 리포트 공유 상태를 갱신한다.
4. `screen_first_data`와 `screen_fresh_data`는 기존 `/home` 성공 기준으로 기록한다.

`/home` 실패 시 `/me`를 fallback으로 호출하지 않는다. 기존 HomeError를 표시하고
공유 부가 상태는 이전 값이 있더라도 새 자녀에 적용하지 않는다.

### 4.3 알림 설정 변경

홈 알림 유도 카드를 누를 때 `/me`로 다시 확인하지 않는다. 현재 홈 응답의
`playNotificationEnabled`를 사용해 이미 설정된 안내 또는 설정 화면을 연다.

알림 설정 저장이 성공하면 다음을 함께 반영한다.

- 홈 local state의 `playNotificationEnabled = true`
- 알림 유도 카드 숨김

저장이 실패하면 성공 상태로 선반영하지 않는다.

### 4.4 BottomNav 리포트 툴팁

BottomNav는 다음 우선순위로 상태를 선택한다.

1. context의 `childId`가 현재 선택 자녀와 같으면
   `hasUnviewedWeeklyReport`를 즉시 사용한다.
2. context가 없거나 자녀가 다르면 기존
   `GET /weekly-reports/unviewed-status`를 호출한다.

홈 pathname(`/`)에서는 HomeDashboard가 곧 context를 채우므로 mount 직후 별도 리포트
상태 요청을 보내지 않는다. 응답 전에는 툴팁을 숨긴다. 홈에서 다른 탭으로 이동할 때
main shell이 유지되면 context를 그대로 사용한다.

다음 경우에는 기존 작은 상태 endpoint로 재검증한다.

- 앱/WebView가 background에서 foreground로 복귀
- main shell은 열려 있지만 context가 없는 비홈 화면 직접 진입
- localStorage의 선택 자녀와 context의 `childId`가 불일치

동일 시점의 `focus`와 `visibilitychange`가 겹쳐도 한 요청만 보내도록 in-flight dedupe를
적용한다.

### 4.5 리포트 확인과 자녀 전환

- `PATCH /weekly-reports/:id/viewed` 성공 시 context의
  `hasUnviewedWeeklyReport`를 즉시 `false`로 바꾼다.
- 자녀를 전환하면 새 `GET /home?childId=...` 응답으로 context 전체를 교체한다.
- 자녀 전환 요청 중에는 이전 자녀의 리포트 상태를 새 자녀에 표시하지 않는다.
- 리포트 확인 또는 알림 설정 변경 실패 시 기존 값을 성공 상태로 바꾸지 않는다.

## 5. 레포별 작업 분해

| 레포               | 작업                                                               | 배포 순서        |
| ------------------ | ------------------------------------------------------------------ | ---------------- |
| `yougabell-api`    | `/home` 필드·최소 조회·테스트·OpenAPI 갱신                         | 1                |
| `yougabell-web`    | codegen, 홈 `/me` 제거, context, BottomNav fallback·dedupe, 테스트 | 2                |
| `yougabell-mobile` | 코드 변경 없음. 기존 앱 WebView 회귀 QA만 수행                     | 스토어 빌드 없음 |
| `yougabell-admin`  | 영향 없음                                                          | —                |
| `yougabell`        | 본 결정 문서와 구현 결과 기록                                      | PR 준비 단계     |

API를 먼저 배포한다. 필드 추가는 additive이므로 구 web은 새 필드를 무시한다. 새 web은
필드를 필수 boolean으로 사용하므로 API 배포가 확인된 후 배포한다.

## 6. 성능 측정과 완료 조건

### 6.1 비교 조건

0번 계측이 포함된 스토어 버전에서 기준선을 먼저 수집한다. 그 뒤 API/web 개선 버전을
같은 플랫폼, 사용자 상태, 자녀, 네트워크 조건으로 비교한다. mobile binary가 같아도
web/API release를 반드시 구분한다.

### 6.2 주 지표

| 지표                                   | 변경 전                            | 완료 조건                                                     |
| -------------------------------------- | ---------------------------------- | ------------------------------------------------------------- |
| 홈 문서의 client `api_headers` 요청 수 | `/home`, `/me`, 리포트 상태 총 3건 | 정상 최초 진입에서 `/home` 1건                                |
| 앱 전체 시작 client API 요청 수        | session 2건 + 홈 3건 = 5건         | session 2건 + 홈 1건 = 3건                                    |
| `screen_first_data` P50/P75/P95        | 운영 기준선                        | P75가 악화되지 않고 유의미한 개선 확인                        |
| `native_home_ready` P50/P75/P95        | 운영 기준선                        | P75가 악화되지 않음                                           |
| `/home` `api_headers.duration_ms`      | 운영 기준선                        | 추가 DB 조회 후에도 P75/P95 유의미한 악화 없음                |
| `/home` API `db_count`, `db_ms`        | 운영 기준선                        | 전체 시작 journey 합계 감소, `/home` 단독 회귀 허용 범위 기록 |
| 오류율                                 | 운영 기준선                        | `/home`, 인증, 리포트 상태 오류율 증가 없음                   |

표본이 적으면 동일 실기기에서 cold start 20회와 warm navigation 20회를 전후 동일하게
수행한다. 운영 판단은 가능한 한 화면별 100건 이상에서 P75를 비교한다.

### 6.3 기능 완료 조건

- 홈 알림 유도 카드가 알림 설정 여부에 맞게 표시된다.
- 알림 설정 성공 직후 새 `/me` 없이 카드가 사라진다.
- 미확인 주간 리포트가 있을 때만 BottomNav 툴팁이 표시된다.
- 리포트를 확인하고 돌아오면 툴팁이 즉시 사라진다.
- 자녀 전환 후 다른 자녀의 리포트 상태가 섞이지 않는다.
- 앱 복귀 시 새로 생성되거나 확인된 리포트 상태가 갱신된다.
- 홈 최초 진입에서 `/me`와 `/weekly-reports/unviewed-status`가 발생하지 않는다.
- `/mobile-entry`의 `/me`와 main layout 인증 guard는 정상 동작한다.

## 7. 테스트 계획

### 7.1 API unit test

- `play_10min` preference가 enabled/disabled/미존재인 경우
- 직전 주차 리포트가 미확인/확인됨/미존재인 경우
- 요청한 자녀가 사용자 소유가 아닌 경우
- `date` query를 사용했을 때 `reportSummary`와 미확인 상태의 기준 주차 일치
- 기존 HomeDashboard 필드 회귀 없음
- 추가 조회가 기존 병렬 실행을 직렬화하지 않음

### 7.2 web test

- 홈 mount에서 `loadHomeDashboard`만 한 번 호출
- 홈 응답으로 알림 유도 카드와 리포트 툴팁 결정
- 홈에서 BottomNav가 별도 리포트 상태를 호출하지 않음
- context 없는 비홈 직접 진입에서 상태 endpoint fallback
- 자녀 전환 중 이전 자녀 상태 숨김 및 응답 후 교체
- 리포트 viewed 성공 후 tooltip 제거
- foreground에서 상태 재검증
- 동시 `focus`/`visibilitychange` 한 건으로 dedupe
- `/home` 실패 시 성공 상태 오표시 없음

### 7.3 실기기 QA

Android와 iOS에서 각각 다음을 확인한다.

1. 앱 종료 후 실행 → 홈 데이터·알림 유도·리포트 툴팁 확인
2. 홈 → 놀이 → 홈 → 로드맵 → 홈
3. 자녀 전환 → 홈 카드와 리포트 툴팁 변경 확인
4. 미확인 리포트 진입 → 뒤로 가기 → 툴팁 제거 확인
5. 앱 background → 새 리포트 생성/확인 → foreground 복귀 상태 갱신
6. Network와 Amplitude에서 홈 최초 진입 요청이 `/home` 한 건인지 확인

mobile native 변경이 없으므로 이 작업만으로 EAS Build나 스토어 재심사는 필요하지
않다. web/API 배포만 필요하다.

## 8. 리스크와 롤백

| 리스크                             | 방어                                                                     |
| ---------------------------------- | ------------------------------------------------------------------------ |
| `/home` 조회 증가로 단일 응답 지연 | preference 최소 select, 기존 쿼리와 병렬 실행, 전후 `/home` P75/P95 비교 |
| BottomNav 상태 stale               | foreground 재검증, 리포트 viewed 성공 시 즉시 context 갱신               |
| 다자녀 상태 혼합                   | 모든 context 값에 `childId` 동반, 불일치 값 사용 금지                    |
| API/web 배포 순서 불일치           | additive API 선배포 후 web 배포                                          |
| API 실패 시 잘못된 알림 UI         | 성공 응답 전에는 숨김, 실패를 false 성공으로 저장하지 않음               |

DB migration은 없으므로 롤백은 web을 먼저 이전 release로 되돌리고 API를 나중에
되돌린다. 구 web은 추가 API 필드를 무시하므로 API만 한동안 유지해도 안전하다.

## 9. 구현 체크리스트

### Phase 0 — 기준선·계약

- [ ] 0번 계측 포함 앱의 스토어 배포 완료
- [ ] 변경 전 홈 최초 진입 요청 수와 성능 기준선 기록
- [x] API response 필드명과 기본값을 OpenAPI 계약으로 확정

### Phase 1 — `yougabell-api`

- [x] `HomeDashboard` type과 DTO에 두 boolean 추가
- [x] 놀이 알림 preference 최소 조회를 병렬 query에 추가
- [x] 기존 주간 리포트 조회에서 미확인 상태 파생
- [x] HomeService unit test 추가
- [x] build 및 OpenAPI export 검증

### Phase 2 — `yougabell-web`

- [x] OpenAPI schema/codegen 갱신
- [x] HomeDashboard 초기 `/me` 제거
- [x] main shell report context 추가
- [x] 알림 유도 open/save 흐름을 홈 응답 기준으로 변경
- [x] BottomNav context 우선·fallback·foreground dedupe 구현
- [x] 리포트 viewed 및 자녀 전환 시 context 갱신
- [x] unit test, typecheck, production build 검증

### Phase 3 — 통합 검증

- [ ] API 선배포 후 web 배포
- [ ] Android/iOS 실기기 QA
- [ ] 기능 완료 조건 확인
- [ ] 변경 후 성능 표본 수집 및 기준선 비교
- [ ] 유지 또는 web/API 순서로 rollback 결정

## 10. 구현 결과

2026-09-16 구현과 로컬 검증을 완료했고, main merge와 배포는 보류했다.

- API PR: [yougabell-api#76](https://github.com/four-lovely-fairies/yougabell-api/pull/76)
- web PR: [yougabell-web#151](https://github.com/four-lovely-fairies/yougabell-web/pull/151)
- API HomeService 단위 테스트 8건, web 단위 테스트 75건, 양쪽 production build 통과
- 홈 전체 reload와 로드맵 → 홈 10회에서 client API가 매번 `/home` 1건만 발생함을 확인
- `/home`의 driver `db_count`는 22 → 23으로 1회 증가했지만 제거된 client `/me` 4회와
  리포트 상태 2회를 합치면 홈 client journey는 28 → 23으로 5회 감소
- 구현 후 로컬 `screen_first_data` 10회는 P50 985 ms, P75 1,096 ms. 변경 전 탐색
  표본보다 느렸지만 원격 DB 편차가 크고 동시 교차 측정이 아니므로 회귀로 판정하지 않음

남은 작업은 API 선배포, web 후배포, Android/iOS 실기기 QA와 운영 표본 비교다. 운영
P75가 악화되면 §8의 순서로 rollback한다.
