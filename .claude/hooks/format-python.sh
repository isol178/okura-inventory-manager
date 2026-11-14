#!/usr/bin/env bash
# PostToolUse(Write|Edit): 編集した Python ファイルを ruff で整形・自動修正し、残った指摘を Claude に返す。
set -uo pipefail

file="$(jq -r '.tool_response.filePath // .tool_input.file_path // ""')"
[[ "$file" =~ \.pyi?$ ]] || exit 0
[[ -f "$file" ]] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
uv run --frozen ruff format --force-exclude --quiet "$file" >/dev/null 2>&1
if ! out="$(uv run --frozen ruff check --fix --force-exclude --quiet "$file" 2>&1)"; then
  printf 'ruff が自動修正できない指摘があります（%s）:\n%s\n' "$file" "$out" >&2
  exit 2
fi
exit 0
