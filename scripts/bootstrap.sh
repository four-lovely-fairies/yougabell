#!/usr/bin/env bash
# bootstrap.sh — 육아밸 워크스페이스 셋업 스크립트
#
# 동작:
#   1. umbrella 레포의 부모 디렉토리(워크스페이스)를 작업 위치로 결정
#   2. 4개 서비스 레포(api/web/admin/mobile)를 병렬 클론 (이미 있으면 skip)
#   3. 워크스페이스 루트에 CLAUDE.md → yougabell/CLAUDE.md 심볼릭 링크 생성
#   4. 4개 서비스 레포에서 `pnpm install` 병렬 실행
#   5. 각 레포의 `.env.example` → `.env` 복사 (이미 있으면 skip)
#
# 사용법:
#   git clone https://github.com/four-lovely-fairies/yougabell.git
#   cd yougabell
#   ./scripts/bootstrap.sh
#
# 사전 요구사항: git, pnpm (또는 corepack), 선택적으로 gh CLI (없으면 https로 fallback)

set -euo pipefail

# ─── 위치 결정 ───────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$UMBRELLA_DIR/.." && pwd)"

# umbrella 레포 안에서 실행되는지 검증
if [ ! -f "$UMBRELLA_DIR/AGENTS.md" ] || [ "$(basename "$UMBRELLA_DIR")" != "yougabell" ]; then
  echo "✗ 이 스크립트는 yougabell(umbrella) 레포 안에서 실행해야 합니다."
  echo "  현재 위치: $UMBRELLA_DIR"
  exit 1
fi

ORG="four-lovely-fairies"
REPOS=(
  "yougabell-api"
  "yougabell-web"
  "yougabell-admin"
  "yougabell-mobile"
)

echo "▸ 워크스페이스: $WORKSPACE_DIR"
echo "▸ Umbrella    : $UMBRELLA_DIR"
echo ""

# ─── 사전 요구사항 ──────────────────────────────────────────────────────────
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "✗ 필수 도구 없음: $1"
    [ -n "${2-}" ] && echo "  설치: $2"
    return 1
  fi
}

MISSING=0
need git || MISSING=1
need pnpm "corepack enable && corepack prepare pnpm@latest --activate" || MISSING=1
[ "$MISSING" -eq 1 ] && exit 1

USE_GH=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  USE_GH=1
fi

# ─── 1) 레포 병렬 클론 ──────────────────────────────────────────────────────
echo "▸ 레포 클론 (4개 병렬)"
cd "$WORKSPACE_DIR"

for repo in "${REPOS[@]}"; do
  if [ -d "$repo/.git" ]; then
    echo "  ✓ $repo (이미 존재, skip)"
    continue
  fi
  (
    if [ "$USE_GH" -eq 1 ]; then
      gh repo clone "$ORG/$repo" >/dev/null 2>&1
    else
      git clone --quiet "https://github.com/$ORG/$repo.git"
    fi
    echo "  ✓ $repo (cloned)"
  ) &
done
wait
echo ""

# ─── 2) 워크스페이스 심볼릭 링크 ────────────────────────────────────────────
echo "▸ 워크스페이스 CLAUDE.md 심볼릭 링크"
cd "$WORKSPACE_DIR"
if [ -L "CLAUDE.md" ]; then
  TARGET="$(readlink CLAUDE.md)"
  echo "  ✓ 이미 존재: CLAUDE.md → $TARGET"
elif [ -e "CLAUDE.md" ]; then
  echo "  ⚠ CLAUDE.md가 일반 파일로 존재. 충돌 방지를 위해 건드리지 않음."
else
  ln -s "yougabell/CLAUDE.md" "CLAUDE.md"
  echo "  ✓ 생성: CLAUDE.md → yougabell/CLAUDE.md"
fi
echo ""

# ─── 3) 의존성 설치 (병렬) ──────────────────────────────────────────────────
echo "▸ pnpm install (4개 병렬)"
INSTALL_LOG="$(mktemp -d)/install"
mkdir -p "$INSTALL_LOG"

PIDS=()
for repo in "${REPOS[@]}"; do
  (
    cd "$WORKSPACE_DIR/$repo"
    if pnpm install --silent > "$INSTALL_LOG/$repo.log" 2>&1; then
      echo "  ✓ $repo"
    else
      echo "  ✗ $repo (로그: $INSTALL_LOG/$repo.log)"
      tail -10 "$INSTALL_LOG/$repo.log"
    fi
  ) &
  PIDS+=($!)
done
wait "${PIDS[@]}"
echo ""

# ─── 4) .env 셋업 ───────────────────────────────────────────────────────────
echo "▸ .env 파일 (.env.example → .env)"
for repo in "${REPOS[@]}"; do
  cd "$WORKSPACE_DIR/$repo"
  if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    cp .env.example .env
    echo "  ✓ $repo/.env 생성 (.env.example 복사)"
  elif [ -f ".env" ]; then
    echo "  ✓ $repo/.env (이미 존재, skip)"
  fi
done
cd "$WORKSPACE_DIR"
echo ""

# ─── 5) 안내 ────────────────────────────────────────────────────────────────
cat <<EOF
▸ 셋업 완료. 다음 단계:

  1. 각 레포의 .env에 실제 값 채우기:
     - yougabell-api/.env  : DATABASE_URL, DIRECT_URL, SUPABASE_*, JWT_SECRET, LLM keys
     - yougabell-web/.env  : NEXT_PUBLIC_SUPABASE_*, NEXT_PUBLIC_API_BASE_URL
     - yougabell-admin/.env: 위와 동일 + SUPABASE_SERVICE_ROLE_KEY
     - yougabell-mobile/.env: EXPO_PUBLIC_*

  2. (api 한정) Prisma 클라이언트 생성:
     cd yougabell-api && pnpm prisma:generate

  3. 개발 서버 실행 (각 터미널에서):
     cd yougabell-api    && pnpm start:dev    # :3000
     cd yougabell-web    && pnpm dev          # :3001 (PORT=3001 권장)
     cd yougabell-admin  && pnpm dev          # :3002 (PORT=3002 권장)
     cd yougabell-mobile && pnpm start        # Metro :8081

  자세한 안내: yougabell/README.md, yougabell/AGENTS.md
EOF
