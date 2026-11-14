---
status: "proposed"
date: 2026-11-14
decision-makers: [Haruki Inaba, Agent (via Claude Code)]
consulted: []
informed: []
---

# 0001. LLM の呼び出しを記録・再生できる単一のクライアントに通す

<!-- 起票シグナル: S3,S4 -->

## Context and Problem Statement

エージェントの振る舞いを出荷前に評価するには、同じ入力に対して同じ LLM 応答を再現でき、どのモデル・どのプロンプトで得た応答かを後から特定できる必要がある（出所: `docs/evals.md` §3・§5）。LLM の応答は実行ごとに揺らぎ、実際に API を呼ぶたびにコストがかかる（1日のコスト上限: `docs/concept.md` §8）。エージェントのループを書き始めると LLM の呼び出し箇所が散らばり、あとから記録・再生の仕組みを差し込むのが難しくなるため、ループを書く前にこの判断を固定する。

## Decision Drivers

- 回帰テストを決定的に実行し、`make check` と CI に含めたい（`docs/evals.md` §5）
- 評価のたびに API を呼ぶとコストがかかり、1日の上限を圧迫する（`docs/concept.md` §8）
- 評価結果の差が、モデルの変更によるものかプロンプトの変更によるものかを区別したい（`docs/evals.md` §3）
- ツール呼び出しの記録（`tool_calls`）と LLM 応答の記録を、同じ実行に紐づけて判定したい（`docs/concept.md` §6）

## Considered Options

- 記録・再生の機能を持つ単一の LLM クライアントを自作し、すべての呼び出しをそこに通す
- SDK を呼び出し箇所ごとに直接使い、テストでは HTTP 通信を録画・再生する
- 記録・再生は持たず、評価は毎回実際に API を呼ぶ

## Decision Outcome

Chosen option: "記録・再生の機能を持つ単一の LLM クライアントを自作し、すべての呼び出しをそこに通す", because 再生による決定的な回帰テストと、モデル ID・プロンプトの版の記録を一か所で保証でき（to achieve 評価の再現性とコストの抑制）、そのために SDK の上に薄い層を1つ持ち、その保守を引き受ける（accepting 自作部分の保守コスト）。

- クライアントは「記録」「再生」「通常」の3つのモードを持つ。再生モードでは API を呼ばず、記録済みの応答を返す
- 記録には、モデル ID、プロンプトの版（リポジトリ内のプロンプトファイル一式のハッシュ。定義は `docs/evals.md` §3）、リクエスト、応答、トークン数、コストを含める
- 実データを入力にした記録は git の管理外に置き、リポジトリには作った例を入力にした記録だけをコミットする（`docs/evals.md` §4）
- エージェント内のコードは SDK を直接 import せず、このクライアントだけを使う

### Consequences

- Good, because 記録した応答を再生する評価は API を呼ばずに決定的に実行でき、`make check` と CI に含められる
- Good, because モデル ID とプロンプトの版が呼び出しのたびに必ず残り、評価結果を比較できる
- Good, because コストの集計（`runs.cost`）と1日の上限の判定を一か所で行える
- Bad, because SDK の新しい機能（ストリーミング、新しいパラメータなど）を使うたびに、クライアント側の対応が必要になる
- Bad, because プロンプトやツール定義を変えると記録済みの応答が使えなくなり、記録をやり直す手間がかかる

### Confirmation

- ruff の `flake8-tidy-imports`（`TID251`, banned-api）で SDK の import をクライアントのモジュール以外で禁止し、`make check` で検査する（LLM の SDK を依存に加えるときに設定する）
- 再生モードで、記録にないリクエストが来たら API を呼ばずにエラーにする。再生する評価が黙って実 API を呼ぶことを防ぐ
- コードレビューでは、LLM を呼ぶ新しいコードがこのクライアントを経由しているかを確認する

## Pros and Cons of the Options

### 記録・再生の機能を持つ単一の LLM クライアントを自作し、すべての呼び出しをそこに通す

- Good, because 記録の形式（モデル ID・プロンプトの版・`tool_calls` との紐づけ）を自分で決められる
- Good, because 本番の実行記録（`runs`）と評価用の記録を同じ仕組みで作れる
- Neutral, because 層は薄く、呼び出しを1つの関数にまとめる程度で済む見込み
- Bad, because 自作部分の保守が必要になる

### SDK を呼び出し箇所ごとに直接使い、テストでは HTTP 通信を録画・再生する

- Good, because アプリ側に層を足さずに済み、SDK の機能をそのまま使える
- Bad, because 録画は HTTP の層で行われるため、モデル ID・プロンプトの版・`tool_calls` との紐づけを本番の実行記録に残す仕組みは別に必要になる
- Bad, because リクエストの細部（ヘッダーや SDK の版による違い）で録画が一致しなくなりやすい

### 記録・再生は持たず、評価は毎回実際に API を呼ぶ

- Good, because 実装が最も単純で、常に実際のモデルの振る舞いを測れる
- Bad, because 結果が実行ごとに揺らぎ、回帰を CI で検出できない
- Bad, because 評価のたびにコストがかかり、1日の上限を圧迫する

## More Information

- **Confidence**: 中。エージェントのループと LLM の SDK はまだ導入していない。最初の LLM 呼び出しを実装するフェーズ1で試し、この ADR を accepted にするか見直す
- **Re-evaluation triggers**: 使う SDK やフレームワーク自体が、同等の記録・再生とメタデータの記録を提供するようになった場合。再生する評価の記録をやり直す手間が、評価で得られる効果を上回るようになった場合
- **References**:
  - `docs/evals.md` §3（設計要件）、§5（実行方法）
  - `docs/concept.md` §6（データモデル: `runs`, `tool_calls`）、§8（コスト上限）
