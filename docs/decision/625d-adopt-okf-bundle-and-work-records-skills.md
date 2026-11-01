---
type: Architecture Decision Record
title: "文書の管理にスキル okf-bundle・work-records を使い、設定を .okf.json・.work-records.json に置く"
description: "移植に関係の無い文書の道具と規則を spec-pivot から分けた汎用のスキル okf-bundle（OKF のバンドルとリンクの検査・文書の移動）と work-records（ADR・backlog の形式と ID）を ATRS に置き、設定を trace/project.json の okf・ids からルートの .okf.json・.work-records.json に移す。機能と backlog の対応表の検査は id_fields で宣言し、旧番号の書き換えと登録簿の旧番号の検査は ATRS の tools/docs/legacy_ids.py に移す。"
tags: [adr, documentation, okf, records, skill, tooling]
id: "625d7301-f7f2-4b5c-a38f-ec2430fc782e"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:40:00+09:00
---

# 文書の管理にスキル okf-bundle・work-records を使い、設定を .okf.json・.work-records.json に置く

## Context and Problem Statement

ATRS の文書の検査（[ADR 920d](920d-docs-bundle-check-in-ci.md)）と ADR・backlog の ID の検査（[ADR f57e](f57e-uuid-ids-for-decisions-and-backlog.md)）は、スキル spec-pivot の道具（`scripts/docs/okf_check.py`・`docmv.py`・`ids.py`）で行い、設定は追跡の設定 `trace/project.json` の `okf`・`ids` にあった。
これらは移植の方法とは関係が無い。プロジェクトオーナーの依頼で、スキル spec-pivot から、移植に関係の無いもの（OKF の管理、タスクの管理など）を別のスキルに分ける（[スキルの ADR 22b4](../../.agents/skills/spec-pivot/references/docs/decision/22b4-split-okf-and-records-skills.md)）。
ATRS は、分けたスキルをどう取り込み、設定と ATRS に固有の検査をどこに置くかを決める必要がある。

## Decision Drivers

* 分ける前と同じ検査（ADR 78 件・backlog 44 件の ID・参照、全バンドルの形とリンク）が、CI で通り続けること
* 追跡の設定（`trace/project.json`）に、追跡と関係の無い設定を置かないこと
* ATRS に固有の事情（旧番号の移行、登録簿の表）を、汎用のスキルに持ち込まないこと

## Considered Options

* スキル okf-bundle・work-records を `.agents/skills/` に置き、設定をルートの `.okf.json`・`.work-records.json` に置く。旧番号の道具は ATRS の `tools/docs/` に移す
* 設定を `trace/project.json` に残す
* 旧番号の書き換え（`migrate`）を削除する

## Decision Outcome

Chosen option: "スキルを `.agents/skills/` に置き、設定をルートの `.okf.json`・`.work-records.json` に置く", because 道具がスキルの設定ファイルだけを読むようになり、ATRS の追跡の設定と文書の設定が分かれるからである。

* `.okf.json`: 元の `trace/project.json` の `okf`（形は同じ）。バンドルにスキル okf-bundle・work-records の `references/docs/` を足し、スキル spec-pivot のプロファイルのパスを `references/okf-profile.json` に改めた。`docs/` のプロファイルの `kind`・`outcome_markers` は除いた（記録の形の検査は `ids.py check` に移った）。
* `.work-records.json`: 元の `trace/project.json` の `ids`。`kinds`・`isolated`・`uuid_roots` に 2 つのスキルのバンドルを足し、`trace/features.json` の backlog の欄を `id_fields` で宣言し、`outcome_markers` に `採択` を足した。`registers`・`legacy`・`features`・`backlog_index` は除いた。
* ATRS の `tools/docs/legacy_ids.py`: 旧番号（`NNNN-<slug>.md`、`ADR NNNN`）からの書き換え `migrate` と、登録簿（`docs/spec/abstraction.md`・`docs/spec/refinement.md`）の backlog の列に旧番号が無いことの検査 `check`。対応表は従来どおり `tools/docs/legacy-ids.json`。共通の処理はスキル work-records の `ids.py` を読み込んで使う。
* mise: `docs:ids` は `ids.py check` と `legacy_ids.py check`、`docs:self-test` は `okf_check.py`・`docmv.py`・`ids.py` の自己テスト、`docs:okf` は `okf_check.py`。
* 規約: [documentation.md](../rules/documentation.md)・[decision-records.md](../rules/decision-records.md)・[backlog.md](../rules/backlog.md) は、形式と道具をスキルに委ね、ATRS での当てはめ（置き場所・言語・いつ ADR を書くか・完了の定義）を残す。優先順位では、3 つのスキルを同じ順位に置く（[rules/README.md](../rules/README.md#優先順位)）。

### Consequences

* Good, because `trace/project.json` が追跡の設定だけになる。
* Good, because 文書の管理の規則と道具を、移植をしない他のリポジトリにも持ち出せる。
* Bad, because ATRS のルートに設定ファイルが 2 つ増える。

### Confirmation

* `mise run docs:self-test`・`mise run docs:ids`・`mise run docs:okf` が通る。分けた後の `ids.py check` が、分ける前と同じ ADR・backlog の件数で通る。
* `trace` の自己テストとビルドが、`okf`・`ids` を除いた `trace/project.json` で通る。

## Pros and Cons of the Options

### 設定を `trace/project.json` に残す

* Good, because 設定ファイルが増えない。
* Bad, because 汎用のスキルが、spec-pivot の追跡の設定の置き場所と形に依存する。

### 旧番号の書き換えを削除する

* Good, because 道具が減る。
* Bad, because 旧番号を含む古いブランチを取り込むときに、書き換えの手段が無くなる。

## More Information

* スキルの側: [スキル spec-pivot の ADR 22b4](../../.agents/skills/spec-pivot/references/docs/decision/22b4-split-okf-and-records-skills.md)、スキル [okf-bundle](../../.agents/skills/okf-bundle/SKILL.md)・[work-records](../../.agents/skills/work-records/SKILL.md)
* 作業項目: [backlog 2ba8](../backlog/2ba8-split-okf-and-records-skills.md)
* 前提: [ADR 920d](920d-docs-bundle-check-in-ci.md)（文書の検査を CI に入れる）、[ADR f57e](f57e-uuid-ids-for-decisions-and-backlog.md)（UUID の ID）、[ADR 50f9](50f9-move-skill-records-to-skill-bundle.md)（スキルの記録をスキルに置く）、[ADR 44a0](44a0-mise-tasks-and-uv-for-tools.md)（mise と uv）
