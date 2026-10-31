---
type: Architecture Decision Record
title: "スキル port-lang の決定と作業項目をスキルのバンドルへ移し、ATRS からはリンクで参照する"
description: "スキル port-lang の文書が references/docs/ の OKF バンドルになり、スキル自身の意思決定記録・作業項目を持つようになったのに合わせ、ATRS の docs/ にあった純粋にスキルの記録（ADR 6 件・backlog 2 件）を移す。ID の道具は ATRS とスキルを 1 つの ID 空間で検査する。"
tags: [adr, skill, documentation]
id: "50f9e6a4-01c6-4f4a-93b3-07a4303a9b77"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:40:00+09:00
---

# スキル port-lang の決定と作業項目をスキルのバンドルへ移し、ATRS からはリンクで参照する

## Context and Problem Statement

スキル port-lang の文書を `references/docs/` に移し、OKF v0.2 のバンドルにした。スキル自身の意思決定記録・作業項目は `references/docs/{decision,backlog}` で持つ（[スキルの ADR 87b9](../../.agents/skills/port-lang/references/docs/decision/87b9-skill-docs-as-okf-bundle.md)）。
これまで ATRS の `docs/decision`・`docs/backlog` には、ATRS の記録と、アプリに依存しないスキルの記録が混ざっていた。
[ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md) は、ATRS にも影響するスキルの改訂について、ATRS の ADR を作ることを求めている。
この ADR では、ATRS 側で何を移し、移した記録をどう参照するかを決める。

## Decision Drivers

* スキルを持ち出したとき、スキルの決定と作業が一緒に持ち出されること
* ATRS の記録の ID・ファイル名を変えないこと
* 移したことで ATRS の参照（本文・`depends_on`・索引）が壊れないこと

## Considered Options

* 純粋にスキルの記録だけを `git mv` で移す。ATRS の部分を含む記録は ATRS に残す
* ATRS の部分を含む記録も分けて移す（ATRS の部分は ATRS に新しい記録を作る）
* 何も移さず、今後の記録だけをスキルに置く

## Decision Outcome

Chosen option: "純粋にスキルの記録だけを `git mv` で移す。ATRS の部分を含む記録は ATRS に残す", because 移す記録の内容を変えずに済み、ATRS の参照の張り直しが小さいため。プロジェクトオーナーが選んだ。

### 移した記録

| 種類 | 項目 | 移す先 |
| --- | --- | --- |
| ADR | [edc8](../../.agents/skills/port-lang/references/docs/decision/edc8-skill-scripts-and-generic-lean-libraries.md)、[7fe4](../../.agents/skills/port-lang/references/docs/decision/7fe4-move-trace-attributes-to-skill.md)、[6edf](../../.agents/skills/port-lang/references/docs/decision/6edf-lean-package-under-skill-assets-lean.md)、[0b83](../../.agents/skills/port-lang/references/docs/decision/0b83-porting-conditions-and-workflow.md)、[0eea](../../.agents/skills/port-lang/references/docs/decision/0eea-trace-tooling-unresolved-details.md)、[9cd9](../../.agents/skills/port-lang/references/docs/decision/9cd9-rehash-diff-impact-details.md) | `.agents/skills/port-lang/references/docs/decision/` |
| backlog | [1ae4](../../.agents/skills/port-lang/references/docs/backlog/1ae4-machine-refinement-framework.md)、[a936](../../.agents/skills/port-lang/references/docs/backlog/a936-lang-semantics-rust.md) | `.agents/skills/port-lang/references/docs/backlog/` |

* ATRS の部分を含む記録は ATRS に残す。たとえば ADR c336・f4e1・01d4・0bd3・e2a4・70eb・9ac6・cc24、backlog f7b7・ae04・114a・38fb・ffdc・a8be・c7e8・d77c・0d1a がそれに当たる。後から分けて移してよい。そのときは `ids.py move` を使う。
* ADR 3e1d は内容はスキルのものだが、[ADR 796c](796c-models-in-lean-and-sources-traced-at-both-ends.md) に置き換えられ、ATRS の仕様へのリンクを多く持つため、ATRS に残す。
* 移した記録の中の ATRS への参照は、リンク無しの来歴の文（「ATRS の ADR xxxx」）にした。移した backlog の ATRS への `depends_on`（backlog be49）は外した。
* 新しいスキルの決定・作業は、スキルのバンドルに置く。アプリに依存しない判断・作業がそれに当たる。ATRS に固有の判断と、スキルの改訂が ATRS に及ぼす影響は、引き続き ATRS の `docs/decision`・`docs/backlog` に置く（[decision-records.md](../rules/decision-records.md)・[backlog.md](../rules/backlog.md)）。

### ATRS からの参照

* ATRS の文書から、スキルの記録へはリンクで参照する。本文の `ADR xxxx`・`backlog xxxx` もスキルの記録に解決する（ID の空間は 1 つ）。どちらのバンドルか紛らわしいときは「スキルの ADR xxxx」と書く。
* ATRS の項目は、`depends_on` でスキルの項目を指してよい（例: backlog d77c・eff6 → a936、0be7 ほか → 1ae4）。
* 優先順位（ATRS の ADR → `docs/rules/` → スキル）は変えない。スキルの記録は、スキルの方法の一部として扱う。

### ID の道具

* `trace/project.json` の `ids.kinds` に、スキルの `references/docs/decision`・`references/docs/backlog` を加える。
* `ids.isolated` にスキルのバンドルを挙げる。`ids.py check` は、スキルの文書が ATRS を指していないことを検査する。
* `docs/index.md` には、スキルのバンドルの索引へのリンクを置く。スキルの記録を 1 件ずつは載せない。

### Consequences

* Good, because スキルの記録がスキルと一緒に持ち出される。
* Good, because ATRS の参照（`depends_on`・本文・索引）は、1 つの ID 空間で検査されたまま保たれる。
* Bad, because ATRS の記録を読むときに、スキルの記録を別の索引で探す必要がある。
* Bad, because ATRS の部分を含む記録が ATRS に残るため、スキルの決定の全体は当面 2 か所にまたがる。

### Confirmation

* `tools/ci/lean.sh` の `ids.py check` が通る。
* `docs/backlog/README.md` の依存の列のリンクがすべて解決する。

## Pros and Cons of the Options

### ATRS の部分を含む記録も分けて移す

* Good, because スキルの決定がスキルにそろう。
* Bad, because `accepted` の記録を分けるには新しい記録が要り、参照の多い記録（ADR 01d4・c336・0bd3・70eb）の張り直しが大きい。

### 何も移さない

* Good, because 何も変えずに済む。
* Bad, because スキルを持ち出すと、既にある決定の理由が失われる。

## More Information

* [スキルの ADR 87b9](../../.agents/skills/port-lang/references/docs/decision/87b9-skill-docs-as-okf-bundle.md)（スキル側の決定）、[スキルの backlog de90](../../.agents/skills/port-lang/references/docs/backlog/de90-skill-docs-okf-bundle-and-records.md)（作業）
* [ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md)（スキルへの切り出し）、[ADR a0f1](a0f1-documentation-format-okf-v0-2.md)（OKF）、[ADR f57e](f57e-uuid-ids-for-decisions-and-backlog.md)（UUID の ID）
* スキルの保守の規則: [maintenance.md](../../.agents/skills/port-lang/references/docs/maintenance.md)
