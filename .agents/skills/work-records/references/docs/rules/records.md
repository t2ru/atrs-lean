---
type: Guideline
title: "意思決定記録と作業項目の書き方"
description: "ADR（MADR 4.0）と作業項目（backlog）の ID・ファイル名・参照・状態・節、置き場所と持ち出すバンドルの境界、リポジトリの設定 .work-records.json、ids.py の検査と OKF のプロファイル。"
tags: [adr, backlog, records]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:20:00+09:00
---

# 意思決定記録と作業項目の書き方

設計上の判断を意思決定記録（ADR）、これからの作業を作業項目（backlog）として、1 項目 1 ファイルの Markdown で残す。
この文書は、両者に共通の ID・参照・置き場所と、それぞれの形を定める。リポジトリは、ここに無い事項（いつ ADR を書くか、完了の定義など）を自分の規約で足してよい。

## ID とファイル名

- ID は小文字 16 進・ハイフン付きの UUID v4（36 文字）である。frontmatter の `id` に書く。
- ファイル名は `<ID の先頭 4 文字>-<slug>.md` とする。slug は英小文字・数字・ハイフンで、内容を表す短い句にする。先頭 4 文字は他の項目と重なってもよい（slug で区別する）。
- 一度付けたファイル名は改名・削除しない。不要になった ADR は状態を変え、作業項目は `dropped` にする。
- 採番は `ids.py new` で行う。ID を手で作らない。先頭 4 文字が十進の数字だけの ID は、番号と見分けにくいので道具が避ける。
- 作成の順序はファイル名から分からない。ADR は `date` で追う。

## 参照

| 書く場所 | 形 |
| --- | --- |
| 道具が読む箇所（frontmatter の `id`・`depends_on`・`superseded_by`、設定の `id_fields` が挙げる JSON の欄） | ID 全体 |
| Markdown の本文 | `[ADR xxxx](<相対パス>/xxxx-<slug>.md)`・`[backlog yyyy](…)`。リンクの文字列は ID の先頭 4 文字（種類の語を付けてもよい） |
| リンクを張れない箇所（コードのコメントなど） | `ADR xxxx`・`backlog yyyy` |
| 先頭 4 文字が同じ種類の他の項目と重なる項目の、リンクの無い参照 | stem（`ADR xxxx-<slug>`） |

- 本文の参照の語は、ADR は `ADR`、作業項目は `backlog`・`Backlog`・`バックログ` である。
- インラインのコード（`` `…` ``）の中は例として扱い、参照の検査から外す。

## 置き場所

- 種類（`adr`・`backlog`）ごとに、置き場所のディレクトリを設定の `kinds` に並べる。置き場所は種類ごとに複数でよい（例: リポジトリの `docs/decision` と、スキルの `references/docs/decision`）。ID の空間は 1 つで、参照はどの置き場所の項目にも解決する。
- 置き場所のディレクトリ名は `decision`・`backlog` にする（本文のパスの言及を、道具がこの名前で確かめる）。
- 各置き場所の `README.md` に、項目の表を置く。ADR は `| ID | 題名 | decision_status | 日付 |`、作業項目は `| ID | 項目 | state | 依存 |`。状態を変えたら表を更新する。
- 記録を別の置き場所へ移すときは `ids.py move <stem> <dir>` を使う。リンクを張り直し、リンクの外でパスを書いた箇所を表示する。
- `depends_on` の連鎖をまたいで一部だけを移すと、持ち出すバンドルの境界（下）に反する。連鎖の途中の項目は、来歴として元の置き場所に残してよい。

### 持ち出すバンドル

他のリポジトリへ持ち出して使う文書（例: スキル）は、設定の `isolated` に `{bundle, root}` で挙げる。そのバンドルについて、次を守る。

- Markdown のリンクは `root` の外へ出ない。
- `depends_on`・`superseded_by` は、そのバンドルの項目だけを指す。
- 本文の `ADR xxxx`・`backlog xxxx` で外の項目を挙げてよいのは、バンドルの `decision/`・`backlog/` の中と、それを要約する `index.md`・`log.md` だけである（**来歴**）。来歴は、外の記録の持ち主の名前を添えてリンク無しで書く（例: `<適用先の名前> の ADR xxxx`）。
- バンドルの外の項目が `depends_on` でバンドルの項目を指すのはよい。逆は書かない。

## 意思決定記録（ADR）

MADR 4.0 の形で書く。節見出しは MADR の英語のまま、本文は文書の言語で書く。雛形は [assets/templates/adr.md](../../../assets/templates/adr.md)。

- 節は `Context and Problem Statement`・`Decision Drivers`・`Considered Options`・`Decision Outcome`・`Pros and Cons of the Options`（省いてよい）・`More Information` の順に置く。
- `Considered Options` には選択肢を 2 つ以上、箇条書きで挙げる。
- `Decision Outcome` には、採択を示す行（既定は `Chosen option: "…", because …`。設定の `outcome_markers` で足せる。例: `採択: …`）を置く。
- frontmatter には、OKF のキーに加えて `id`・`decision_status`・`date`・`decision-makers` を書く。任意で `consulted`・`informed`。置き換えられた場合は `superseded_by` も書く。

決定の状態は `decision_status` に書く。OKF の `status` は文書のライフサイクルに予約されているので、MADR の値を書かない。

| `decision_status` | 意味 | 遷移先 | OKF の `status` |
| --- | --- | --- | --- |
| `proposed` | 提案中。実装はこれに依存しない | `accepted`, `rejected` | `draft` |
| `accepted` | 採択済み。規範的 | `deprecated`, `superseded` | `stable` |
| `rejected` | 不採択。記録として残す | — | `deprecated` |
| `deprecated` | 廃止。代替なし | — | `deprecated` |
| `superseded` | 後継の ADR に置き換えられた。`superseded_by: "<後継の ID>"` を書く | — | `deprecated` |

- `accepted` の決定内容は書き換えない。変えるときは新しい ADR を作り、古い ADR を `decision_status: superseded`・`superseded_by`・`status: deprecated` にし、新しい ADR の `More Information` に古い ADR へのリンクを書く。
- 誤字・リンクの修正と補足は書き換えてよい。

## 作業項目（backlog）

雛形は [assets/templates/backlog.md](../../../assets/templates/backlog.md)。

- 節は `目的`・`範囲`・`対象外`・`完了条件`（チェックボックス）・`参照` の順に置く。間に別の節を足してよい。
- frontmatter には、OKF のキーに加えて `id`・`state`・`depends_on`（ID 全体のフローの列 `["…", …]`）を書く。`status` は省く（作業の状態は `state` で表す）。

| `state` | 意味 |
| --- | --- |
| `todo` | 未着手 |
| `doing` | 着手中（同時に `doing` にする項目は、原則 1 つ） |
| `blocked` | 依存・未決事項で止まっている。理由を本文に書く |
| `done` | 完了条件をすべて満たした |
| `dropped` | 取りやめた。理由を本文に書く |

- `depends_on` の項目がすべて `done` になるまで着手しない。依存しない部分を先に進めるときは、範囲を分けた新しい項目を作る。
- 完了条件は、検証できる形（検査・テストの名前、成果物）で書く。`done` にする前に、すべてのチェックボックスを埋める。自己申告ではなく、検査の結果で埋める。
- 作業が途切れても引き継げるよう、着手中の項目には、いま何をしていて次に何をするか、止まっている判断を本文に残す。

## 設定

リポジトリのルートに `.work-records.json` を置く。道具は、作業ディレクトリから上にたどって `.work-records.json` があるところをリポジトリのルートとする。

```json
{
  "kinds": {"adr": ["docs/decision"], "backlog": ["docs/backlog"]},
  "isolated": [{"bundle": ".agents/skills/<skill>/references/docs", "root": ".agents/skills/<skill>"}],
  "id_fields": [{"file": "plan/features.json", "keys": ["backlog"], "kind": "backlog"}],
  "outcome_markers": ["Chosen option"],
  "check_roots": ["AGENTS.md", "docs/"],
  "uuid_roots": ["docs/"],
  "check_skip": [],
  "exclude": []
}
```

| キー | 内容 |
| --- | --- |
| `kinds` | 種類（`adr`・`backlog`）ごとの置き場所。文字列か配列。最初のものが `new` の既定 |
| `isolated` | 持ち出すバンドルの列 `[{bundle, root}]`。`root` はリンクが出てはならない範囲（省くと `bundle`） |
| `id_fields` | ID 全体を書く JSON の欄 `[{file, keys, kind}]`。`file` の中で `keys` のどれかのキーの下にある文字列（入れ子の列・写像もたどる）を、`kind` の ID として検査する |
| `outcome_markers` | ADR の `Decision Outcome` で採択を示す行の書き出し（既定 `["Chosen option"]`） |
| `check_roots` | 本文の参照とパスの言及を検査する範囲（パスの接頭辞。既定 `["docs/"]`） |
| `uuid_roots` | 現れる UUID がすべて記録の ID であるべき範囲（既定 `["docs/"]`） |
| `check_skip` | `check_roots` から外すパスの接頭辞（例: 道具の違反例、生成物） |
| `exclude` | git の管理するファイルのうち、道具がまったく読まないパスの接頭辞（例: submodule） |

## 検査

`ids.py check` が、次を検査する。違反はすべて失敗扱いで、終了コード 1 を返す。

- ID とファイル名: ファイル名の形、`id` が UUID v4 であること、ファイル名の先頭 4 文字と `id` の一致、ID の重複。
- 参照: `depends_on`・`superseded_by`・`id_fields` が既存の項目の ID であること、本文の `ADR xxxx`・`backlog xxxx` が 1 つの項目に解決すること、リンクの文字列と行き先の一致、`decision/`・`backlog/` のパスの言及が実在すること、`uuid_roots` の UUID がすべて記録の ID であること。
- 持ち出すバンドル: 上の [持ち出すバンドル](#持ち出すバンドル) の規則。
- 記録の形（A1）: ADR の `decision_status` の値と `status` の対応、`superseded_by` は `superseded` のときだけ、選択肢が 2 つ以上、`Decision Outcome` に採択を示す行。
- 記録の形（B1）: 作業項目の `state` の値、`status` を持たない、`depends_on` がフローの列、`done` の項目に未完了の完了条件が無い。

`--self-test` は、`scripts/fixtures/` の例（違反なしの `ok` と、違反を含む `violations`。期待は各例の `expect.txt`）を一時の git リポジトリに写して確かめる。検査を足すときは、違反例も足す。

## OKF のプロファイル

記録の置き場所が OKF v0.2 のバンドルの中にある場合は、スキル okf-bundle のプロファイルに次の規則を書き、frontmatter の必須キーと節の順を検査する（記録の形の残りは `ids.py check` が検査する）。

```json
[
  {"match": "**/README.md", "type": "Overview"},
  {"match": "decision/*.md", "type": "Architecture Decision Record",
   "required": ["id", "decision_status", "date", "decision-makers"],
   "sections": ["Context and Problem Statement", "Decision Drivers", "Considered Options", "Decision Outcome", "More Information"]},
  {"match": "backlog/*.md", "type": "Backlog Item",
   "required": ["id", "state", "depends_on"],
   "sections": ["目的", "範囲", "対象外", "完了条件", "参照"]}
]
```
