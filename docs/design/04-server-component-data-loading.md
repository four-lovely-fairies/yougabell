# Server Component 중심 데이터 로딩

> 작성일: 2026-09-21 · 상태: `proposed (구현 전 검토)`
> 관련 문서: [성능 기준선과 개선 실험](./02-performance-baseline.md),
> [홈 부가 요청 통합 설계(PR #30)](https://github.com/four-lovely-fairies/yougabell/pull/30),
> [홈](../features/20260510-home.md),
> [주간 리포트](../features/20260513-weekly-report.md),
> [설정](../features/20260519-settings.md)

## 0. 결정 요약

화면의 최초 데이터는 Next.js Server Component가 Nest API에서 가져온다. 브라우저가 React를
hydrate한 뒤 다시 같은 API를 호출하는 client fetch waterfall을 제거한다. 탭 이동은 우선
기본 RSC navigation으로 측정하고, route prefetch는 수치가 나쁠 때만 후속 적용한다.

TanStack Query는 이번 작업에 도입하지 않는다. Server Component와 Query가 같은 데이터의
최신성을 동시에 관리하면 탭 이동마다 server fetch가 실행되는 동안 browser Query cache는
화면을 먼저 표시할 수 없고, 두 캐시의 갱신 규칙만 중복되기 때문이다. Server Component로
옮긴 뒤 실제 측정에서 해결되지 않는 client cache 문제가 확인될 때 별도 설계로 도입한다.

```text
최초 홈
WebView → Next Server Component → Nest GET /home
        ← HTML/RSC에 포함된 홈 데이터
        → 별도 client GET /home 없이 렌더

홈 탭 클릭
→ 홈 RSC 요청
→ Next가 Nest GET /home
→ 홈 표시

후속 최적화가 필요한 경우
→ `<Link prefetch>`로 위 작업을 클릭 전에 이동
```

| 항목              | 결정                                               | 이유                                             |
| ----------------- | -------------------------------------------------- | ------------------------------------------------ |
| 데이터 소유자     | 화면별 Server Component                            | 한 데이터의 freshness 책임을 한 곳에 둠          |
| 홈 `/home`        | 홈 Server Component에서 조회해 props로 전달        | 첫 화면 client waterfall 제거                    |
| Query             | 이번 범위에서 도입하지 않음                        | Server fetch와 client cache의 중복 책임 방지     |
| Nest 응답 캐시    | 우선 `cache: "no-store"`                           | 사용자·자녀 데이터의 격리와 mutation 최신성 우선 |
| RSC 이동 최적화   | 우선 기본 navigation 측정, prefetch는 후속 판단    | 선요청 비용 없이 실제 병목부터 확인              |
| mutation 후 갱신  | 안전한 작업만 optimistic, 필요할 때만 refresh      | 과도한 추측 UI와 RSC 재요청 방지                 |
| 선택 자녀         | cookie를 영속 source of truth로 사용               | Server와 Client가 같은 값을 읽을 수 있음         |
| 기존 localStorage | 이관하지 않고 더 이상 읽거나 쓰지 않음             | 기본 자녀 선택 규칙으로 단순화                   |
| 서버 캐시         | 측정 전에는 도입하지 않음                          | 사용자별 key·무효화 복잡도를 먼저 만들지 않음    |
| 실험 기능         | `staleTimes`, `use cache: private`에 의존하지 않음 | 초기 구현을 실험 API에 묶지 않음                 |

## 1. 현재 상태와 문제

현재 `fetchServerMe()`를 사용하는 Server Component는 주로 인증·온보딩 guard만 담당한다.
홈·로드맵·주간 리포트·설정 등의 실제 화면 데이터는 Client Component가 mount된 뒤
`useEffect`에서 API를 호출하고 local state에 저장한다.

```text
문서/RSC 수신
→ client JS 다운로드·실행
→ hydration
→ Supabase browser session 조회
→ Nest API 요청
→ 데이터 화면 렌더
```

이 방식은 다음 비용을 만든다.

1. 화면 데이터 요청이 hydration 뒤에 시작되어 첫 표시가 늦다.
2. 데이터가 없는 HTML/RSC와 client loading state를 별도로 관리한다.
3. 인증 guard의 `/me`와 화면의 client `/me`가 연이어 호출될 수 있다.
4. 화면마다 `useEffect + loading + error + active flag` 코드가 반복된다.
5. mutation 뒤 local state와 서버 진실을 맞추는 규칙이 화면별로 흩어진다.

## 2. 목표와 비목표

### 2.1 목표

- 홈의 실제 데이터를 Server Component에서 받아 첫 응답에 포함한다.
- 최초 홈에서 브라우저의 중복 `/home` 요청을 제거한다.
- 홈·설정·리포트 등 주요 읽기 fetch를 단계적으로 Server Component로 이동한다.
- 기본 RSC navigation의 탭 클릭 대기와 API 호출 수를 먼저 측정한다.
- mutation별 optimistic UI·local update·`router.refresh()` 기준을 명확히 한다.
- RSC, Next→Nest API, 화면 표시 시간을 분리해 측정한다.
- 각 단계가 독립적으로 revert 가능하게 한다.

### 2.2 비목표

- TanStack Query 또는 SWR 도입
- BottomNav route prefetch 적용
- Next 서버에 인증 사용자 데이터를 장기 저장하는 shared cache
- `use cache: private`, experimental `staleTimes`, Cache Components 도입
- `/mobile-entry` hard reload 개선
- 추천 놀이·연속일 계산 자체의 API/DB 최적화
- 모든 화면을 한 커밋에서 Server Component로 변경
- 모달·드롭다운·입력값 같은 local UI state의 서버 이전
- 이번 작업만으로 운영 리텐션 개선을 입증

## 3. 데이터 소유권 원칙

한 API 응답은 한 계층이 freshness를 주도한다.

### 3.1 Server Component 소유 데이터

다음 조건에 해당하면 Server Component에서 조회한다.

- route 진입에 반드시 필요한 본문 데이터
- 첫 화면 표시 속도에 직접 영향을 주는 데이터
- URL과 인증 session으로 조회 대상을 결정할 수 있는 데이터
- mutation 뒤 route refresh로 다시 가져와도 되는 데이터
- SEO보다 WebView 첫 렌더와 waterfall 제거가 중요한 데이터도 포함

홈 `/home`, 주간 리포트 본문, 설정의 사용자 정보가 우선 후보다.

### 3.2 Client Component 소유 데이터

다음은 client에 둔다.

- 모달 열림·닫힘, 드롭다운, 입력 중인 값
- 타이머와 애니메이션 상태
- 채팅 streaming 중간 상태
- optimistic UI의 임시 상태
- 브라우저·WebView API가 필요한 상태

Server Component가 내려준 본문 데이터를 Client Component가 props로 받아 상호작용하는 것은
가능하다. 다만 같은 데이터를 mount 직후 client에서 다시 fetch하지 않는다.

### 3.3 Query를 미루는 이유

Server Component는 최초 문서뿐 아니라 App Router의 후속 navigation에서도 서버에서
실행된다. 홈 Server Component가 매번 `GET /home`을 실행한다면 browser Query cache가 있어도
홈 component는 RSC가 도착하기 전에 mount될 수 없다.

```text
Query cache 있음
→ 홈 탭 클릭
→ 홈 RSC 대기
→ Next→Nest GET /home 대기
→ RSC 도착 후 HomeDashboard mount
```

이 구조에서 Query는 mutation·background refetch 기능은 제공하지만 탭 클릭부터 화면 전환까지
걸리는 서버 대기를 제거하지 못한다. 우선 Server Component 전환 자체의 수치를 확인하고,
Query가 해결할 구체적인 잔여 문제가 생길 때 도입한다.

## 4. 홈 Server Component 전환

### 4.1 서버 API helper

browser용 `authHeaders()`는 Supabase browser session에 의존하므로 Server Component에서
재사용하지 않는다. server-only helper를 별도로 만든다.

```typescript
type ServerHomeResult = {
  data: HomeDashboard;
  selectionResetRequired: boolean;
};

export async function fetchServerHome(
  childId?: string | null,
): Promise<ServerHomeResult> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) throw new UnauthorizedError();

  const response = await fetch(homeUrl(childId), {
    headers: { Authorization: `Bearer ${session.access_token}` },
    cache: "no-store",
  });

  return parseServerHomeResponseWithDefaultRetry(response);
}
```

요구사항:

- `server-only` 경계로 client bundle import를 차단한다.
- `measureServer("server_home", ...)`로 Nest 응답 시간·status·request ID를 기록한다.
- 401/403은 기존 auth routing과 일관되게 처리한다.
- 선택 자녀 404는 기본 자녀로 한 번만 재시도하고 `selectionResetRequired`를 함께 반환한다.
  Server Component에서는 cookie를 삭제할 수 없으므로 client bridge가 이 신호를 받아 기존
  cookie를 정리한다.
- 같은 서버 렌더에서 중복 호출될 가능성이 있으면 React `cache()`로 요청 단위만 dedupe한다.
- 장기 server cache로 사용하지 않는다.

`no-store`는 Server Component가 cache를 사용할 수 없어서가 아니다. 이번 1차 전환에서는 다음
이유로 API 응답을 의도적으로 저장하지 않는다.

- `/home`은 로그인 사용자와 선택 자녀에 따라 달라지는 개인화 응답이다.
- 놀이 완료·기분 기록·자녀 설정 등 여러 mutation이 응답을 바꾼다.
- 아직 사용자·자녀별 cache key와 mutation별 무효화 정책을 정의하지 않았다.
- RSC 전환과 server cache 도입을 동시에 하면 성능·stale 문제의 원인을 분리하기 어렵다.

따라서 이번에는 매 RSC 생성 시 Nest의 최신 응답을 받고, client waterfall 제거 효과만 먼저
검증한다. 측정에서 `server_home`이 주요 병목으로 남을 때 사용자·자녀·날짜를 포함한 key와
tag 무효화 정책을 설계한 뒤 server cache를 별도 실험한다. 인증 응답을 사용자 구분 없는
shared cache에 저장하지 않는다.

### 4.2 홈 page

홈 page가 인증 확인과 본문 데이터를 준비해 Client Component에 전달한다.

```tsx
export default async function HomePage() {
  const [me, requestedChildId] = await Promise.all([
    fetchServerMe(),
    readSelectedChildCookie(),
  ]);

  if (me && !me.onboardedAt) {
    redirect("/onboarding/intro");
  }

  const homeResult = await fetchServerHome(requestedChildId);

  return (
    <HomeDashboard
      initialHome={homeResult.data}
      selectionResetRequired={homeResult.selectionResetRequired}
    />
  );
}
```

실제 구현에서는 상위 layout의 `fetchServerMe()`와 중복되는지 확인하고 request-scoped
`cache()`로 한 서버 렌더 안의 `/me`를 한 번만 호출한다. 인증되지 않은 상태에서 `/home`을
먼저 호출하지 않는다.

### 4.3 HomeDashboard

`HomeDashboard`는 `useEffect`의 최초 `loadHomeDashboard()`를 제거하고 `initialHome`을 서버
진실로 사용한다. 전체 응답을 `useState(initialHome)`으로 단순 복사하지 않는다. Client
Component가 route refresh 뒤에도 유지되면 `useState`의 초기값은 새 props로 자동 갱신되지
않기 때문이다.

```tsx
export function HomeDashboard({
  initialHome,
  selectionResetRequired,
}: {
  initialHome: HomeDashboardData;
  selectionResetRequired: boolean;
}) {
  const [home, updateHomeOptimistically] = useOptimistic(
    initialHome,
    reduceHomeOptimisticAction,
  );
  useSelectedChildCookieRepair(
    selectionResetRequired,
    initialHome.selectedChild.id,
  );
  // 모달·드롭다운처럼 서버 데이터가 아닌 UI 상태만 useState로 관리
}
```

- 최초 render에서 스켈레톤을 표시하지 않는다.
- mount 직후 browser `/home`을 다시 호출하지 않는다.
- Server Component props와 별도로 같은 전체 응답을 장기 client cache로 복제하지 않는다.
- 자녀 전환은 cookie를 먼저 갱신한 뒤 `router.refresh()`로 새 Server Component 데이터를
  받는다. 전환 중에는 이전 자녀 데이터를 새 자녀 데이터로 표시하지 않는다.
- 당겨서 새로고침은 `useTransition` 안에서 `router.refresh()`를 사용하고 기존 화면을 유지한
  채 진행 상태만 표시한다.

## 5. 선택 자녀 cookie

Server Component는 localStorage를 읽을 수 없으므로 선택 자녀의 영속 source of truth를
cookie로 통일한다.

- cookie에는 opaque child ID만 저장한다.
- production에서는 `Secure`, 모든 환경에서 `SameSite=Lax`, `Path=/`를 사용한다.
- JavaScript에서 자녀를 변경해야 하므로 HttpOnly는 사용하지 않는다.
- 화면 내 현재 선택은 React state로 관리하되 영속값은 cookie 하나만 사용한다.
- 로그아웃·계정 변경·선택 자녀 삭제 시 cookie를 제거한다.

### 5.1 cookie가 없는 사용자

기존 `home:selected-child-id` localStorage 값은 이관하지 않고 새 코드에서 더 이상 읽거나 쓰지
않는다. cookie가 없는 사용자는 신규 로그인 사용자와 같은 흐름을 사용한다.

1. Server Component가 `childId` 없이 `/home`을 요청한다.
2. API가 첫 번째 기본 활성 자녀를 선택한다.
3. 화면은 해당 자녀의 응답으로 바로 렌더한다.
4. Client Component가 응답의 자녀 ID를 cookie에 저장한다.
5. 이후 요청부터 Server Component와 Client Component가 같은 cookie를 사용한다.

기존 사용자가 전에 다른 자녀를 선택했더라도 최초 한 번 기본 자녀로 돌아가는 것을 허용한다.
localStorage migration gate나 두 저장소 동기화 로직은 만들지 않는다.

## 6. RSC route prefetch는 후속 후보

이번 구현에서는 BottomNav의 `router.push` 동작을 route prefetch 목적으로 바꾸지 않는다.
홈 Server Component 전환 전후의 기본 navigation을 먼저 측정한다.

```text
홈 탭 클릭
→ 홈 RSC 요청
→ Next→Nest GET /home
→ 홈 표시
```

다음 조건이 확인될 때만 별도 실험으로 `<Link prefetch={true}>` 또는
`router.prefetch("/")`를 추가한다.

- 홈 탭 클릭→표시 P75가 사용자 체감상 느림
- 그 지연의 대부분이 RSC와 `server_home` 대기임
- 선요청으로 늘어나는 API 호출량을 감당할 수 있음
- 홈을 실제로 누르는 비율이 높아 prefetch 낭비가 작음

prefetch는 API 요청을 제거하지 않고 클릭 전 background로 옮기는 최적화다. 적용할 때는 현재
화면 표시 시간, 홈 클릭 시간, Next→Nest 호출 증가량을 함께 비교한다.

BottomNav를 공유하는 최상위 탭들을 `(tabs)` Route Group으로 정리하는 작업도 prefetch 도입에
필수는 아니다. 실제 navigation UI 중복이나 layout 교체 문제가 확인될 때 별도 범위로 다룬다.

## 7. Mutation과 갱신

이번 단계에서는 기존 client→Nest mutation 경로를 유지한다. Query mutation을 도입하지 않고
각 동작의 pending/error/optimistic state를 해당 Client Component에서 관리한다.

```text
사용자 동작
→ 안전하고 되돌리기 쉬운 작업이면 즉시 optimistic 반영
→ Nest mutation 전송
→ 성공: mutation 응답으로 충분하면 그대로 종료
→ 성공: 파생 서버 데이터가 바뀌면 필요한 route만 router.refresh()
→ 실패: optimistic state를 썼다면 원복하고 오류 표시
```

| 작업                     | optimistic 적용                                        | 성공 후 처리                                       |
| ------------------------ | ------------------------------------------------------ | -------------------------------------------------- |
| 알림 한 건/전체 읽기     | 적용. count/list를 정확히 되돌릴 수 있음               | 응답으로 확정 가능하면 refresh 생략                |
| 기분 기록                | 중복 제출을 막고 원복 가능할 때만 적용                 | 다른 파생 데이터가 바뀔 때만 refresh               |
| 자녀 전환                | 홈 본문은 추측 갱신하지 않음. pending UI만 표시        | cookie 저장 후 `router.refresh()`                  |
| 놀이 완료·피드백         | 연속일·달력·리포트를 추측하지 않고 완료 화면만 유지    | 서버 성공 뒤 이동한 홈 RSC에서 최신 데이터 조회    |
| 리포트 viewed            | 툴팁 제거는 적용하고 실패 시 복원                      | 응답으로 확정 가능하면 refresh 생략                |
| 자녀 생성·삭제·순서 변경 | 기본적으로 적용하지 않음                               | 서버 성공 후 `router.refresh()`                    |
| 설정 변경                | 서버가 값을 정규화할 수 있으므로 성공 전 확정하지 않음 | 응답으로 충분하면 local 반영, 아니면 route refresh |

`router.refresh()`는 browser history를 추가하지 않고 현재 route의 Server Component payload를
다시 요청한다. 기존 Client Component state를 무조건 모두 초기화한다고 가정하지 말고 화면별
QA를 수행한다. mutation마다 무조건 호출하지 않는다. 현재 화면에 필요한 변경 결과가 mutation
응답에 전부 있고 다른 파생 데이터가 바뀌지 않았다면 local state만 확정하는 편이 요청 수와
화면 안정성에 유리하다.

`router.refresh()`는 브라우저 전체 새로고침이 아니다. 새 RSC payload를 기존 화면에 merge하고,
영향받지 않은 Client Component state와 scroll 같은 browser state는 유지한다. 따라서 정상
구현에서는 흰 화면이나 전체 스켈레톤으로 바뀌는 깜빡임이 없어야 한다. refresh 직전에 기존
본문을 비우거나 route 전체에 새 `key`를 주지 않고, `useTransition`으로 기존 본문을 유지하면서
버튼이나 작은 progress indicator만 pending 상태로 표시한다.

### 7.1 `router.refresh()`와 server revalidation

두 방식은 대체 관계가 아니라 역할이 다르다.

| 방식                              | 역할                                                                | 현재 단계의 판단                                |
| --------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------- |
| `router.refresh()`                | browser가 현재 route의 새 RSC를 요청해 화면을 최신 서버 상태와 맞춤 | `no-store`에서도 동작. 필요한 mutation에만 사용 |
| `revalidatePath()`                | server에서 특정 page/layout의 cached data를 무효화                  | 현재 핵심 API가 `no-store`라 얻는 이득이 없음   |
| `revalidateTag()` / `updateTag()` | tag가 붙은 cached data를 정밀하게 stale/expire 처리                 | 향후 server cache를 도입할 때 검토              |

`revalidatePath()`나 `revalidateTag()` 자체는 사용자가 보는 화면을 optimistic하게 바꾸지 않는다.
즉각적인 UX는 Client Component의 local state 또는 `useOptimistic`이 담당한다. 반대로
`router.refresh()`는 현재 화면을 실제로 다시 요청하므로 구현은 단순하지만 RSC와 Nest 호출 비용이
든다.

`revalidatePath()`는 Client Component에서 직접 호출할 수 없고 Server Function 또는 Route
Handler가 필요하다. Server Function에서 실행하면 사용자가 그 path를 보고 있을 때 UI 갱신까지
연결할 수 있지만, 현재의 browser→Nest mutation을 Next Server Action으로 감싸는 구조 변경이
추가된다. 현재 mutation은 browser에서 Nest로 직접 보내고 API fetch도 `no-store`이므로, 1차
구현에서는 `router.refresh()`가 개발 복잡도가 낮고 결과도 명확하다. 단, 즉시 갱신이 필요 없는
작업에는 이마저 생략한다.

향후 mutation을 Server Action/Route Handler로 옮기고 server cache를 켜면 넓은 path 단위
`revalidatePath()`보다 데이터별 tag 무효화를 우선 검토한다. 사용자가 방금 쓴 값을 즉시 읽어야
하는 Server Action에는 `updateTag()`, stale-while-revalidate가 허용되는 데이터에는
`revalidateTag(tag, "max")`가 더 구체적이다.

## 8. 후속 화면 이전

홈에서 패턴과 성능 효과를 확인한 뒤 화면별로 적합성을 다시 확인하고 독립 이전한다. 아래
화면들은 모두 최초 읽기를 Server Component로 옮기기 좋은 후보이지만, 화면 전체를 Server
Component로 바꾼다는 뜻은 아니다. 사용자 상호작용·폼·timer·streaming은 Client Component에
남긴다.

### 8.1 설정 `/me`

현재 의미의 “설정 화면 사이에서 반복되는 `/me`”는 프로필·자녀·관심사·알림 설정 페이지가
각자 mount될 때 동일한 사용자·자녀 정보를 client에서 다시 읽는 상황을 말한다.

먼저 설정의 실제 호출 수를 확인한다. 여러 설정 페이지가 같은 전체 `/me`를 필요로 하면
Query를 바로 도입하지 않고 다음 순서로 단순화한다.

1. 설정 Server Component 또는 설정 공통 layout에서 `/me`를 조회한다.
2. 여러 설정 페이지에 정말 공통인 최소 데이터만 공통 layout/provider로 전달한다.
3. 특정 페이지 전용 데이터는 해당 page Server Component에서 조회한다.
4. 설정 mutation 성공 뒤 해당 route를 refresh한다.

공통 layout에는 공통 데이터만 둔다. 홈 데이터처럼 특정 화면 전용 응답을 반복 fetch 방지
목적으로 끌어올리지 않는다.

### 8.2 주간 리포트와 로드맵

- route 진입에 필요한 본문은 page Server Component에서 조회한다.
- URL의 report ID·선택 자녀 cookie를 서버 조회 입력으로 사용한다.
- viewed·milestone mutation은 client 상호작용을 유지하고 성공 뒤 refresh한다.
- 홈 응답에 이미 포함된 리포트 상태를 다른 route의 숨은 cache로 간주하지 않는다.

주간 리포트는 URL 기반의 읽기 중심 본문이라 우선순위가 높다. 로드맵도 최초 목록은 좋은
후보지만 milestone 변경이나 펼침 상태 등 상호작용은 client에 남긴다. 설정은 사용자·자녀의
안정적인 초기 데이터가 많아 적합하지만, 입력 폼은 client에 남긴다. 따라서 설정→리포트→로드맵
순서는 확정된 일괄 변환 순서가 아니라 홈 결과 뒤 실제 중복 요청 수·화면 복잡도·기대 효과로
조정하는 후보 순서다.

### 8.3 채팅과 미션

- 채팅 history의 최초 읽기는 Server Component 이전 후보지만 streaming 대화 상태는 client에
  둔다.
- 미션 intro의 최초 데이터는 Server Component 후보지만 timer·effect·feedback의 진행 상태는
  client에 둔다.
- 진행 중인 사용자 입력이나 타이머를 `router.refresh()`가 훼손하지 않는지 별도 검증한다.

## 9. TanStack Query 후속 도입 기준

다음 문제가 Server Component 전환 이후에도 실제 측정으로 남을 때만 Query 설계를 다시 연다.

- RSC가 준비될 때까지 기존 데이터를 먼저 보여줘야 하는 요구가 큼
- 같은 응답을 서로 독립적인 여러 route가 자주 재사용함
- background refetch와 stale-while-revalidate가 UX에 필수임
- pagination·infinite query·요청 dedupe가 반복 구현되고 있음
- 여러 mutation의 optimistic update와 rollback이 복잡해짐
- 탭 재방문에서 RSC를 기다리는 UX가 반복되고 이전 데이터를 즉시 보여줄 필요가 큼

Query를 도입할 때는 데이터별 소유권을 다시 정한다.

```text
Server 소유 데이터
→ Server Component fetch + RSC refresh

Query 소유 데이터
→ route RSC는 가벼운 shell
→ browser Query cache 표시와 refetch

SSR prefetch + Query 공동 소유
→ 최초 표시 이득과 후속 RSC 중복 비용을 측정해 명시적으로 허용한 경우만 사용
```

“모든 서버 상태는 Query” 또는 “모든 fetch는 Server Component”를 전역 규칙으로 만들지 않는다.

## 10. 오류·인증·개인정보

- Server Component API helper는 token과 응답 본문을 log하지 않는다.
- 성능 이벤트에는 user ID, child ID, 이름, access token을 넣지 않는다.
- 인증 실패는 기존 `/mobile-entry`·로그인 복구 흐름과 일관되게 처리한다.
- server fetch 실패는 route `error.tsx` 또는 화면별 오류 UI로 복구한다.
- 다른 계정 로그인은 full reload 또는 명시적인 router/cache 초기화 경로로 이전 RSC 상태를
  제거한다.
- cookie에는 선택 자녀 ID 외 개인정보를 저장하지 않는다.

## 11. 구현 순서와 커밋 단위

1. `refactor(web)`: server-only API helper와 request 단위 계측·오류 처리
2. `feat(web)`: 선택 자녀 cookie source of truth와 기본 자녀 fallback
3. `refactor(web)`: 홈 `/home` fetch를 Server Component로 이동하고 client 최초 fetch 제거
4. `perf(web)`: 기본 탭 navigation의 RSC/API 호출과 화면 표시 시간 계측
5. `refactor(web)`: mutation별 selective optimistic state와 refresh 계약 정리
6. `test(web)`: 최초 진입·탭 복귀·자녀 전환·mutation·오류 통합 테스트
7. 홈 효과 확인 뒤 설정·리포트·로드맵의 적합성과 우선순위를 각각 평가해 이전

각 단계는 build와 QA를 통과한 뒤 다음 단계로 진행하고 독립적으로 revert 가능하게 한다.
API 계약과 DB migration은 예정하지 않는다. mobile 변경도 예정하지 않는다.

## 12. 성능 측정

변경 전 commit과 변경 후 commit을 같은 local production build, 같은 배포 API/DB, 같은 Chrome
profile·viewport·network 조건에서 비교한다. 준비 실행 1회를 제외하고 시나리오별 10회를
실행한다.

### 12.1 최초 홈

```text
새 문서/WebView 시작 → 홈의 실제 콘텐츠 표시
```

- 앱 계측: `native_shell_home`, `native_home_ready`
- 웹 계측: FP/FCP/LCP, `screen_first_data`
- Next 서버: `server_me`, `server_home`
- browser Network: client `/home` 중복 요청 여부
- RSC/HTML payload와 client JS 변화량

### 12.2 탭 복귀

```text
홈 → 로드맵 또는 리포트 → 홈
```

- 홈 탭 클릭→실제 홈 콘텐츠 표시
- `?_rsc=` 요청 수·시간·transfer size
- Next→Nest `server_home` 호출 수·시간
- 같은 시나리오 반복 시 Router Cache 재사용 여부와 요청 수 변화

### 12.3 mutation

- 알림 읽음·기분 기록·자녀 전환 후 즉시 UI 반영 시간
- `router.refresh()` RSC와 Next→Nest API 시간
- optimistic state 원복·중복 요청·화면 깜박임
- refresh 중 기존 본문 유지와 전체 화면 깜빡임 여부
- 놀이 완료 뒤 홈의 완료 상태·연속일·달력 일치

### 12.4 완료 조건

- 최초 홈에서 HomeDashboard mount 뒤 browser `/home` 요청이 없다.
- 기존 client waterfall 대비 첫 홈 `screen_first_data`와 LCP가 개선되거나 유의미하게 악화되지
  않는다.
- 기본 탭 복귀에서 RSC와 `server_home` 호출 수·시간을 변경 전과 비교할 수 있다.
- RSC cache miss에서는 RSC와 `/home` 요청이 한 번씩만 발생하고 browser의 별도 `/home`
  요청은 없다.
- mutation과 자녀 전환 뒤 최신 서버 상태가 보인다.
- `router.refresh()` 중 기존 본문이 유지되고 흰 화면·전체 스켈레톤 깜빡임이 없다.
- 다자녀 데이터나 다른 계정 데이터가 섞이지 않는다.
- server error·offline·401에서 기존 복구 흐름이 유지된다.
- lint, unit test, production build가 통과한다.
- 측정 조건과 원본 결과를 구현 PR에 기록한다.

로컬 5~10회 표본은 방향과 요청 수 검증용이다. 운영 P75/P95와 리텐션 결론에는 배포 후
실사용자 표본이 필요하다.

## 13. QA 체크

1. 신규 상태에서 앱 실행 후 기본 자녀 홈이 스켈레톤 없이 표시되는지 확인
2. cookie 없는 기존 사용자가 localStorage와 무관하게 기본 자녀로 진입하는지 확인
3. 홈→로드맵→홈을 3회 반복해 RSC와 `server_home` 요청 수 확인
4. 홈→리포트→홈을 반복해 동일하게 확인
5. 자녀 A→B→A 전환 중 이름·추천·리포트가 섞이지 않는지 확인
6. 알림·리포트 viewed 실패 시 optimistic UI가 원복되는지 확인
7. 자녀 변경·놀이 완료처럼 추측 갱신하지 않는 작업의 pending UI와 최신 결과 확인
8. 불필요한 mutation 뒤 `router.refresh()`가 실행되지 않는지 확인
9. 놀이 완료→홈 이동 후 완료 상태·연속일·달력 확인
10. 앱 background→foreground와 날짜 변경 후 홈 최신성 확인
11. server `/home` 실패·401·offline 후 오류와 재시도 확인
12. 로그아웃 후 다른 계정 로그인 시 이전 RSC/화면 데이터 미노출 확인

## 14. 롤백

DB migration과 API 계약 변경이 없으므로 web 구현 PR revert로 원복한다. server helper,
선택 자녀 cookie, 홈 Server Component 전환, mutation refresh를 독립 커밋으로 두어 문제가 생긴
단계만 되돌릴 수 있게 한다.

다음 중 하나가 발생하면 성능 이득과 무관하게 즉시 롤백한다.

- 계정 간 또는 자녀 간 데이터 노출
- 잘못된 자녀 화면 표시
- mutation 뒤 핵심 상태가 장시간 stale
- 최초 홈 FCP/LCP 또는 앱 아이콘→홈 준비 시간의 유의미한 악화

## 15. 참고 자료

- [Next.js: Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components)
- [Next.js: Linking and Navigating](https://nextjs.org/docs/app/getting-started/linking-and-navigating)
- [Next.js: Prefetching](https://nextjs.org/docs/app/guides/prefetching)
- [Next.js: Route Groups](https://nextjs.org/docs/app/getting-started/project-structure#route-groups-and-private-folders)
- [Next.js: `router.refresh`](https://nextjs.org/docs/app/api-reference/functions/use-router)
- [Next.js: `revalidatePath`](https://nextjs.org/docs/app/api-reference/functions/revalidatePath)
- [Next.js: `revalidateTag`](https://nextjs.org/docs/app/api-reference/functions/revalidateTag)
- [Next.js: `updateTag`](https://nextjs.org/docs/app/api-reference/functions/updateTag)
- [TanStack Query: Advanced Server Rendering](https://tanstack.com/query/latest/docs/framework/react/guides/advanced-ssr)
