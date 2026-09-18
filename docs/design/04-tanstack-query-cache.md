# Server Component + TanStack Query 데이터 로딩

> 작성일: 2026-09-18 · 상태: `proposed (구현 전 검토)`
> 관련 문서: [성능 기준선과 개선 실험](./02-performance-baseline.md),
> [홈 부가 요청 통합 설계(PR #30)](https://github.com/four-lovely-fairies/yougabell/pull/30),
> [홈](../features/20260510-home.md),
> [주간 리포트](../features/20260513-weekly-report.md),
> [설정](../features/20260519-settings.md)

## 0. 결정 요약

초기 화면은 Server Component가 데이터를 가져와 HTML/RSC에 포함하고, Client Component는
그 결과를 TanStack Query 캐시에 hydrate한다. 이후 같은 앱 실행 중 탭 재방문, 백그라운드
갱신, 사용자 동작 이후의 데이터 동기화는 Query가 담당한다.

```text
첫 진입
브라우저/WebView → Next Server Component → Nest API
                  ← HTML/RSC + dehydrated query
                  → Query cache hydrate → 즉시 상호작용

같은 앱 실행 중 재사용
화면 mount → Query cache 표시 → stale일 때만 background refetch

사용자 변경 작업
mutation 성공 → setQueryData 또는 invalidateQueries → 필요한 데이터만 갱신
```

| 항목              | 결정                                                                      | 이유                                                         |
| ----------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------ |
| 초기 데이터       | Server Component에서 필수 query를 prefetch하고 `HydrationBoundary`로 전달 | HTML/RSC 수신 뒤 별도 client fetch를 기다리는 waterfall 제거 |
| 재방문 데이터     | root `QueryClient`의 메모리 캐시 재사용                                   | 탭 왕복 때 스켈레톤과 직접 API 재요청 반복 방지              |
| 1차 적용 범위     | 홈 `/home`                                                                | 첫 화면이며 현재 성능 계측과 기준선이 준비됨                 |
| 2차 적용 범위     | 주간 리포트·리포트 상태·설정 `/me`                                        | 홈 방식 검증 후 같은 패턴으로 확장                           |
| Next 서버 캐시    | 인증된 도메인 데이터는 우선 `cache: "no-store"`                           | 사용자 간 격리 오류와 서버 stale을 먼저 피함                 |
| Query 캐시        | 브라우저 메모리에만 보관                                                  | 앱 종료 뒤 개인정보와 오래된 데이터를 남기지 않음            |
| 홈 신선도         | `staleTime = 30초`, `gcTime = 10분`                                       | 짧은 왕복은 재조회하지 않고 오래된 화면은 배경 갱신          |
| `/me`·주간 리포트 | `staleTime = 5분`, `gcTime = 30분`                                        | 변경 빈도가 낮고 재사용 가치가 큼                            |
| 날짜 경계         | 오늘 의미가 있는 key에 한국 날짜 포함                                     | 23:59 캐시를 다음 날 데이터로 표시하지 않음                  |
| 선택 자녀         | 기존 localStorage와 서버가 읽을 수 있는 cookie를 동기화                   | 서버도 첫 렌더에서 올바른 자녀를 요청해야 함                 |
| 쓰기 이후         | 정확한 결과는 `setQueryData`, 나머지는 좁게 invalidate                    | stale 방지와 불필요한 전체 refetch 사이의 균형               |
| Server Action     | 이번 단계에서 필수로 도입하지 않음                                        | 기존 client→Nest mutation을 유지하고 Query 캐시만 동기화     |
| 실험 기능         | `staleTimes`, `use cache: private`, Cache Components 미사용               | 현재 Next 공식 문서상 실험 기능에 초기 설계를 의존하지 않음  |

이 구조에서 Server Component와 Query는 같은 일을 중복하는 것이 아니다. Server Component는
**최초 응답에 데이터를 싣는 역할**, Query는 hydration 이후 **브라우저 수명 동안 데이터를
재사용하고 갱신하는 역할**을 맡는다.

## 1. 현재 문제

현재 실제 데이터 화면은 대부분 Client Component가 mount된 뒤 `useEffect`에서 API를
호출하고 local state에 저장한다.

```text
첫 홈: HTML/RSC → client JS/hydration → Supabase browser session → GET /home → 렌더
재방문: component 재생성 → local state 없음 → GET /home → 렌더
```

이 방식에는 다음 문제가 있다.

1. 첫 화면 데이터 요청이 client hydration과 세션 조회 뒤에 시작된다.
2. 화면이 unmount되면 local state가 사라져 탭 재방문 때 같은 요청을 반복한다.
3. 홈, 리포트, 설정이 각자 로딩·재시도·중복 요청·stale 처리를 직접 구현한다.
4. 놀이 완료나 설정 변경 뒤 어떤 화면 데이터를 갱신해야 하는지 계약이 분산되어 있다.
5. 캐시된 화면 표시 시점과 최신 서버 데이터 반영 시점을 구분해 측정하기 어렵다.

기존 Server Component의 `fetchServerMe()`는 인증·온보딩 guard만 담당한다. 화면 본문 데이터는
여전히 client에서 가져오므로 이번 설계는 guard를 제거하지 않고 화면 데이터 경로를
추가한다.

## 2. 목표와 비목표

### 2.1 목표

- 첫 홈은 Server Component가 받은 `/home` 데이터로 렌더한다.
- hydration 직후 같은 데이터가 Query cache에 있어 중복 client `/home` 요청이 없다.
- 같은 앱 실행 중 홈 재방문은 기존 Query 데이터를 유지하고, 정책에 따라 갱신한다.
- 자녀, 한국 날짜, 로그인 사용자가 다른 데이터를 같은 cache entry로 섞지 않는다.
- 놀이 완료, 리포트 확인, 설정 변경 뒤 영향받은 query만 갱신한다.
- 변경 전후의 첫 진입과 탭 재방문을 각각 측정한다.

### 2.2 비목표

- Next 서버에 인증 사용자 응답을 장기 저장하는 shared cache
- localStorage/AsyncStorage Query persister
- `/mobile-entry` hard reload 제거
- 추천 놀이·연속일 계산 자체의 API/DB 최적화
- 모든 화면을 한 PR에서 Query로 이전
- React local UI state(모달, 드롭다운, 선택 중인 탭)를 Query로 이전
- 이번 작업만으로 운영 리텐션 개선을 입증

## 3. 전체 구조

### 3.1 세 종류의 QueryClient

역할이 다른 인스턴스를 구분한다.

| 위치                             | 수명                   | 역할                                                      |
| -------------------------------- | ---------------------- | --------------------------------------------------------- |
| Server Component prefetch client | 한 서버 렌더 요청      | Nest 응답을 담고 serialize할 dehydrated state 생성        |
| React server render 내부 client  | 한 서버 렌더 요청      | 같은 dehydrated state로 서버 markup 생성                  |
| 브라우저 client                  | 현재 문서/WebView 수명 | hydration 이후 화면 간 cache 재사용·refetch·mutation 반영 |

서버 `QueryClient`를 module 전역 singleton으로 만들지 않는다. 하나의 Vercel/Next 프로세스는
서로 다른 부모 계정의 요청을 연속으로 처리할 수 있으므로 전역 cache는 사용자 데이터가
섞일 위험이 있다. 서버에서는 요청마다 새 인스턴스를 만들고, 브라우저에서는 root provider
수명 동안 한 인스턴스만 유지한다.

### 3.2 컴포넌트 배치

```text
app/layout.tsx (Server Component)
└─ AppProviders (Client Component)
   └─ QueryClientProvider (브라우저 인스턴스 1개)
      └─ route tree
         └─ app/(main)/page.tsx (Server Component)
            └─ HydrationBoundary(home dehydrated state)
               └─ HomeDashboard (Client Component, useQuery)
```

`QueryClientProvider`는 route별 layout 안이 아니라 root provider에 둔다. 홈에서 놀이·설정으로
이동해도 provider가 교체되지 않아야 브라우저 cache가 살아 있기 때문이다.

`HydrationBoundary`는 prefetch한 화면 가까이에 둔다. 전체 Query cache를 모든 route payload에
싣지 않고 현재 화면에 필요한 query만 serialize한다.

### 3.3 서버와 브라우저 API helper 분리

기존 browser helper는 Supabase browser session에서 access token을 읽는다. Server Component는
다음 별도 helper를 사용한다.

1. `cookies()` 기반 Supabase server client로 session 확인
2. access token을 `Authorization` header에 넣어 Nest 호출
3. `cache: "no-store"`로 사용자 응답을 Next shared cache에 저장하지 않음
4. `measureServer("server_home", ...)`로 API 시간과 request ID 기록
5. cookie의 자녀 ID가 404이면 기본 자녀로 한 번만 재시도하고 잘못된 cookie를 client에서
   제거할 수 있는 결과를 반환
6. 그 외 401/403/404를 browser helper와 같은 domain error로 변환

server query와 browser query는 **같은 query key와 같은 응답 타입**을 사용한다. queryFn만
실행 환경에 따라 다르다.

## 4. 첫 홈 로딩 계약

### 4.1 서버 prefetch와 hydration

`app/(main)/page.tsx`는 기존 `fetchServerMe()` guard를 유지하고 홈 query를 prefetch한다.

```typescript
const queryClient = makeServerQueryClient();
const requestedChildId = await readSelectedChildCookie();
const requestedOptions = homeQueryOptions({
  childId: requestedChildId,
  date: koreaDate,
  queryFn: () => fetchServerHome(requestedChildId),
});
const home = await queryClient.fetchQuery(requestedOptions);
const resolvedChildId = home.data.selectedChild.id;

if (resolvedChildId !== requestedChildId) {
  queryClient.setQueryData(
    homeQueryOptions({
      childId: resolvedChildId,
      date: koreaDate,
    }).queryKey,
    home,
    { updatedAt: queryClient.getQueryState(requestedOptions.queryKey)?.dataUpdatedAt },
  );
  queryClient.removeQueries({ queryKey: requestedOptions.queryKey, exact: true });
}

return (
  <HydrationBoundary state={dehydrate(queryClient)}>
    <HomeDashboard initialChildId={resolvedChildId} />
  </HydrationBoundary>
);
```

예시는 책임을 보여주기 위한 의사 코드다. 실제 구현에서는 실패 query를 기본 dehydrate하지
않는 TanStack Query 동작을 고려한다.

- 인증 실패: 기존 auth routing으로 이동
- 홈 404/데이터 없음: 기존 HomeError 또는 명시적인 서버 오류 경계 사용
- 일시적인 5xx: 서버 응답 전체를 실패시키지 않고 기존 client retry 경로로 내려갈지 구현 시
  결정하되, 같은 오류를 서버와 client가 동시에 반복 요청하지 않음

성공한 prefetch의 `dataUpdatedAt`이 브라우저로 전달되므로 `staleTime`은 HTML을 받은 시각이
아니라 서버가 데이터를 가져온 시각부터 계산한다. 30초 동안은 hydration 직후 client가
같은 `/home`을 다시 요청하지 않는다.

### 4.2 서버 렌더와 탭 재방문의 차이

Server Component prefetch는 첫 진입을 줄이지만, dynamic route로 다시 이동하면 Next가 RSC를
받기 위해 서버를 호출할 수 있다. Query cache가 있다고 해서 Next router의 RSC 요청 자체가
자동으로 없어지는 것은 아니다.

따라서 다음을 함께 적용하고 별도로 측정한다.

- BottomNav는 `<Link>` 또는 `router.prefetch()`로 홈 route를 미리 준비한다.
- 무조건 다섯 탭을 full prefetch하지 않고, 현재 탭이 홈이 아닐 때 홈만 우선 prefetch한다.
- prefetch가 Nest `/home`을 얼마나 추가 호출하는지 `server_home` 계측으로 확인한다.
- experimental `staleTimes`에 의존하지 않는다.
- Query cache hit인데도 탭 클릭→표시 시간이 RSC 왕복만큼 지연되면 persistent app shell 또는
  route 구조 개선을 후속 실험으로 분리한다.

완료 조건은 “브라우저 Network에 직접 `/home`이 0건”만으로 잡지 않는다. RSC 안에서 Next가
Nest `/home`을 호출할 수 있으므로 **화면 표시 시간, browser API 수, server API 수**를 모두
기록한다.

## 5. 선택 자녀 계약

현재 선택 자녀는 localStorage에만 있어 Server Component가 읽을 수 없다. 그대로 구현하면
다자녀 사용자의 첫 서버 렌더가 기본 자녀로 만들어졌다가 client에서 다른 자녀로 바뀔 수
있다.

### 5.1 저장 위치

- `home:selected-child-id` localStorage는 client UI와 기존 코드 호환을 위해 유지한다.
- 같은 값을 server-readable cookie에도 저장한다.
- 자녀 선택 시 두 저장소를 같은 함수에서 함께 갱신한다.
- cookie에는 opaque child ID만 저장하고 이름·생년월일 등 개인정보는 저장하지 않는다.
- production에서는 `Secure`, 모든 환경에서 `SameSite=Lax`, `/` path를 사용한다. 로컬 HTTP
  개발 환경에서는 `Secure`를 붙이지 않는다. JavaScript가 갱신해야 하므로 HttpOnly는 사용할
  수 없다.
- 로그아웃, 계정 변경, 선택 자녀 삭제 시 localStorage와 cookie를 모두 제거한다.

### 5.2 기존 사용자 최초 마이그레이션

배포 직후 기존 사용자는 localStorage에는 값이 있고 cookie는 없을 수 있다.

1. 서버는 cookie가 없으면 API의 기본 자녀를 prefetch한다.
2. client mount에서 localStorage의 유효한 ID가 서버 선택과 다르면 그 ID로 query를 전환한다.
3. 잘못된 자녀 데이터가 잠깐 보이지 않도록 전환 동안 기존 기본 자녀 화면 대신 loading
   상태를 사용한다.
4. 선택 결과가 확인되면 cookie를 채운다. 다음 진입부터 서버도 같은 자녀를 사용한다.
5. localStorage ID가 404이면 양쪽 저장소를 비우고 기본 자녀로 한 번만 재시도한다.

첫 배포에서 일부 기존 다자녀 사용자에게 한 번의 추가 client `/home` 요청이 생길 수 있다.
이는 영구 중복이 아니라 cookie 마이그레이션 비용이며 별도 property로 구분해 측정한다.

## 6. Query key와 날짜 계약

query key는 중앙 factory에서만 만든다.

```typescript
queryKeys.home({ childId, date: koreaDate });
queryKeys.me();
queryKeys.weeklyReportStatus({ childId, date: koreaDate });
queryKeys.weeklyReportCurrent({ childId, date: koreaDate });
queryKeys.weeklyReportDetail({ reportId });
```

- 명시된 자녀는 실제 `childId`를 key에 넣는다.
- 자녀가 정해지기 전 요청은 `childId = "default"`를 사용한다.
- `/home` 응답으로 실제 `selectedChild.id`를 알면 실제 자녀 key에도 같은 데이터를 seed한다.
- 다른 자녀 cache를 placeholder로 표시하지 않는다.
- access token, 사용자 ID, 아이 이름은 key나 성능 이벤트에 넣지 않는다.
- 실제 child/report ID는 브라우저 메모리 key에만 있고 분석 로그로 전송하지 않는다.

홈의 추천, 연속일, 주간 달력은 날짜가 바뀌면 의미가 달라지므로 한국 날짜를 key에 넣는다.

- 열린 앱은 다음 한국 자정에 date state를 갱신한다.
- background timer 지연에 대비해 `visibilitychange`와 `focus` 때 다시 계산한다.
- 날짜가 바뀌면 새 key를 사용하므로 23:59 cache를 00:00 이후 표시하지 않는다.
- 서버와 client가 같은 `Asia/Seoul` 날짜 계산 함수를 공유한다.

## 7. QueryClient 기본 정책

```typescript
new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      gcTime: 600_000,
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
      retry: retryOnceForNetworkOrServerError,
    },
    mutations: { retry: false },
  },
});
```

- 401/403과 사용자가 고칠 수 없는 4xx는 retry하지 않는다.
- 네트워크 오류와 5xx만 최대 한 번 재시도한다.
- mutation은 중복 쓰기를 피하기 위해 자동 retry하지 않는다.
- `isPending`은 표시할 데이터가 없는 최초 로딩에만 사용한다.
- `isFetching` 중 기존 데이터가 있으면 화면을 비우지 않는다.
- 당겨서 새로고침은 fresh 여부와 무관하게 현재 query를 refetch한다.
- background refetch 실패 시 기존 cache를 유지하고 비차단 오류로 처리한다.

WebView 복귀가 브라우저 focus만으로 항상 감지된다고 가정하지 않는다. 공통 provider에서
`visibilitychange`와 `window.focus`를 Query focus manager에 연결한다. 실기기에서 둘 다
누락될 때만 native AppState bridge를 후속 mobile 작업으로 추가한다.

| Query              | key 요소                      | staleTime | gcTime |
| ------------------ | ----------------------------- | --------: | -----: |
| 홈 `/home`         | 실제/default 자녀 + 한국 날짜 |      30초 |   10분 |
| 사용자 `/me`       | 현재 로그인 session           |       5분 |   30분 |
| 미확인 리포트 상태 | 실제/default 자녀 + 한국 날짜 |      30초 |   10분 |
| 현재 주간 리포트   | 실제/default 자녀 + 한국 날짜 |       5분 |   30분 |
| 특정 리포트        | report ID                     |      30분 |   60분 |

로그아웃 또는 다른 계정 session 주입이 확인되면 `queryClient.clear()`를 호출한다. `gcTime`은
보안 만료 시간이 아니다.

## 8. 화면별 적용

### 8.1 1차: 홈

1. Server Component가 선택 자녀 cookie와 한국 날짜로 `/home`을 prefetch한다.
2. `HomeDashboard`는 같은 key로 `useQuery`를 구독한다.
3. hydrated data가 있으므로 첫 client render에서 별도 `/home`을 호출하지 않는다.
4. 홈 응답의 실제 자녀 ID를 저장소와 실제 자녀 key에 반영한다.
5. `hasUnviewedWeeklyReport`를 리포트 상태 query에 seed한다.
6. 자녀 전환은 새 key로 이동하며 이전 자녀 데이터를 placeholder로 사용하지 않는다.
7. 당겨서 새로고침은 현재 자녀 query를 강제로 refetch한다.

### 8.2 2차: 리포트와 설정

홈 효과가 확인된 뒤 별도 커밋으로 확장한다.

- 홈에서 seed한 리포트 상태가 있으면 BottomNav는 별도 상태 API를 호출하지 않는다.
- 비홈 직접 진입은 해당 route Server Component가 필요한 리포트 query를 prefetch한다.
- 리포트 viewed 성공 시 상태 query와 홈 boolean을 즉시 `false`로 갱신한다.
- 프로필·자녀·관심사·알림 설정은 공통 `me` query를 사용한다.
- 설정 route 직접 진입은 Server Component가 `/me`를 prefetch하고, 설정 내 이동은 같은 Query
  cache를 재사용한다.

인증 guard용 `fetchServerMe()`와 화면용 전체 `me` query는 목적이 다르다. 구현 중 실제 응답과
타이밍을 확인해 한 서버 렌더에서 안전하게 공유할 수 있을 때만 중복을 합친다. 타입이 다른
응답을 억지로 같은 key에 넣지 않는다.

## 9. Mutation 이후 갱신 계약

기존 client→Nest mutation은 유지한다. 성공 뒤 Query cache를 아래처럼 갱신하며, 이번 단계에서
Server Action과 `revalidatePath`를 필수로 만들지 않는다.

| 성공한 작업                   | 즉시 갱신                         | invalidate                                  |
| ----------------------------- | --------------------------------- | ------------------------------------------- |
| 알림 한 건/전체 읽기          | 현재 홈 notifications             | 없음                                        |
| 놀이 알림 설정                | 현재 홈 `playNotificationEnabled` | `me`                                        |
| 리포트 viewed                 | 상태=false, 홈 boolean=false      | 필요 시 해당 report                         |
| 놀이 완료/피드백 완료         | 없음                              | 선택 자녀의 오늘 홈·현재 리포트·리포트 상태 |
| 로드맵 milestone 변경         | 로드맵 optimistic state           | 선택 자녀의 오늘 홈                         |
| 기분 체크                     | 응답으로 현재 홈 mood             | 계산 불가 시 홈                             |
| 프로필·관심사·일반 알림 변경  | 응답으로 `me` 갱신 가능 시 반영   | `me`, 영향받는 홈                           |
| 자녀 생성·수정·삭제·순서 변경 | 선택 자녀 저장소 정리             | 모든 자녀 의존 query                        |
| 로그아웃·계정 변경            | 없음                              | invalidate 대신 `queryClient.clear()`       |

invalidate는 가능한 가장 좁은 자녀·날짜 범위를 사용한다. 자녀 삭제나 순서 변경처럼 기본
자녀가 달라질 수 있는 작업만 root key를 invalidate한다.

Next 서버 데이터가 `no-store`이므로 client mutation 뒤 서버 cache revalidation은 필요하지
않다. 현재 보이는 Server Component 자체를 다시 렌더해야 하는 경우만 `router.refresh()`를
별도로 사용한다. 향후 Next server cache를 도입하면 그때 Server Action/Route Handler와
`revalidateTag` 계약을 추가한다.

## 10. 오류와 개인정보

- queryFn은 실패를 `{ error }` 데이터로 반환하지 않고 throw한다.
- 서버 prefetch 실패가 발생해도 오류를 숨긴 채 빈 성공 데이터로 hydrate하지 않는다.
- 401은 retry하지 않고 기존 인증 복구 흐름으로 넘긴다.
- background 401에서 이전 사용자 cache를 계속 노출하지 않는다.
- Query 응답을 localStorage, 로그, Amplitude property에 저장하지 않는다.
- React Query Devtools는 production bundle에 포함하지 않는다.
- dehydrate payload에는 현재 화면에 필요한 성공 query만 포함한다.

## 11. 구현 순서와 커밋 단위

각 단계는 독립 커밋으로 남겨 측정과 revert가 가능하게 한다.

1. `chore(web)`: TanStack Query v5, root provider, request-scoped server query client, query key
   factory, retry/date utility와 unit test
2. `feat(web)`: 선택 자녀 cookie 동기화와 기존 localStorage 사용자 마이그레이션
3. `refactor(web)`: 홈 server prefetch·dehydrate·hydrate, `HomeDashboard useQuery` 전환
4. `perf(web)`: 홈 BottomNav route prefetch와 server/browser 요청 계측
5. `fix(web)`: 홈 관련 mutation의 `setQueryData`·invalidate 누락 보완
6. `test(web)`: 첫 진입·탭 재방문·자녀 격리·자정·로그아웃 통합 테스트와 전후 측정
7. 홈 완료 조건 충족 뒤 `refactor(web)`: 리포트와 설정 query 이전

API 계약과 DB migration은 예정하지 않는다. mobile 변경도 WebView focus 이벤트가 실기기에서
누락되는 것이 확인되기 전에는 하지 않는다.

## 12. 성능 측정

### 12.1 비교 시나리오

변경 전 commit과 변경 후 commit을 같은 로컬 production build, 같은 배포 API/DB, 같은 Chrome
profile·viewport·network 조건에서 비교한다. 준비 실행 1회를 제외하고 각 시나리오를 10회
반복한다.

**A. 앱/문서 첫 홈 진입**

```text
새 문서 또는 cache 없는 WebView 시작 → 홈 실제 콘텐츠 표시
```

- FP/FCP/LCP
- `screen_first_data`
- `/home` server fetch 시간
- hydration 뒤 browser `/home` 중복 여부
- dehydrated RSC payload와 JS 증가량

**B. 같은 앱 실행 중 탭 왕복**

```text
홈 표시 → 놀이 또는 로드맵 → 홈 탭 → 5초 대기 → 다른 탭 → 홈 탭
```

- 탭 클릭→기존 홈 데이터 표시
- cache 표시→최신 API 반영
- browser `/home` 수
- RSC request 수와 시간
- Next server→Nest `/home` 수와 시간

**C. 데이터 변경**

- 놀이 완료→홈
- 자녀 A→B→A
- 리포트 viewed→홈/BottomNav
- 23:59→00:00 모의 전환
- 로그아웃→다른 계정 로그인

### 12.2 완료 지표

| 지표                 | 완료 조건                                                               |
| -------------------- | ----------------------------------------------------------------------- |
| 첫 홈 client `/home` | hydration 직후 중복 요청 0건                                            |
| 첫 홈 표시           | 기존 FCP/LCP와 `screen_first_data` 대비 유의미한 회귀 없음, 목표는 개선 |
| 30초 내 홈 재방문    | 스켈레톤 없이 cache data 표시                                           |
| stale 홈 재방문      | 기존 화면 유지 + background refetch 한 건 이하                          |
| RSC 대기             | Query cache 이득을 상쇄하지 않는지 탭 클릭 기준으로 기록                |
| server `/home`       | route prefetch 포함 호출 수를 기록하고 중복 폭증 없음                   |
| 자녀 전환            | 다른 자녀 데이터가 한 프레임이라도 본문에 표시되지 않음                 |
| 날짜 변경            | 전날 query를 오늘 화면에 사용하지 않음                                  |
| mutation             | 놀이 완료·리포트 viewed 뒤 stale 상태가 남지 않음                       |
| 오류율               | 변경 전보다 증가 없음                                                   |
| bundle/payload       | 증가량 기록, 첫 화면 이득을 상쇄하지 않음                               |

캐시가 보인 시점은 `screen_first_data source=cache|server_hydration`, 최신 API 반영은
`screen_fresh_data source=api`로 구분한다. Network response 완료 시각만 화면 표시 시각으로
간주하지 않고 React 반영 뒤 paint 기회를 포함한 기존 계측 기준을 사용한다.

로컬 5~10회는 방향과 요청 수를 검증하는 표본이다. 운영 P75/P95와 리텐션 결론은 배포 뒤
실사용자 표본으로 판단한다.

## 13. 기능 완료 조건

- 첫 홈 HTML/RSC에 `/home` 성공 데이터가 포함된다.
- hydration 직후 동일 key의 browser `/home` 재요청이 없다.
- 30초 안의 홈 재방문은 스켈레톤 없이 cache를 표시한다.
- stale cache가 있어도 전체 화면을 비우지 않고 background에서 한 번만 갱신한다.
- dynamic RSC 왕복이 재방문 체감을 상쇄하는지 수치로 확인하고 결과를 PR에 기록한다.
- 당겨서 새로고침은 fresh cache가 있어도 서버를 조회한다.
- 기존 다자녀 사용자의 localStorage 선택값이 cookie로 이관된다.
- 자녀 전환 중 이름·추천·리포트가 다른 자녀와 섞이지 않는다.
- 23:59 cache가 00:00 이후 오늘 데이터로 표시되지 않는다.
- 놀이 완료 뒤 홈의 오늘 놀이 상태·연속일·달력이 최신이다.
- 리포트 확인 직후 BottomNav 툴팁이 사라진다.
- 로그아웃·계정 변경 뒤 이전 사용자 데이터가 보이지 않는다.
- unit test, lint, production build가 통과한다.
- 로컬 전후 측정 결과와 원본 조건을 구현 PR에 기록한다.

## 14. QA 체크

1. cache와 선택 자녀 cookie가 없는 상태에서 앱을 열어 기본 자녀 홈 확인
2. 기존 localStorage에 자녀 B만 있는 상태에서 최초 진입 후 B 유지·cookie 이관 확인
3. 홈→놀이→홈을 3회 반복해 스켈레톤, RSC, browser/server `/home` 수 확인
4. 30초 대기 후 탭 왕복해 기존 화면 유지와 background 갱신 확인
5. 홈 당겨서 새로고침 후 최신 응답 반영 확인
6. 다자녀 A→B→A 전환 중 이름·놀이·리포트 혼합 여부 확인
7. 놀이 시작→완료→피드백→홈 후 완료 상태 확인
8. 로드맵 milestone 변경→홈 후 진행률 확인
9. 리포트 열기→뒤로가기 후 툴팁 제거 확인
10. 23:59→00:00 또는 fake timer로 날짜 변경 후 전날 데이터 미표시 확인
11. 앱 background→foreground 후 중복 요청과 화면 깜박임 확인
12. 로그아웃 후 다른 계정 로그인 시 이전 계정 데이터 미표시 확인
13. 서버 `/home` 실패·browser retry·오프라인 복귀 동작 확인

## 15. 롤백

DB migration과 API 계약 변경이 없으므로 web 구현 PR revert로 원복한다. 단계별 문제가 있으면
route prefetch, server hydration, Query 전환, cookie 동기화를 각각 독립 커밋 단위로 되돌릴
수 있다.

다음 중 하나가 발생하면 성능 이득과 무관하게 즉시 롤백한다.

- 계정 간 또는 자녀 간 cache 데이터 노출
- 잘못된 자녀 화면이 사용자에게 표시됨
- mutation 뒤 핵심 상태가 장시간 stale
- 첫 홈 FCP/LCP 또는 앱 아이콘→홈 준비 시간이 유의미하게 악화
- RSC/server prefetch 호출이 API 부하를 감당하기 어려울 정도로 증가

## 16. 참고 자료

- [TanStack Query: Server Rendering & Hydration](https://tanstack.com/query/latest/docs/framework/react/guides/ssr)
- [TanStack Query: Next.js App Prefetching Example](https://tanstack.com/query/latest/docs/framework/react/examples/nextjs-app-prefetching)
- [Next.js: Prefetching](https://nextjs.org/docs/app/guides/prefetching)
- [Next.js: `staleTimes`](https://nextjs.org/docs/app/api-reference/config/next-config-js/staleTimes)
- [Next.js: `use cache: private`](https://nextjs.org/docs/app/api-reference/directives/use-cache-private)
