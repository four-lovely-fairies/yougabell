# TanStack Query 클라이언트 캐시 도입

> 작성일: 2026-09-18 · 상태: `proposed (구현 전 검토)`
> 관련 문서: [성능 기준선과 개선 실험](./02-performance-baseline.md),
> [홈](../features/20260510-home.md),
> [주간 리포트](../features/20260513-weekly-report.md),
> [설정](../features/20260519-settings.md)

## 0. 결정 요약

| 항목              | 결정                                                                                             | 이유                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| 목표              | 같은 앱 실행 중 홈·사용자 정보·리포트를 재방문할 때 캐시를 즉시 표시하고 중복 요청을 공유한다    | 탭 왕복 때마다 스켈레톤과 동일 API 대기를 반복하지 않기 위해               |
| 범위              | web에 `@tanstack/react-query` v5 도입, 홈·리포트 상태·주간 리포트·클라이언트 `/me` 조회부터 이전 | 초기 효과가 크고 갱신 조건을 명확히 정의할 수 있는 서버 상태               |
| 캐시 위치         | 메모리의 단일 `QueryClient`                                                                      | 앱 종료 후 오래된 데이터를 영속화하지 않음                                 |
| provider 수명     | Next root layout 아래에서 유지                                                                   | 홈에서 놀이·설정으로 갔다 돌아와도 같은 캐시 사용                          |
| 홈 신선도         | `staleTime = 30초`, `gcTime = 10분`                                                              | 짧은 탭 왕복은 요청 없이, 그 이후에는 캐시를 먼저 표시하고 백그라운드 갱신 |
| `/me`·주간 리포트 | `staleTime = 5분`, `gcTime = 30분`                                                               | 변경 빈도가 낮고 응답 재사용 가치가 큼                                     |
| 리포트 상태       | `staleTime = 30초`, `gcTime = 10분`                                                              | 툴팁 최신성과 중복 요청 감소의 균형                                        |
| 날짜 경계         | 홈·오늘 기준 query key에 한국 날짜(`YYYY-MM-DD`) 포함                                            | 23:59에 받은 캐시를 다음 날 데이터로 재사용하지 않음                       |
| 앱 복귀           | stale query만 background refetch, 날짜가 바뀌었으면 새 key로 조회                                | 화면을 비우지 않고 최신 상태 확인                                          |
| 수동 새로고침     | stale 여부와 무관하게 현재 query를 즉시 refetch                                                  | 사용자 의도를 최우선으로 반영                                              |
| 쓰기 이후         | 성공한 mutation별로 `setQueryData` 또는 좁은 범위 `invalidateQueries` 실행                       | 오래된 홈·리포트·사용자 상태 방지                                          |
| SSR 인증          | Next 서버의 `fetchServerMe()`는 이번 Query 캐시로 대체하지 않음                                  | 브라우저 캐시와 서버 인증 guard는 수명·신뢰 경계가 다름                    |
| 영속 캐시         | localStorage/AsyncStorage persister를 도입하지 않음                                              | 초기 단계에서 개인정보·버전 호환·장기 stale 문제를 만들지 않음             |

**제안 (2026-09-18)**: 캐시가 있으면 먼저 화면에 표시하고, stale이면 뒤에서 최신 데이터를
받는다. 따라서 `staleTime`은 “데이터를 숨기거나 폐기하는 시간”이 아니라 “재조회 없이
신선하다고 믿는 시간”이다. `gcTime`은 사용 중인 화면에는 적용되지 않으며, 해당 query를
사용하는 화면이 사라진 뒤 메모리에서 제거하기까지의 시간이다.

## 1. 컨텍스트와 문제

현재 client component들은 `useEffect`에서 직접 API를 호출하고 결과를 각 화면의 local
state에 저장한다. 화면이 unmount되면 데이터가 사라지므로 같은 세션에서 탭을 왕복해도
다시 스켈레톤을 보여주고 같은 요청을 보낸다.

대표 흐름은 다음과 같다.

```text
홈 진입       GET /home              → local state
놀이 이동     홈 component unmount   → 홈 데이터 소멸
홈 재방문     GET /home              → 다시 스켈레톤과 대기

설정 진입     GET /me
프로필 이동   GET /me
자녀 설정     GET /me                → 같은 사용자 응답 반복

비홈 진입     GET /weekly-reports/unviewed-status
화면 focus    같은 상태 API 재호출 가능
리포트 진입   GET /weekly-reports/current
재방문        같은 리포트 재조회
```

직접 구현한 `MainShellReportContext`와 in-flight dedupe는 홈과 BottomNav 사이의 한 가지
상태만 공유한다. 화면 데이터 캐시, stale 판단, 요청 공유, 재시도, mutation 이후 갱신을
각 기능이 계속 직접 구현해야 한다. TanStack Query를 서버 상태의 공통 계층으로 두고,
UI 전용 상태(열린 modal, 입력값, 타이머 등)는 기존 React state에 남긴다.

## 2. 목표와 비목표

### 2.1 목표

- 같은 앱 실행 중 재방문하면 캐시된 데이터를 즉시 표시한다.
- 같은 query key의 동시 요청은 하나의 Promise를 공유한다.
- 자녀·날짜·리포트가 다른 데이터를 같은 캐시 항목에 섞지 않는다.
- 데이터 변경 성공 후 영향받는 캐시를 명시적으로 갱신한다.
- 앱 복귀, 한국 자정, 당겨서 새로고침에서도 최신 데이터를 받을 수 있다.
- 캐시 화면 표시와 최신 API 반영 시간을 기존 성능 이벤트에서 구분한다.
- 변경 전후 재방문 표시 시간, fresh 반영 시간, 요청 수를 같은 로컬 조건에서 비교한다.
- Query 계층을 제거하는 한 PR revert로 원복할 수 있게 DB/API 계약 변경 없이 구현한다.

### 2.2 비목표

- Next 서버 component의 인증 guard 캐시 변경
- `/mobile-entry` 세션 동기화 또는 hard reload 개선
- React local UI state 전체를 Query로 이전
- 앱 종료 후에도 남는 영속 캐시
- Service Worker/HTTP CDN 캐시 정책 변경
- 추천 놀이·연속일 계산 자체의 서버 최적화
- 모든 API를 한 번에 Query로 이전
- 이번 작업만으로 운영 리텐션 개선을 입증

## 3. QueryClient와 기본 정책

### 3.1 단일 provider

`QueryClientProvider`는 web root layout의 client provider 안에 한 번만 둔다. route별 layout
안에 두면 홈→놀이 또는 홈→설정 이동에서 provider가 교체되어 캐시가 사라질 수 있으므로
금지한다. render마다 새 client를 만들지 않고 provider 인스턴스 수명 동안 하나만 만든다.

기본값은 다음과 같다.

```typescript
new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      gcTime: 600_000,
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
      retry: (failureCount, error) =>
        isRetryableServerOrNetworkError(error) && failureCount < 1,
    },
    mutations: { retry: false },
  },
});
```

화면별 정책이 다르면 query 정의에서 override한다. 401/403과 사용자가 고칠 수 없는 4xx는
retry하지 않는다. 네트워크 오류와 5xx만 최대 한 번 재시도한다. mutation은 자동 retry하지
않는다. `ApiError`의 status를 검사하는 retry 판정 함수는 별도 pure function으로 두고 unit
test한다.

TanStack Query v5의 브라우저 focus 판단만 WebView 앱 복귀를 모두 포착한다고 가정하지
않는다. 공통 provider에서 `focusManager.setEventListener`로 `visibilitychange`와
`window.focus`를 연결하고, `document.visibilityState === "visible"`일 때만 focused로
알린다. 두 이벤트가 연달아 발생해도 Query가 같은 key의 in-flight 요청을 공유하는지
테스트한다. mobile native AppState 메시지를 새로 추가하는 것은 이번 범위가 아니며, 실제
iOS/Android WebView QA에서 두 웹 이벤트가 모두 누락되면 후속 mobile 작업으로 분리한다.

### 3.2 캐시 표시와 background 갱신

캐시가 있는 query가 stale인 경우에도 화면은 캐시를 즉시 사용한다. `isPending`은 표시할
데이터가 전혀 없는 최초 로딩에만 스켈레톤을 제어한다. `isFetching`은 background refetch를
포함하므로 전체 화면 스켈레톤 조건으로 사용하지 않는다.

| 상태                     | 화면                         | 계측                               |
| ------------------------ | ---------------------------- | ---------------------------------- |
| 캐시 없음 + 요청 중      | 기존 스켈레톤                | 아직 first data 없음               |
| 캐시 있음 + fresh        | 캐시 즉시 표시, 요청 없음    | `screen_first_data source=cache`   |
| 캐시 있음 + stale        | 캐시 즉시 표시, 뒤에서 요청  | first=`cache`, 성공 후 fresh=`api` |
| 캐시 있음 + refetch 실패 | 캐시 유지 + 비차단 오류 처리 | fresh 성공으로 기록하지 않음       |
| 캐시 없음 + 요청 실패    | 기존 전체 오류 UI            | `screen_outcome=error`             |

background refetch 때문에 카드 전체를 로딩 상태로 되돌리거나 스크롤 위치를 초기화하지
않는다. 당겨서 새로고침은 기존 헤더 아래 spinner를 사용한다.

## 4. Query key 계약

query key는 중앙 factory에서만 만든다. 문자열을 화면마다 직접 조합하지 않는다.

```typescript
queryKeys.home({ childId, date: koreaDate });
queryKeys.me();
queryKeys.weeklyReportStatus({ childId, date: koreaDate });
queryKeys.weeklyReportCurrent({ childId, date: koreaDate });
queryKeys.weeklyReportDetail({ reportId });
```

### 4.1 자녀

- 명시된 자녀는 실제 `childId`를 key에 넣는다.
- 저장된 자녀가 없는 최초 요청은 `childId = "default"` key를 사용한다.
- `/home` 응답으로 실제 `selectedChild.id`를 알게 되면 같은 응답을 실제 자녀 key에도
  저장하고 이후 화면은 실제 key를 구독한다.
- 자녀 추가·삭제·순서 변경 성공 시 `homeRoot`, `me`, `weeklyReportStatusRoot`,
  `weeklyReportRoot`를 invalidate한다. default 자녀가 바뀔 수 있기 때문이다.
- 다른 자녀의 캐시를 placeholder로 보여주지 않는다.

### 4.2 한국 날짜와 자정

홈에는 오늘의 추천, 놀이 연속일, 주간 달력처럼 날짜에 따라 바뀌는 값이 있다. 따라서
`staleTime`만으로 자정을 처리하지 않고 한국 날짜를 key에 포함한다.

- 앱이 열린 상태에서는 다음 한국 자정에 date state를 갱신하는 timer를 둔다.
- 앱이 background에 있어 timer가 지연될 수 있으므로 `visibilitychange`와 `focus` 때 한국
  날짜를 다시 계산한다.
- 날짜가 달라지면 새 key가 되어 전날 홈 캐시를 오늘 데이터로 표시하지 않는다.
- 23:59에 받은 5분 캐시가 있더라도 00:00 이후에는 오늘 key로 새 요청한다.
- 기기 시각 변경이나 timer 정지는 앱 복귀 시 재계산으로 보정한다.

서버가 `date` query를 받지 않는 기본 요청이어도 client cache key에는 날짜를 넣는다. 이는
같은 URL의 응답 의미가 날짜에 따라 변하기 때문이다.

## 5. Query별 정책

| Query              | key 요소                      | staleTime | gcTime | 갱신 계기                                                      |
| ------------------ | ----------------------------- | --------: | -----: | -------------------------------------------------------------- |
| 홈 `/home`         | 실제/default 자녀 + 한국 날짜 |      30초 |   10분 | mount, stale focus/reconnect, pull refresh, 관련 mutation      |
| 사용자 `/me`       | 현재 로그인 세션              |       5분 |   30분 | 설정 직접 진입, stale focus, 프로필·자녀·관심사·알림 설정 변경 |
| 미확인 리포트 상태 | 실제/default 자녀 + 한국 날짜 |      30초 |   10분 | 비홈 직접 진입, stale focus, 홈 응답 seed, 리포트 viewed       |
| 현재 주간 리포트   | 실제/default 자녀 + 한국 날짜 |       5분 |   30분 | 리포트 진입, 놀이 완료 후 invalidate, pull/retry               |
| 특정 리포트        | report ID                     |      30분 |   60분 | URL로 명시한 리포트 진입                                       |

`gcTime`은 보안 만료 시간이 아니다. 로그아웃·세션 사용자 변경 시 `queryClient.clear()`를
호출해 이전 사용자의 모든 메모리 캐시를 제거한다. access token, 사용자 ID, 아이 이름을
query key나 성능 이벤트에 넣지 않는다. 실제 child/report ID는 메모리 query key에만 있고
로그·Amplitude property로 전송하지 않는다.

## 6. 화면별 동작

### 6.1 홈

HomeDashboard의 수동 `useEffect + useState` 로딩을 `useQuery`로 이전한다.

1. 현재 저장된 자녀와 한국 날짜로 query key를 만든다.
2. 캐시가 있으면 즉시 렌더한다.
3. 캐시가 없을 때만 HomeSkeleton을 표시한다.
4. 성공 응답의 실제 `selectedChild.id`를 local selection과 실제 자녀 key에 반영한다.
5. 응답의 `hasUnviewedWeeklyReport`를 같은 자녀의 리포트 상태 query에 seed한다.
6. 당겨서 새로고침은 현재 홈 query를 강제로 refetch한다.
7. 자녀 전환은 새 자녀 key로 이동한다. 이전 자녀 데이터는 새 자녀의 placeholder로 쓰지
   않는다.

홈 알림 읽기처럼 응답 형태를 정확히 갱신할 수 있는 mutation은 성공 후 `setQueryData`로
즉시 반영한다. 서버 결과를 계산하기 어려운 변경은 `invalidateQueries`를 사용한다.

### 6.2 BottomNav 리포트 상태

홈 성공 응답이 같은 자녀의 상태 query를 채우므로 홈에서는 별도 상태 API를 호출하지
않는다. 비홈 직접 진입에서 상태 캐시가 없을 때만
`GET /weekly-reports/unviewed-status`를 호출한다. 같은 key의 focus와 visibility 이벤트가
겹쳐도 Query가 in-flight 요청을 공유하므로 직접 single-flight를 유지하지 않는다.

당분간 선택 자녀를 sibling component에 알리는 main shell context는 유지한다. Query는
서버 상태 캐시이고, 현재 선택 자녀는 client UI state이므로 이번 단계에서 억지로 하나로
합치지 않는다. 리포트 상태 boolean의 진실은 Query cache로 옮기고 context는 선택 변화
전파와 점진적 이전에만 사용한다.

### 6.3 주간 리포트

- 현재 리포트와 URL의 특정 `reportId`는 다른 key를 사용한다.
- 리포트 데이터는 캐시에서 즉시 표시하되, `PATCH .../viewed`는 화면 표시와 별개로
  idempotent하게 수행한다.
- viewed 성공 시 같은 자녀의 리포트 상태를 `false`로 set하고 홈 캐시의 boolean도
  `false`로 갱신한다.
- viewed 실패 시 성공 상태로 바꾸지 않으며 다음 진입에서 다시 시도할 수 있다.
- 조회 분석 이벤트는 API 호출 횟수가 아니라 실제 화면 진입당 한 번만 기록한다.

### 6.4 설정의 `/me`

프로필, 자녀, 관심사, 알림 설정 화면이 같은 `me` query를 공유한다. 각 화면은 필요한
필드를 select해서 사용해도 원본 query key는 하나로 유지한다.

- 캐시가 있으면 설정 화면 간 이동에서 `/me`를 다시 호출하지 않는다.
- 프로필·관심사·알림 수정 성공 시 응답으로 정확히 갱신 가능하면 `setQueryData`, 아니면
  `invalidateQueries(queryKeys.me())`를 실행한다.
- 자녀 생성·수정·삭제·순서 변경은 `/me`와 모든 자녀 의존 query를 invalidate한다.
- logout 또는 다른 계정 session 주입 시 전체 Query cache를 clear한다.

## 7. Mutation 이후 갱신 계약

| 성공한 작업                   | 즉시 갱신                          | invalidate                                        |
| ----------------------------- | ---------------------------------- | ------------------------------------------------- |
| 알림 한 건 읽기               | 현재 홈 notifications count/list   | 없음                                              |
| 알림 모두 읽기                | 현재 홈 notifications count/list   | 없음                                              |
| 놀이 알림 설정                | 현재 홈 `playNotificationEnabled`  | `me`                                              |
| 리포트 viewed                 | 상태 query=false, 홈 boolean=false | 필요 시 해당 report                               |
| 놀이 완료/피드백 완료         | 없음                               | 선택 자녀의 오늘 홈, 현재 리포트, 리포트 상태     |
| 로드맵 milestone 변경         | 로드맵 화면의 optimistic state     | 선택 자녀의 오늘 홈                               |
| 기분 체크                     | 응답으로 현재 홈 mood 갱신         | 계산 불가 시 홈                                   |
| 프로필/관심사/일반 알림 변경  | 응답으로 `me` 갱신 가능 시 반영    | `me`, 영향받는 홈                                 |
| 자녀 생성/수정/삭제/순서 변경 | 선택 자녀 local state 정리         | `me`, 모든 home/report/roadmap/mission 자녀 query |
| 로그아웃/계정 변경            | 없음                               | invalidate가 아니라 `queryClient.clear()`         |

invalidate는 root key로 무조건 전체 앱을 갱신하지 않고 가능한 가장 좁은 자녀·날짜 범위를
사용한다. 다만 default 자녀가 바뀔 수 있는 자녀 구조 변경은 root 단위가 맞다.

mutation이 실패하면 optimistic update를 원복한다. invalidate Promise를 사용자 이동보다
반드시 먼저 기다려야 하는지는 화면별로 결정한다. 놀이 완료 후 홈으로 돌아가는 경우에는
invalidate 표시만 먼저 해두면 홈 mount가 최신 데이터를 가져올 수 있으므로 이동을 막지
않는다.

## 8. 오류·인증·개인정보

- queryFn은 실패를 정상 데이터 `{ error }`로 반환하지 않고 가능한 한 throw한다. 그래야
  Query의 retry/error 상태가 정확해진다. 기존 API wrapper를 한 번에 바꾸기 어렵다면
  adapter에서 error를 throw하고 UI용 메시지로 변환한다.
- 401은 retry하지 않고 기존 로그인/온보딩 복구 흐름으로 넘긴다.
- background refetch 401에서 이전 사용자 캐시를 계속 노출하지 않는다. 세션 불일치가
  확인되면 cache clear 후 인증 화면으로 이동한다.
- 캐시 데이터는 메모리에만 존재하며 새 로그나 localStorage에 API 응답을 저장하지 않는다.
- React Query Devtools는 production bundle에 포함하지 않는다. 로컬에서 필요하면 개발
  전용 dynamic import를 별도 검토한다.

## 9. 구현 순서와 커밋 단위

각 단계는 독립 커밋으로 남겨 단계별 측정과 revert가 가능해야 한다.

1. `chore(web)`: TanStack Query 의존성, root provider, query key factory, 한국 날짜 hook,
   retry 정책과 unit test
2. `refactor(web)`: 홈 query 전환, 자녀/date key, pull refresh, 알림 cache update,
   리포트 상태 seed
3. `refactor(web)`: BottomNav 상태 query 및 주간 리포트 query 전환, viewed cache update,
   기존 직접 single-flight 제거
4. `refactor(web)`: 설정 화면의 공통 `me` query 전환과 mutation invalidation
5. `fix(web)`: 놀이 완료·로드맵·설정 변경의 홈/리포트 캐시 무효화 누락 보완
6. `test(web)`: query cache 수명·자녀 격리·자정·mutation 갱신 통합 테스트와 측정 결과

한 단계가 빌드 또는 QA를 통과하지 못하면 그 단계부터 수정한다. 모든 코드를 한 커밋으로
묶지 않는다. API·mobile 변경은 예정하지 않는다.

## 10. 성능 측정

### 10.1 로컬 전후 비교

변경 전 commit과 변경 후 commit을 같은 로컬 production build, 같은 API/DB, 같은 Chrome
profile과 viewport에서 비교한다. DevTools Network의 Disable cache는 **ON으로 고정**하되,
이는 HTTP cache만 끄며 Query memory cache는 유지한다. 각 버전에서 준비 실행 1회를 제외하고
다음 흐름을 10회 반복한다.

```text
홈 데이터 표시
→ 놀이 또는 로드맵 탭 이동
→ 홈 탭 복귀
→ 5초 대기
→ 다시 다른 탭 이동
→ 홈 복귀
```

추가 시나리오:

1. 30초 안의 홈 재방문: `/home` 요청 0건, 캐시 즉시 표시
2. 30초 이후 홈 재방문: 캐시 즉시 표시 후 `/home` 1건 background refetch
3. 당겨서 새로고침: 즉시 `/home` 1건
4. 자녀 A→B→A: 자녀 데이터 혼합 없이 key별 캐시 사용
5. 날짜 변경 모의 테스트: 전날 캐시를 오늘 key에서 사용하지 않음
6. 놀이 완료 후 홈: 완료 전 홈 캐시를 그대로 표시하지 않고 최신 홈 조회
7. 설정 화면 연속 이동: 최초 이후 불필요한 `/me` 제거

### 10.2 지표

| 지표                         | 기준선                      | 완료 조건                                 |
| ---------------------------- | --------------------------- | ----------------------------------------- |
| 홈 재방문 첫 데이터 표시     | 변경 전 `screen_first_data` | cache hit P50/P75 감소                    |
| 홈 재방문 fresh 반영         | 변경 전 API 반영            | stale refetch P75가 회귀하지 않음         |
| 30초 내 홈 재방문 `/home` 수 | 매번 1건                    | 0건                                       |
| stale 홈 재방문 `/home` 수   | 매번 1건                    | 1건, 중복 없음                            |
| 설정 연속 이동 `/me` 수      | 화면별 반복                 | 최초 1건 후 fresh 동안 0건                |
| 리포트 상태 요청             | focus/직접 진입별 직접 관리 | 같은 key의 동시 요청 1건 이하             |
| 최초 문서 FCP/LCP            | 기존 로컬 기준선            | Query bundle 추가 후 유의미한 회귀 없음   |
| JS 전송/실행 비용            | 변경 전 build/trace         | 증가량 기록, 첫 화면 이득을 상쇄하지 않음 |
| 오류율                       | 변경 전                     | 증가 없음                                 |

캐시된 화면은 `screen_first_data source=cache`와 최신 API 반영
`screen_fresh_data source=api`를 분리한다. 캐시가 보인 시각은 Query data가 React에 반영된 뒤
기존 두 프레임 기준으로 기록하고, 최신 반영은 성공한 refetch의 `dataUpdatedAt` 변화와 fetch
완료를 기준으로 기록한다. Network response 시간만으로 화면 표시 시간을 대신하지 않는다.

5~10회 로컬 표본은 방향과 요청 수 확인용이다. 운영 P75/P95나 리텐션 결론에는 배포 후
충분한 실제 사용자 표본이 필요하다.

## 11. 기능 완료 조건

- 30초 안에 홈→다른 탭→홈으로 돌아오면 스켈레톤 없이 캐시 화면이 즉시 보이고 `/home`
  요청이 없다.
- 30초가 지난 캐시에서도 화면을 비우지 않고 background에서 한 번만 갱신한다.
- 당겨서 새로고침은 fresh 캐시가 있어도 서버를 조회한다.
- 23:59 캐시가 00:00 이후 오늘 홈 데이터로 사용되지 않는다.
- 자녀 전환 중 이전 자녀의 이름·추천·리포트 툴팁이 새 자녀 화면에 섞이지 않는다.
- 놀이 완료 후 홈의 오늘 놀이 상태·연속일·달력이 최신 상태로 갱신된다.
- 리포트 확인 직후 BottomNav 툴팁이 사라지고 재방문에서도 다시 나타나지 않는다.
- 설정 화면 사이를 이동할 때 fresh `/me` 캐시를 재사용하고, 설정 변경 후에는 최신 정보가
  보인다.
- 앱 background→foreground 복귀 시 stale query만 갱신하고 동일 key 요청을 중복 전송하지
  않는다.
- 로그아웃·계정 변경 뒤 이전 사용자의 캐시 데이터가 보이지 않는다.
- 최초 방문의 기존 스켈레톤·오류·재시도 UI가 정상 동작한다.
- unit test, lint, production build가 통과한다.
- 로컬 전후 측정 결과와 원본 조건을 문서에 추가한 뒤 구현 PR을 연다.

## 12. QA 체크

1. 앱/웹을 새로 열어 홈 정상 표시 확인
2. 홈→놀이→홈을 3회 반복하고 두 번째부터 스켈레톤·`/home` 요청 여부 확인
3. 30초 대기 후 탭 왕복하여 기존 화면 유지 + background `/home` 한 건 확인
4. 홈에서 당겨서 새로고침하고 최신 응답 반영 확인
5. 다자녀 계정에서 A→B→A 전환, 이름·놀이·리포트 툴팁 확인
6. 놀이 시작→완료→피드백→홈 이동 후 완료 상태 확인
7. 로드맵 milestone 변경→홈 복귀 후 진행률 확인
8. 리포트 열기→뒤로가기 후 툴팁 제거 확인
9. 프로필→자녀→관심사→알림 설정 이동 중 `/me` 요청 수 확인
10. 프로필·자녀·관심사 중 하나를 수정한 뒤 재진입해 최신 값 확인
11. 앱 background→foreground 복귀 후 중복 요청·화면 깜박임 확인
12. 로그아웃 후 다른 테스트 계정으로 로그인하여 이전 계정 데이터가 보이지 않는지 확인

## 13. 롤백

DB migration과 API 계약 변경이 없으므로 web PR revert만으로 원복한다. 장애가 query 정책
일부에 한정되면 해당 화면을 기존 직접 fetch로 되돌릴 수 있지만 provider만 남겨 둔 혼합
상태를 장기간 유지하지 않는다. 계정 간 캐시 노출, 자녀 데이터 혼합, mutation 후 심각한
stale이 발견되면 성능 이득과 무관하게 즉시 롤백한다.
