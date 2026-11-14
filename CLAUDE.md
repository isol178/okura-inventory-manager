# okura

台所の在庫係エージェント。構想・要件・設計原則は `docs/concept.md` が正典。エージェントの評価（Evals）の方針は `docs/evals.md`。コードから読み取れない技術判断は `docs/decisions/` に ADR として残す（`adr` スキルを使う）。

## コマンド

- Python は必ず uv 経由で扱う（`pip` や素の `python` は使わない）。依存の追加は `uv add`、開発用は `uv add --dev`
- 変更後は `make check` を通す（`uv lock --check` / pre-commit 全フック / pytest + カバレッジ）
- 個別に回すとき: `make fmt`・`make lint`・`make typecheck`・`make test`

## 規約

- src レイアウト（`src/okura/`）。テストは `tests/` に置く
- mypy は strict。`# type: ignore` を使うときはエラーコードを付ける
- 日付・時刻はタイムゾーン付きで扱う（ruff の DTZ ルールが有効）
- 秘密情報（API キーなど）はコミットしない。`.env` は git 管理外で、`.env.example` にキー名だけを書く
- GitHub Actions のアクションはコミット SHA で固定し、末尾にバージョンをコメントで書く（zizmor で検査）
- LLM が関わる振る舞いを足したり、プロンプト・モデルを変えたりしたら、`docs/evals.md` §2 の評価項目と評価データも合わせて更新する

## Claude Code フック（`.claude/settings.json`）

- SessionStart: `uv sync --locked` で仮想環境を揃える
- PreToolUse(Bash): `pip` や素の `python`、`--no-verify`、force push、main への直接 push・コミットを拒否し、作業ツリーを破棄する git 操作は確認を求める
- PostToolUse(Write|Edit): 編集した Python ファイルを ruff で整形・自動修正し、残った指摘を返す
- Stop: Python まわりに未コミットの変更があれば mypy と pytest を実行し、失敗していれば作業を続けさせる
