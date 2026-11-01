---
type: Architecture Decision Record
title: "docs/ とスキルのバンドルを okf_check.py で検査し、CI の一括検査に入れる"
description: "ATRS の docs/ とスキル spec-pivot の references/docs/ を、スキルの道具 okf_check.py で検査する。ATRS の規則（ディレクトリごとの type・必須キー・ADR と backlog の必須の節・採択を示す行・索引の網羅・相対リンクとアンカー）を trace/project.json の okf に置き、tools/ci/lean.sh から実行する。frontmatter は YAML の部分集合で書く。"
tags: [adr, documentation, okf, ci]
id: "920d9c0e-d4cb-4c40-8c59-df278da4aa77"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:10:00+09:00
---

# docs/ とスキルのバンドルを okf_check.py で検査し、CI の一括検査に入れる

## Context and Problem Statement

[ADR a0f1](a0f1-documentation-format-okf-v0-2.md) は、`docs/` を OKF v0.2 のバンドルとし、frontmatter と `type`、`docs/index.md` の網羅をスクリプトで検査すると定めた。この検査はまだ無かった（[backlog ddbd](../backlog/ddbd-okf-bundle-lint.md)）。
`ids.py check` は ID と、ADR・backlog へのリンクだけを見ており、一般の相対リンクと見出しアンカーは検査していなかった。
アプリに依存しない検査の道具は、スキルに `scripts/docs/okf_check.py` として置いた（[スキルの ADR 330e](../../.agents/skills/spec-pivot/references/docs/decision/330e-okf-bundle-check-tool.md)）。ATRS は、どの規則で何を検査するかを決める必要がある。

## Decision Drivers

* [documentation.md](../rules/documentation.md#okf-v02)・[decision-records.md](../rules/decision-records.md)・[backlog.md](../rules/backlog.md) の規則を、書かれたとおりに機械で確かめること
* 既存の文書を大きく書き換えないこと（`accepted` の ADR の決定内容は変えない）
* ATRS の文書からスキルの文書へのリンクも、切れていないこと

## Considered Options

* `docs/` とスキルのバンドルを、規約どおりの規則で検査し、`tools/ci/lean.sh` から実行する
* OKF の適合条件（§11）だけを検査する
* 検査しない（レビューで確かめる）

## Decision Outcome

Chosen option: "規約どおりの規則で検査し、`tools/ci/lean.sh` から実行する", because 規約の多くは形の規則であり、機械で確かめれば更新漏れ（索引・節・状態の対応）を CI で止められるため。§11 だけでは、規約が求める索引の網羅も確かめられない。

### 検査する範囲

* バンドル: `docs/`（規則は `trace/project.json` の `okf.bundles`）と、スキルの `references/docs/`（規則はスキルの `scripts/docs/profiles/spec-pivot.json`）。
* リンク: `AGENTS.md`・`CLAUDE.md`・`docs/`・`.agents/` の Markdown。スキルの道具の違反例（`scripts/ci/fixtures/`）は除く。`/` で始まるリンクは違反とする（[documentation.md](../rules/documentation.md#リンク)）。

### `docs/` の規則

| パス | `type` | 必須キー（`title`・`description`・`tags` に加えて） | ほか |
| --- | --- | --- | --- |
| `**/README.md` | `Overview` | — | — |
| `decision/*.md` | `Architecture Decision Record` | `id`・`decision_status`・`date`・`decision-makers` | 節 `Context and Problem Statement`・`Decision Drivers`・`Considered Options`・`Decision Outcome`・`More Information`（この順）。`Decision Outcome` に `Chosen option` か `採択` で始まる行 |
| `backlog/*.md` | `Backlog Item` | `id`・`state`・`depends_on` | 節 `目的`・`範囲`・`対象外`・`完了条件`・`参照`（この順） |
| `spec/*.md` | `Specification` | `models`・`spec_role` | 値は `models` ∈ {`spec`, `source`, `target`}、`spec_role` ∈ {`normative`, `meta`, `draft`, `informative`}（配列も可） |
| `rules/*.md` | `Guideline` | — | — |

* どの文書も、`title`・`description` をダブルクォートで囲み、`#` 見出しを 1 つだけ持ち、それが `title` と一致する。
* `docs/index.md` は `docs/` のすべての文書を列挙し、項目の題名・説明は文書の `title`・`description` と一致する。
* `Pros and Cons of the Options` は必須にしない。既存の ADR のうち `docs/` の 7 件とスキルの 5 件が持たず、MADR 4.0 でも任意の節である。
* 採択を示す行に `採択:` を認める。既存の ADR のうち `docs/` の 2 件（ADR 6ab4・cc24）とスキルの 2 件が、`Chosen option:` ではなく `採択:` で書いているためである。

### 導入で直したもの

* `docs/rules/README.md` の `type` を `Overview` にした（規約の表に合わせた）。
* `docs/index.md` の ADR f4e1・c108 の説明を、frontmatter の `description` に合わせた。
* backlog 0d1a・c27d に、無かった `対象外` の節を補った（中身は「記載なし」）。

### Consequences

* Good, because 索引・節・状態の更新漏れと、リンク・アンカーの切れを CI で止められる。
* Good, because ATRS の文書からスキルの文書の見出しへのリンクも検査される。
* Bad, because frontmatter を YAML の部分集合で書く制約が増える（既存の文書はすべて部分集合で書かれていた）。
* Bad, because 見出しを改めるとアンカーのリンクが切れて CI が落ちるので、見出しを変えるときはリンクも直す必要がある。

### Confirmation

* `tools/ci/lean.sh` が `okf_check.py --self-test` と `okf_check.py` を実行し、違反で失敗する。

## Pros and Cons of the Options

### OKF の適合条件だけを検査する

* Good, because 規則が少なく、設定が要らない。
* Bad, because ADR a0f1 が求める索引の網羅と、規約の節・状態の対応を確かめられない。

### 検査しない

* Good, because 何も足さずに済む。
* Bad, because 更新漏れがレビューに頼ることになる。

## More Information

* 道具の決定: [スキルの ADR 330e](../../.agents/skills/spec-pivot/references/docs/decision/330e-okf-bundle-check-tool.md)（検査の符号、YAML の部分集合、設定の形）
* [ADR a0f1](a0f1-documentation-format-okf-v0-2.md) の Confirmation を実装する（置き換えない）。
* 作業: [backlog ddbd](../backlog/ddbd-okf-bundle-lint.md)、[スキルの backlog a49c](../../.agents/skills/spec-pivot/references/docs/backlog/a49c-okf-bundle-check-tool.md)
* 規約: [documentation.md](../rules/documentation.md#okf-v02)、[decision-records.md](../rules/decision-records.md)、[backlog.md](../rules/backlog.md)
