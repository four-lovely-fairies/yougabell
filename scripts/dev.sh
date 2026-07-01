#!/usr/bin/env bash
# dev.sh — 육아벨 web/api dev 서버 동시 실행
#
# 동작:
#   1. yougabell-api 를 백그라운드로 start:dev (port 3001) → logs/api.log
#   2. yougabell-web 를 백그라운드로 dev (port 3000) → logs/web.log
#   3. tail -f 로 두 로그 stream 출력
#   4. Ctrl+C 시 두 프로세스 + 자식 일괄 종료
#
# 사용법:
#   ./scripts/dev.sh                # api + web
#   ./scripts/dev.sh --web-only     # web 만 (api 는 Render 호스팅 사용 시)
#   ./scripts/dev.sh --api-only     # api 만

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$UMBRELLA_DIR/.." && pwd)"
LOG_DIR="$UMBRELLA_DIR/logs"
mkdir -p "$LOG_DIR"

API_DIR="$WORKSPACE_DIR/yougabell-api"
WEB_DIR="$WORKSPACE_DIR/yougabell-web"

RUN_API=true
RUN_WEB=true
case "${1:-}" in
  --web-only) RUN_API=false ;;
  --api-only) RUN_WEB=false ;;
  -h|--help)
    echo "사용법: $0 [--web-only|--api-only]"
    exit 0
    ;;
esac

PIDS=()
cleanup() {
  echo
  echo "→ dev 서버 종료 중..."
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  # 자식 프로세스(nest/next 의 watch 워커 등) 정리
  pkill -P $$ 2>/dev/null || true
  exit 0
}
trap cleanup INT TERM

if [ "$RUN_API" = true ]; then
  if [ ! -d "$API_DIR" ]; then
    echo "❌ $API_DIR 가 없습니다. 워크스페이스 셋업을 먼저 진행하세요." >&2
    exit 1
  fi
  echo "→ yougabell-api 시작 (port 3001, logs: $LOG_DIR/api.log)"
  (cd "$API_DIR" && pnpm start:dev >"$LOG_DIR/api.log" 2>&1) &
  PIDS+=($!)
fi

if [ "$RUN_WEB" = true ]; then
  if [ ! -d "$WEB_DIR" ]; then
    echo "❌ $WEB_DIR 가 없습니다. 워크스페이스 셋업을 먼저 진행하세요." >&2
    exit 1
  fi
  echo "→ yougabell-web 시작 (port 3000, logs: $LOG_DIR/web.log)"
  (cd "$WEB_DIR" && pnpm dev >"$LOG_DIR/web.log" 2>&1) &
  PIDS+=($!)
fi

sleep 2
echo
echo "✅ 시작됨. 아래 log stream (종료: Ctrl+C)"
echo

if [ "$RUN_API" = true ] && [ "$RUN_WEB" = true ]; then
  tail -f "$LOG_DIR/api.log" "$LOG_DIR/web.log"
elif [ "$RUN_API" = true ]; then
  tail -f "$LOG_DIR/api.log"
else
  tail -f "$LOG_DIR/web.log"
fi
