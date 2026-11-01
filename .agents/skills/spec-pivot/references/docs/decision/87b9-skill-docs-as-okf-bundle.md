---
type: Architecture Decision Record
title: "スキルの文書を references/docs/ の OKF バンドルにし、スキルの決定と作業項目をスキルで持つ"
description: "スキル spec-pivot の references を references/docs/ に移して OKF v0.2 の Knowledge Bundle とし、スキル自身の意思決定記録と作業項目を references/docs/{decision,backlog} で管理する。適用先のプロジェクトとは ID の空間を共有し、外の項目は来歴としてだけ挙げる。"
tags: [adr, skill, documentation, okf]
id: "87b96b93-64cb-46f5-b7a0-72edf43e386d"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:40:00+09:00
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/open-knowledge-format/blob/main/SPEC.md
    title: Open Knowledge Format (OKF) Specification v0.2
  - id: agentskills
    resource: https://agentskills.io/specification
    title: Agent Skills Specification
---

# スキルの文書を references/docs/ の OKF バンドルにし、スキルの決定と作業項目をスキルで持つ

## Context and Problem Statement

スキル spec-pivot の文書は、`references/*.md` と言語パック `references/<lang>/` に、frontmatter 無しで置かれていた。
スキル自身の設計判断と作業項目には、スキルの置き場所が無かった。そのため、スキルを最初に適用したプロジェクト（ATRS）の `docs/decision`・`docs/backlog` に、そのプロジェクトの記録と混ざって置かれていた。
スキルは他のリポジトリへ持ち出して使う。持ち出すと、方法の文書は手元に残るが、方法を決めた理由と残りの作業が失われる。
プロジェクトオーナーから次の指示があった。
- references の文書を `references/docs/` に移し、OKF v0.2 のバンドルにする[^okf-spec]。
- `references/docs/{decision,backlog}` で、スキルの決定と作業項目を管理する。
- 適用先にあるスキルの記録は移す。

## Decision Drivers

* スキルを持ち出したとき、方法とその理由・残りの作業が一緒に持ち出されること
* 文書の形式（frontmatter・索引・変更履歴）を、適用先の文書と揃え、同じ道具で検査できること
* 適用先の記録を壊さないこと（ID・ファイル名を変えない）
* スキルの文書が、適用先のアプリに依存しないままであること

## Considered Options

* `references/docs/` を OKF のバンドルとし、その中に `decision/`・`backlog/` を置く
* スキル直下に `docs/` を設け、`references/` とは別のバンドルにする
* スキルの記録は引き続き適用先に置き、`references/` は今の形のままにする

## Decision Outcome

Chosen option: "`references/docs/` を OKF のバンドルとし、その中に `decision/`・`backlog/` を置く", because バンドルが 1 つで済み、方法の文書と記録が同じ索引・同じ変更履歴に載るため。Agent Skills の `references/` の段階的な読み込みもそのまま使える[^agentskills]。

### バンドルの構成

| パス | 内容 |
| --- | --- |
| `references/docs/index.md`・`log.md` | OKF の予約ファイル（索引・変更履歴） |
| `references/docs/*.md` | 方法の文書（`type: Guideline`） |
| `references/docs/<lang>/` | 言語パック（`type: Reference`） |
| `references/docs/decision/` | スキルの意思決定記録（MADR 4.0、`type: Architecture Decision Record`） |
| `references/docs/backlog/` | スキルの作業項目（`type: Backlog Item`） |
| `references/docs/rules/maintenance.md` | このバンドルの保守の規則 |

* 各文書は OKF v0.2 の frontmatter を持つ。規則は [maintenance.md](../rules/maintenance.md) にまとめる。
* 言語パックの 6 ファイルの構成（[adding-a-language.md](../guide/adding-a-language.md)）と相対リンクは変えない。

### 何をスキルに記録するか

* アプリに依存しない判断と作業は、スキルの `decision/`・`backlog/` に置く。次のものが当たる。
  * 方法（層・手順・証明の義務・追跡・版上げ）
  * スキルの道具（`scripts/`）
  * スキルの Lean のライブラリ（`assets/lean`）
  * スキルの構成
* 適用先に固有の判断（ドメインの規則、言語の組の選択、適用先の配置）は、適用先に置く。
* 両方を含む判断は分けて書く。分けられない既存の記録は適用先に残す。後から分けて移してよい。

### ID と参照

* ID の形は適用先と同じにする。UUID v4 で、ファイル名は `<ID の先頭 4 文字>-<slug>.md`。
* 適用先がスキルの道具 `scripts/docs/ids.py` を使う場合は、その設定 `ids.kinds` にスキルの `decision/`・`backlog/` を加え、ID の空間を 1 つにする。
* 設定 `ids.isolated` にこのバンドルを挙げ、持ち出せることを道具で検査する。
  * スキルの項目は、`depends_on`・`superseded_by` で外の項目を指さない。
  * スキルの文書は、Markdown のリンクでスキルの外へ出ない。
  * 外の項目を本文で挙げてよいのは、`decision/`・`backlog/` の中の来歴だけである。書き方は「ATRS の ADR xxxx」のように適用先の名前を添え、リンクを張らない。
* 適用先からスキルの項目へは、リンクで参照してよい。適用先の項目が `depends_on` でスキルの項目を指すのもよい（依存の向きは適用先からスキル）。

### 移した記録

ATRS の `docs/` から、純粋にスキルのものだけを `git mv` で移した。ID とファイル名は変えていない。

| 種類 | 項目 |
| --- | --- |
| 意思決定記録 | [ADR edc8](edc8-skill-scripts-and-generic-lean-libraries.md)、[ADR 7fe4](7fe4-move-trace-attributes-to-skill.md)、[ADR 6edf](6edf-lean-package-under-skill-assets-lean.md)、[ADR 0b83](0b83-porting-conditions-and-workflow.md)、[ADR 0eea](0eea-trace-tooling-unresolved-details.md)、[ADR 9cd9](9cd9-rehash-diff-impact-details.md) |
| 作業項目 | [backlog 1ae4](../backlog/1ae4-machine-refinement-framework.md)、[backlog a936](../backlog/a936-lang-semantics-rust.md) |

* 移した記録では、ATRS へのリンクを来歴の文に直した。決定の内容は変えていない。
* 作業項目の ATRS への `depends_on`（どちらも ATRS の backlog be49）は外し、本文に来歴として書いた。
* ATRS の部分を含む記録は ATRS に残した。たとえば ATRS の ADR c336・f4e1・01d4・70eb・cc24、backlog f7b7・ffdc がそれに当たる。
* ATRS の ADR 3e1d は内容はスキルのものだが、ATRS の ADR 796c に置き換えられ、ATRS の仕様へのリンクを多く持つため、残した。

### Consequences

* Good, because スキルを持ち出すと、方法・決定・作業項目が一緒に持ち出される。
* Good, because 適用先と同じ道具（`ids.py check`）で、ID・参照・持ち出せることを検査できる。
* Bad, because ATRS の部分を含む記録が適用先に残るため、スキルの決定の一部は当面、適用先の記録を読まないと分からない。
* Bad, because `references/` のパスが 1 段深くなり、スキルを参照する文書を張り直す必要がある。

### Confirmation

* `python3 -I <skill>/scripts/docs/ids.py check` が通る（`ids.isolated` の検査を含む）。
* `references/docs/` の `index.md`・`log.md` 以外の `.md` が、`type` を持つ frontmatter を持つ。
* 文書を足したら、`index.md` と `log.md` を更新する（[maintenance.md](../rules/maintenance.md)）。

## Pros and Cons of the Options

### スキル直下に `docs/` を設ける

* Good, because 方法の文書（読み込む資料）と記録（保守の資料）が分かれる。
* Bad, because バンドルが 2 つになり、索引と変更履歴も 2 組になる。方法の文書を OKF にする目的と合わない。

### スキルの記録を適用先に置いたままにする

* Good, because 何も移さずに済む。
* Bad, because スキルを持ち出すと、決定の理由と残りの作業が失われる。

## More Information

* 来歴: ATRS の ADR f4e1（スキルへの切り出し。スキルに ATRS の語を書かない規則）、ATRS の ADR a0f1（ATRS の `docs/` の OKF）、ATRS の ADR f57e（UUID の ID）。ATRS 側の決定は ATRS の ADR 50f9 にある。
* 作業: [backlog de90](../backlog/de90-skill-docs-okf-bundle-and-records.md)
* 規則: [maintenance.md](../rules/maintenance.md)、道具: [scripts/README.md](../../../scripts/README.md)

[^okf-spec]: Open Knowledge Format (OKF) Specification v0.2 — §3 Bundle, §4 Frontmatter, §8 Index, §9 Log.
[^agentskills]: Agent Skills Specification — Optional directories: `references/`.
