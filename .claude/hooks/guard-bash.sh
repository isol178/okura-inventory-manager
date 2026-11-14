#!/usr/bin/env bash
# PreToolUse(Bash): プロジェクトの規約に反するコマンドを実行前に止める。
set -euo pipefail

cmd="$(jq -r '.tool_input.command // ""')"

decide() { # $1: deny | ask, $2: 理由
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# コマンドの先頭（行頭・; & | ( の直後）にある語だけを見る
head='(^|[;&|(]|\$\()[[:space:]]*(sudo[[:space:]]+)?'

if [[ "$cmd" =~ ${head}(pip3?|python3?[[:space:]]+-m[[:space:]]+pip)[[:space:]]+(install|uninstall) ]]; then
  decide deny "pip は使わない。依存の追加は 'uv add <pkg>'（開発用は 'uv add --dev <pkg>'）、削除は 'uv remove <pkg>' を使うこと。"
fi
if [[ "$cmd" =~ ${head}python3?([[:space:]]|$) ]]; then
  decide deny "素の python は使わない。'uv run python ...' か 'uv run <tool>' を使うこと。"
fi
if [[ "$cmd" =~ git[[:space:]].*--no-verify ]]; then
  decide deny "--no-verify で pre-commit を飛ばさない。フックの失敗原因を直すこと。"
fi
if [[ "$cmd" =~ git[[:space:]]+push ]]; then
  if [[ "$cmd" =~ [[:space:]](--force|-f)([[:space:]]|$) ]]; then
    decide deny "force push は禁止。必要なら --force-with-lease を作業ブランチに対してだけ使うこと。"
  fi
  if [[ "$cmd" =~ [[:space:]](main|HEAD:main|refs/heads/main)([[:space:]]|$) ]]; then
    decide deny "main へ直接 push しない。作業ブランチを push して PR を作ること。"
  fi
fi
if [[ "$cmd" =~ git[[:space:]]+commit ]] \
  && [[ "$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null)" == "main" ]]; then
  decide deny "main ブランチに直接コミットしない。'git switch -c <branch>' で作業ブランチを切ること。"
fi
if [[ "$cmd" =~ git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|checkout[[:space:]]+--[[:space:]]|restore[[:space:]]) ]]; then
  decide ask "作業ツリーの変更を破棄するコマンドです。実行してよいか確認してください。"
fi

exit 0
