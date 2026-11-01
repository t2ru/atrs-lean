---
name: work-records
description: "意思決定記録（ADR。MADR 4.0）と作業項目（backlog）を Markdown のファイルとして管理する方法と道具。UUID v4 の ID とファイル名 <ID の先頭 4 文字>-<slug>.md、決定の状態（decision_status）と作業の状態（state）・依存（depends_on）、本文の参照 ADR xxxx・backlog xxxx、複数の置き場所（リポジトリとスキル）で 1 つの ID の空間、持ち出すバンドルの境界を扱い、ids.py で採番・検査・移動する。Use when recording a design decision, creating or updating a backlog item or task, changing its state, choosing what to work on next from depends_on, referencing ADRs/backlog items, or moving records between repositories and skills. Keywords: ADR, architecture decision record, MADR, backlog, task management, work item, UUID, depends_on, decision log."
compatibility: Python 3（uv で実行。標準ライブラリだけ）と git。OKF のバンドルの中で使う場合はスキル okf-bundle を併用する。
metadata:
  version: "0.1"
---

# work-records: 意思決定記録と作業項目

設計上の判断を **意思決定記録（ADR）**、これからの作業を **作業項目（backlog）** として、リポジトリの中に 1 項目 1 ファイルで残す。
ID・参照・状態の形は道具で検査し、作業の中断（文脈の上限・セッションの終了）があっても、別の担当者が記録から引き継げるようにする。

## 使う場面

- 設計上の判断をした。判断を改めた（新しい ADR と、古い ADR の `superseded`）。
- 作業を項目に分ける。項目の状態を変える。次に着手できる項目を `depends_on` から選ぶ。
- 本文やコードのコメントから ADR・backlog を参照する。
- 記録を、リポジトリとスキル（他のリポジトリへ持ち出す文書）の間で移す。

## 規則（要約）

詳細は [references/docs/rules/records.md](references/docs/rules/records.md)、雛形は [assets/templates/](assets/templates/adr.md)。

1. ID は小文字の UUID v4。ファイル名は `<ID の先頭 4 文字>-<slug>.md`。一度付けたファイル名は改名・削除しない。採番は `ids.py new` で行う。
2. 道具が読む箇所（frontmatter の `id`・`depends_on`・`superseded_by`、設定の `id_fields` の JSON の欄）には ID 全体を、本文には先頭 4 文字（`ADR xxxx`・`backlog xxxx`）を書く。
3. ADR は MADR 4.0 の節で書き、決定の状態は `decision_status` に書く（OKF の `status` とは別。対応は規則の表）。`accepted` の決定内容は書き換えず、新しい ADR で置き換える。
4. backlog は `目的`・`範囲`・`対象外`・`完了条件`・`参照` の節で書き、作業の状態は `state`（`todo` / `doing` / `blocked` / `done` / `dropped`）に書く。`depends_on` がすべて `done` になるまで着手しない。`done` は完了条件がすべて埋まってから。
5. 状態を変えたら、置き場所の `README.md` の表を更新する。
6. 持ち出すバンドル（スキル）の記録は、外の項目を frontmatter で指さず、外へリンクしない。外の記録は来歴として文字で書く。

## 道具（scripts）

`scripts/ids.py` が、ID の採番・検査・移動を行う。

```bash
uv run python -I <work-records>/scripts/ids.py new adr <slug> [--dir <dir>]
uv run python -I <work-records>/scripts/ids.py new backlog <slug> [--dir <dir>]
uv run python -I <work-records>/scripts/ids.py check        # ID・ファイル名・参照・記録の形（違反で終了コード 1）
uv run python -I <work-records>/scripts/ids.py move <stem> <dir>
uv run python -I <work-records>/scripts/ids.py --self-test  # 違反例（scripts/fixtures/）を検出できること
```

`<work-records>` は、このスキルの置き場所である。道具は、作業ディレクトリから上にたどって `.work-records.json` があるところをリポジトリのルートとする（`--repo <dir>` でも指定できる）。設定の形は [rules/records.md](references/docs/rules/records.md#設定) にある。

## 関連するスキル

記録を OKF v0.2 のバンドルの中に置く場合は、スキル **okf-bundle** の `okf_check.py` が frontmatter・必須キー・節の順・索引・リンクを検査する。プロファイルに書く規則は [rules/records.md](references/docs/rules/records.md#okf-のプロファイル) にある。

## スキルの文書と記録

`references/docs/` は、このスキル自身の OKF のバンドルである（索引 [references/docs/index.md](references/docs/index.md)、変更履歴 [log.md](references/docs/log.md)）。
このスキルの意思決定記録は [references/docs/decision/](references/docs/decision/README.md)、作業項目は [references/docs/backlog/](references/docs/backlog/README.md) に置く。
スキルは他のリポジトリへ持ち出して使う。文書のリンクはスキルのディレクトリの外へ出さない。
