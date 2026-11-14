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

branch="$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null || true)"

# git push / git commit の区間（次の ; & | まで）ごとに引数を見る。
# コマンド全体を見ると、push 以外の部分（例: git log main）にまで誤反応する。
while IFS= read -r seg; do
  [[ -z "$seg" ]] && continue
  # 語に分ける（引用符は外すだけで、厳密なシェル解析はしない）
  read -r -a words <<<"${seg//[\"\']/}"
  args=()
  ((${#words[@]} > 2)) && args=("${words[@]:2}")
  positional=()
  for w in ${args[@]+"${args[@]}"}; do
    if [[ "$w" == --force || "$w" == --force=* || "$w" =~ ^-[a-zA-Z]*f[a-zA-Z]*$ ]]; then
      decide deny "force push は禁止。必要なら --force-with-lease を作業ブランチに対してだけ使うこと。"
    fi
    [[ "$w" == -* ]] && continue
    positional+=("$w")
    if [[ "$w" == +* ]]; then
      decide deny "'+<refspec>' による force push は禁止。必要なら --force-with-lease を作業ブランチに対してだけ使うこと。"
    fi
    # refspec の宛先（: の右側、なければ全体）が main なら止める
    if [[ "${w##*:}" =~ ^(refs/heads/)?main$ ]]; then
      decide deny "main へ直接 push しない。作業ブランチを push して PR を作ること。"
    fi
  done
  # main 上で refspec を省略した push や HEAD の push は、現在のブランチ（main）を送る
  if [[ "$branch" == "main" ]]; then
    if ((${#positional[@]} <= 1)) || [[ " ${positional[*]:1:99} " =~ [[:space:]]HEAD(:|[[:space:]]) ]]; then
      decide deny "main ブランチから現在のブランチを push しようとしている。作業ブランチに切り替えてから push すること。"
    fi
  fi
done < <(grep -oE 'git[[:space:]]+push([[:space:]][^;&|]*)?' <<<"$cmd" || true)

while IFS= read -r seg; do
  [[ -z "$seg" ]] && continue
  # -n は --no-verify の短縮形（-an のようにまとめた形も含む）
  if [[ "$seg" =~ [[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$) ]]; then
    decide deny "git commit -n（--no-verify）で pre-commit を飛ばさない。フックの失敗原因を直すこと。"
  fi
done < <(grep -oE 'git[[:space:]]+commit([[:space:]][^;&|]*)?' <<<"$cmd" || true)

# 実行前の判定なので、同じコマンド内で main に切り替えてからのコミットは見えない。
# それは pre-commit の no-commit-to-branch がコミット時に止める。
if [[ "$cmd" =~ git[[:space:]]+commit ]] && [[ "$branch" == "main" ]]; then
  decide deny "main ブランチに直接コミットしない。'git switch -c <branch>' で作業ブランチを切ること。"
fi
if [[ "$cmd" =~ git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|checkout[[:space:]]+--[[:space:]]|restore[[:space:]]) ]]; then
  decide ask "作業ツリーの変更を破棄するコマンドです。実行してよいか確認してください。"
fi

exit 0
