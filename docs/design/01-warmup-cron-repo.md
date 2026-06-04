# 01 — API 웜업 크론 레포 (`yougabell-cron`)

> 인프라 결정 문서. 임시(stopgap) 성격 — 더 나은 크론 대안 도입 시 폐기 예정.
> 상위 룰: 워크스페이스 [`AGENTS.md`](../../AGENTS.md), [`docs/AGENTS.md`](../AGENTS.md).

## 배경 / 문제

- **API 호스팅(Render Free)** 은 idle 시 sleep → 첫 호출 cold start 30초 안팎.
- 기존 웜업을 **GitHub Actions cron**(`*/5`)으로 돌렸으나 **스케줄이 불안정**(관측상 1~4시간씩 건너뜀). 사용자별 정시 미션 푸시 알림이 이 cron에 의존하면 알림 누락 위험.
- 안정적인 5분 주기 트리거가 필요. Cloud Scheduler / Cloud Run / Render 유료 등 정식 대안 검토 전까지의 **임시 수단**이 필요하다.

## 컨셉 — "웜업과 실제 일을 하나의 5분 잡으로"

미션 푸시 알림 디스패치는 이미 **5분 단위**로 동작한다 (`*/5 * * * *`). 그렇다면:

- **별도 헬스체크 웜업을 또 만들 필요가 없다.**
- 5분마다 **미션 알림 디스패치 엔드포인트를 호출**하면 그 요청 자체가
  1. 잠든 API 서버를 깨우고(웜업),
  2. 동시에 그 시점에 도래한 사용자별 미션 알림을 발송한다.
- 즉 **5분 단위 잡 하나**가 웜업 + 실제 발송을 겸한다. 헬스체크 1회를 절약.

```
[개발자 PC] --5분마다 POST--> /internal/notifications/dispatch-play-reminders
                               ├─ (잠들어 있었으면) cold start 깨어남 = 웜업
                               └─ windowMinutes 내 도래한 미션 알림 발송
```

## 대상 엔드포인트 (anchor: `yougabell-api`)

`notifications/notifications.internal.controller.ts`

| 항목     | 값                                                                        |
| -------- | ------------------------------------------------------------------------- |
| Method   | `POST`                                                                    |
| Path     | `/internal/notifications/dispatch-play-reminders`                         |
| 인증     | 헤더 `x-cron-secret: <NOTIFICATION_CRON_SECRET>` (서버 env와 일치해야 함) |
| Body     | `{ "windowMinutes": 10 }` (`now?`, `dryRun?` 옵션)                        |
| 부수효과 | cold start 깨움(웜업) + 도래 미션 알림 발송                               |

> 주간 리포트 알림(`dispatch-weekly-report-notifications`)은 **월요일 한정** 스케줄이라 본 잡과 분리.
> 본 5분 잡이 서버를 깨워 두므로 주간 잡의 cold start도 함께 완화된다. (주간은 기존 GH Actions 유지 또는 추후 동일 방식 추가 검토.)

## 레포 — `four-lovely-fairies/yougabell-cron`

- **성격**: 임시. 개발자 로컬 PC에서 상시 실행. 정식 대안 도입 시 archive/삭제.
- **스택**: Node 24 + TypeScript(tsx, 빌드 없음) + `node-cron`. 의존성 최소.
- **동작**: 시작 즉시 1회 호출(웜업) 후 `*/5 * * * *` 주기로 디스패치 호출. 결과 로깅.
- **설정**(`.env`): `API_URL`, `NOTIFICATION_CRON_SECRET`, `WINDOW_MINUTES`, `CRON_SCHEDULE`.
- **상시 실행**: `pnpm start`(포그라운드) 또는 pm2 / nohup / launchd 등으로 백그라운드 유지(README 안내).

## 한계 · 폐기 조건

- 개발자 PC가 꺼지거나 네트워크가 끊기면 멈춘다(임시 수단의 한계).
- **폐기 조건**: Cloud Scheduler / Cloud Run(무료 티어) / Render 유료 등 **상시 가동 트리거**가 도입되면 본 레포는 중단·archive.
- 그 시점에 미션/주간 알림 디스패치 트리거를 정식 인프라로 이관한다.
