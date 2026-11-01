---
type: Guideline
title: "スキルの文書の保守"
description: "references/docs（OKF v0.2 のバンドル）の形式とその検査、意思決定記録と作業項目の書き方、ID の道具、持ち出せることの検査、適用先との分担。"
tags: [documentation, okf, adr, backlog]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:10:00+09:00
---

# スキルの文書の保守

`references/docs/` は Open Knowledge Format (OKF) v0.2 の Knowledge Bundle である。スキルの方法の文書と、スキル自身の意思決定記録・作業項目を置く（[ADR 87b9](../decision/87b9-skill-docs-as-okf-bundle.md)）。
この文書は、スキルを保守する人とエージェントのためのものである。移植の方法を使うだけなら読まなくてよい。

## バンドルの構成

| パス | `type` | 内容 |
| --- | --- | --- |
| [index.md](../index.md) | （予約） | 索引。frontmatter は `okf_version: "0.2"` だけ。本文は `#` 見出しと `* [題名](相対パス) - 説明` の箇条書きだけ |
| [log.md](../log.md) | （予約） | 変更履歴。frontmatter は無し。新しい順に、`## YYYY-MM-DD` 見出しの下に `* **Creation**: …` / `* **Update**: …` / `* **Deprecation**: …` を書く |
| `spec/` | `Specification` | 方法の規範: 層・リファインメントと義務・追跡・ベクタの形式・検証の使い分け・Spec に課す制約 |
| `rules/` | `Guideline` | 書き方の規約: 仕様文書の書き方、このバンドルの保守 |
| `guide/` | `Guide` | 手順と進め方: 移植の手順・作業の進め方・版上げ・言語パックの追加 |
| `lang/<lang>/`（`lang/sql/dialects/<dbms>/` を含む） | `Reference` | 言語パック。言語・処理系ごとの意味論・効果・構成・ロケータ・ベクタの実行・検証器（[adding-a-language.md](../guide/adding-a-language.md)） |
| [decision/](../decision/README.md) | `Architecture Decision Record` | スキルの意思決定記録 |
| [backlog/](../backlog/README.md) | `Backlog Item` | スキルの作業項目 |
| 各ディレクトリの `README.md` | `Overview` | 索引 |

## frontmatter

`index.md`・`log.md` 以外の `.md` は、先頭に YAML の frontmatter を持たなければならない。

| キー | 必須 | 内容 |
| --- | --- | --- |
| `type` | MUST | 上の表の値 |
| `title` | SHOULD | 本文の `#` 見出しと同じ。ダブルクォートで囲む |
| `description` | SHOULD | 1 文の要約。`index.md` の説明と一致させる。ダブルクォートで囲む |
| `tags` | SHOULD | 英小文字の配列 |
| `status` | SHOULD | OKF のライフサイクル（`draft` / `stable` / `deprecated`）。他の意味に使わない |
| `generated` | AI が書いた場合 MUST | `{by: <producer>/<version>, at: <ISO 8601 オフセット付き>}` |
| `verified` | 任意 | 人のレビューの記録 `[{by: human:<id>, at: …}]` |
| `sources` | 任意 | 出典 `[{id, resource, title}]`。本文から脚注 `[^id]` で引く |

- frontmatter は YAML の部分集合で書く（下の「バンドルの検査」）。
- 文書を足す・改名する・廃止するときは、`index.md` と `log.md` を必ず更新する。
- 方法の文書は、規範（守るべき構成・義務・形式）なら `spec/`、書き方の規約なら `rules/`、手順・進め方なら `guide/` に置く。どこにも当たらない種類が増えたら、新しいディレクトリとプロファイルの規則を足す（意思決定記録を残す）。
- 文書を移す・ディレクトリを組み替えるときは、`scripts/docs/docmv.py` を使う。リポジトリのリンクとパスの言及を一度に張り直す。
- スキルの改訂は `SKILL.md` の `metadata.version` で管理する。版を上げたら `log.md` に書く。

## バンドルの検査

`scripts/docs/okf_check.py` が、OKF のバンドルの形と Markdown のリンクを検査する（[ADR 330e](../decision/330e-okf-bundle-check-tool.md)）。

```bash
python3 -I <skill>/scripts/docs/okf_check.py              # 違反で終了コード 1
python3 -I <skill>/scripts/docs/okf_check.py --self-test  # 違反例を検出できることを確かめる
```

| 検査 | 内容 |
| --- | --- |
| OKF の適合条件 | `index.md`・`log.md` 以外の `.md` の frontmatter が YAML の部分集合として読め、空でない `type` を持つ。`index.md`・`log.md` が OKF §8・§9 の形である |
| プロファイルの規則 | パスごとの `type`・必須キー・値・ダブルクォート・`#` 見出し・必須の節。意思決定記録と作業項目の形（下の 2 節） |
| 索引 | バンドルのルートの `index.md` がすべての文書を列挙し、題名・説明が frontmatter と一致する |
| リンク | 相対リンクの指す先があり、見出しアンカー（GitHub の規則）が指す Markdown にある。`/` で始まるリンクを書かない |

- frontmatter の YAML の部分集合: ブロックのマッピングと列（字下げは空白。列はキーより深く）、引用符付きと 1 行のプレーンのスカラ、要素がスカラだけのフローの列 `[a, b]`、コメント。フローのマッピング `{…}`・ブロックのスカラ `|`・`>`・複数行のプレーン・アンカー・タグ・キーの重複は使わない。
- 道具の設定は、適用先の `trace/project.json` の `okf` にある（[traceability.md](../spec/traceability.md#プロジェクトの設定)）。このバンドルの規則は `scripts/docs/profiles/spec-pivot.json` で、適用先の設定からそのパスを指す。
- 意思決定記録の `Decision Outcome` には、`Chosen option: "…", because …` か `採択: …` で始まる行を置く（プロファイルの `outcome_markers`）。

## 意思決定記録（`decision/`）

MADR 4.0 の形で書く。節見出しは英語（`Context and Problem Statement`・`Decision Drivers`・`Considered Options`・`Decision Outcome`・`Pros and Cons of the Options`・`More Information`）、本文は日本語とする。

- frontmatter には OKF のキーに加えて、`id`（UUID v4）・`decision_status`・`date`・`decision-makers` を書く。置き換えられた場合は `superseded_by` も書く。
- `decision_status` と OKF の `status` の対応:

  | `decision_status` | OKF の `status` |
  | --- | --- |
  | `proposed` | `draft` |
  | `accepted` | `stable` |
  | `rejected` / `deprecated` / `superseded` | `deprecated` |

- `accepted` の決定内容は書き換えない。変えるときは新しい記録を作り、古い記録を `superseded` にする。誤字・リンクの修正と補足は書き換えてよい。
- 次の判断は記録に残す。
  - 方法（層・手順・証明の義務・追跡・版上げ）の変更
  - 言語パックの構成の変更
  - スキルの道具・Lean のライブラリの構成や設定の形の変更
  - スキルの構成の変更

## 作業項目（`backlog/`）

- frontmatter には OKF のキーに加えて、`id`（UUID v4）・`state`（`todo` / `doing` / `blocked` / `done` / `dropped`）・`depends_on`（ID 全体の配列）を書く。`status` は省く。
- 節は `目的`・`範囲`・`対象外`・`完了条件`（チェックボックス）・`参照` とする。
- `depends_on` の項目がすべて `done` になるまで着手しない。
- 状態を変えたら、[backlog/README.md](../backlog/README.md) の表を更新する。

## ID と参照

- ID は小文字の UUID v4 である。ファイル名は `<ID の先頭 4 文字>-<slug>.md`（slug は英小文字・数字・ハイフン）とする。一度付けたファイル名は改名・削除しない。
- 道具が読む箇所（`id`・`depends_on`・`superseded_by`）には ID 全体を書く。本文では先頭 4 文字を書く（`ADR xxxx`・`backlog xxxx`）。先頭 4 文字が重なるときは stem を書く。
- 採番と検査には、スキルの `scripts/docs/ids.py` を使う（[scripts/README.md](../../../scripts/README.md)）。

  ```bash
  python3 -I <skill>/scripts/docs/ids.py new adr <slug> --dir <skill>/references/docs/decision
  python3 -I <skill>/scripts/docs/ids.py new backlog <slug> --dir <skill>/references/docs/backlog
  python3 -I <skill>/scripts/docs/ids.py move <stem> <dir>   # 記録を適用先とスキルの間で移す
  python3 -I <skill>/scripts/docs/ids.py check
  ```

- 道具の設定は、適用先の `trace/project.json` の `ids` にある（[traceability.md](../spec/traceability.md#プロジェクトの設定)）。適用先の置き場所とスキルの置き場所を `ids.kinds` に並べ、ID の空間を 1 つにする。

## 持ち出せること

スキルは他のリポジトリへ持ち出して使う。そのため、次を守る。`ids.isolated` にこのバンドルを挙げると、`ids.py check` が検査する。

- 文書の Markdown のリンクは、スキルのディレクトリの外へ出ない。
- `depends_on`・`superseded_by` は、このバンドルの項目だけを指す。
- 方法の文書と言語パックには、アプリ固有の語（適用先の機能・コード・commit・文書へのリンク）を書かない。
- 例外として、`decision/`・`backlog/` と、それを要約する `index.md`・`log.md` には **来歴** を書いてよい。適用先で作った記録を移した場合や、適用先の判断をきっかけにした場合が当たる。来歴は、適用先の名前を添えてリンク無しで書く（例: `<適用先の名前> の ADR xxxx`）。

## 適用先との分担

| 判断・作業 | 置き場所 |
| --- | --- |
| アプリに依存しない判断・作業（方法、道具、Lean のライブラリ、スキルの構成） | このバンドルの `decision/`・`backlog/` |
| 適用先に固有の判断・作業（ドメインの規則、言語の組、配置、適用の仕方） | 適用先の記録 |
| 両方にかかるもの | 分けて両方に書く。適用先の記録からは、スキルの記録へリンクしてよい |

- 適用先にも影響するスキルの改訂は、適用先にも記録を残す（適用先の規約に従う）。
- 適用先の項目が `depends_on` でスキルの項目を指すのはよい。逆は書かない。
