#!/usr/bin/env bash
# Stop: Python まわりに未コミットの変更があれば mypy と pytest を回し、失敗していれば作業を続けさせる。
set -uo pipefail

input="$(cat)"
# Stop フックが再起動させた後の停止では再チェックしない（無限ループ防止）
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
changed="$(git status --porcelain --untracked-files=all -- '*.py' '*.pyi' pyproject.toml uv.lock 2>/dev/null)"
[[ -n "$changed" ]] || exit 0

fail=""
if ! out="$(uv run --frozen mypy 2>&1)"; then
  fail+=$'## mypy\n'"$(tail -n 30 <<<"$out")"$'\n'
fi
if ! out="$(uv run --frozen pytest -q -x --no-header 2>&1)"; then
  fail+=$'## pytest\n'"$(tail -n 40 <<<"$out")"$'\n'
fi
[[ -z "$fail" ]] && exit 0

jq -n --arg r "型チェックかテストが失敗しています。修正してから終了してください。"$'\n'"$fail" \
  '{decision: "block", reason: $r}'
exit 0
