# おくら（okura-inventory-manager）

> 食材も日用品も、**お蔵入りさせない**。

台所の在庫係エージェント。構想は [docs/concept.md](docs/concept.md) を参照。

## 必要なもの

- [uv](https://docs.astral.sh/uv/)（Python 本体と依存はすべて uv が管理する）
- make（任意。`make help` でコマンド一覧）

## セットアップ

```sh
make setup        # = uv sync && uv run pre-commit install
```

Python のバージョンは `.python-version`（3.14）で固定しており、未インストールなら uv が自動で取得する。

## よく使うコマンド

| コマンド | 内容 |
|---|---|
| `uv run okura` | CLI を実行 |
| `make fmt` | ruff による自動修正と整形 |
| `make lint` | lint と format のチェック |
| `make typecheck` | mypy（strict） |
| `make test` / `make cov` | テスト / カバレッジ付きテスト |
| `make audit` | 依存の脆弱性検査（`uv audit`） |
| `make check` | CI と同じチェックを一通り実行 |

依存の追加は `uv add <pkg>`（開発用は `uv add --dev <pkg>`）。`uv.lock` も必ずコミットする。

## CI/CD

| ワークフロー | トリガー | 内容 |
|---|---|---|
| `ci.yml` | main への push / PR | pre-commit 全フック（ruff・mypy・actionlint・zizmor ほか）、Ubuntu と macOS でのテスト、wheel のビルドとスモークテスト、`uv audit` |
| `release.yml` | `v*` タグの push | CI を通してからビルドし、GitHub Release に成果物を添付 |

- ブランチ保護の必須チェックには `CI OK` ジョブだけを指定すればよい
- Dependabot が uv・GitHub Actions・pre-commit を毎週更新する
- 本番は自宅 Mac で動かす（外部公開しない）ため、PyPI への公開や自動デプロイはしない

### リリース手順

```sh
# 1. 作業ブランチでバージョンを上げて PR を出し、main にマージする
git switch -c release/next
uv version --bump minor   # pyproject.toml と uv.lock のバージョンを更新
git commit -am "Release v$(uv version --short)"
gh pr create --fill

# 2. マージ後、main の最新にタグを付けて push する（release.yml が起動する）
git switch main && git pull
git tag "v$(uv version --short)" && git push origin "v$(uv version --short)"
```

## ディレクトリ構成

```
src/okura/      アプリ本体（src レイアウト）
tests/          pytest
docs/           コンセプト・設計文書
.github/        CI/CD と Dependabot
.claude/        Claude Code の設定とフック（内容は CLAUDE.md）
```
