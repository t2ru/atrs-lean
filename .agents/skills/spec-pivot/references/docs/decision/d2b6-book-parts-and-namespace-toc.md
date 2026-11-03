---
type: Architecture Decision Record
title: "本を部に分け、目次をモジュール名の階層で入れ子にする"
description: "scripts/book/build.py の設定に book.parts（部の題・Lean のルート base・トップレベルのモジュールの列）を足し、複数の Lean のルートを 1 冊にする。目次は、部ごとに入口のモジュールの import の順、モジュール名の階層の入れ子とし、モジュールの無い中間の名前はページの無い見出しにする。本に入れた Lean のファイルへのリンクは、部をまたいでも本のページへ向ける。"
tags: [adr, tooling, documentation, mdbook]
id: "d2b636d1-7732-419d-b284-80918ecfd947"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: 適用先 ATRS のオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T13:00:00+09:00
---

# 本を部に分け、目次をモジュール名の階層で入れ子にする

## Context and Problem Statement

本の道具 `scripts/book/build.py`（[ADR c634](c634-spec-prose-in-lean-module-docs-and-book.md)）は、1 つの Lean のルート（`roots` と `entry`）の `Spec` だけを本にしていた。
適用先 ATRS は、Lean のソース全体（モデル・証明・テストと、このスキルの `assets/lean`）を 1 冊にすることにした（来歴: ATRS の ADR f779）。
ルートが複数になり、モジュールも約 300 になるので、部と、深い名前の階層の目次が要る。

## Decision Drivers

* 複数の Lean のルート（適用先の Lean パッケージと、このスキルの `assets/lean`）を 1 冊にできること
* 深い名前の階層（例 `SourceModel.Domain.Service.B0.TicketSharedServiceImpl`）でも、目次を読めること
* これまでの設定（`roots`・`entry`）を壊さないこと

## Considered Options

* 部（`book.parts`）を足し、目次をモジュール名の階層で入れ子にする
* ルートごとに別の本を作る

## Decision Outcome

Chosen option: "部を足し、目次をモジュール名の階層で入れ子にする", because 部をまたぐリンクを本の中で解決でき、目次の形は mdbook の部（`# <題>`）とページの無い章（`- [題]()`）で表せるため。

* `book.parts`: `[{title, base, modules}]`。`base` は Lean のルート、`modules` はトップレベルのモジュール名の列で、各 `M` は `<base>/M.lean` と `<base>/M/` の下の `.lean` に当たる。ページは `<モジュールのパス>.md`。異なるファイルが同じページに当たれば誤りにする。`parts` が無ければ、`roots`・`entry` を題の無い 1 部とする。
* 目次: 前書き `index.md`（本の題と部の一覧）の後に、部ごとに `# <部の題>` を置く。各部は、モジュールごとに入口（`M.lean`）を章にする。その下は、入口が直接 import するモジュールの順、それ以外は入口からの深さ優先の順に並べ、モジュール名の階層で入れ子にする。
  * モジュールの無い中間の名前は、すぐ下の名前が 2 つ以上あれば、ページの無い見出しにする。1 つなら畳み、`A.B` のように続けて示す。
  * 章の題がモジュール名そのもの（モジュール文書の題が無い）なら、親から見た相対の名前で示す。
* リンク: 本に入れた Lean のファイルを指すリンクは、部をまたいでも本のページへ向ける。他は `repo_url` へ向ける。

### Consequences

* Good, because 適用先とこのスキルの Lean のソースを、層をまたぐリンクごと 1 冊で読める。
* Bad, because 大きな本では、mdbook の検索の索引が大きくなる（ATRS で約 10 MB）。

## More Information

* 設定の形: [traceability.md](../spec/traceability.md#プロジェクトの設定)。道具: `scripts/README.md`。
