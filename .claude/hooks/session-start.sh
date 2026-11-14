#!/usr/bin/env bash
# SessionStart: 仮想環境を uv.lock に揃えておく。
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if ! out="$(uv sync --locked --quiet 2>&1)"; then
  jq -n --arg m "uv sync --locked が失敗しました: $out" '{systemMessage: $m}'
fi
exit 0
