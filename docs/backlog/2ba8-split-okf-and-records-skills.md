---
type: Backlog Item
title: "spec-pivot から OKF の管理と記録の管理を別のスキルに分ける"
description: "スキル spec-pivot から、移植に関係の無い OKF のバンドルの管理と ADR・backlog の管理を、汎用のスキル okf-bundle・work-records に分け、ATRS の設定と検査を移す。"
tags: [backlog, docs, okf, records, skill]
id: "2ba87822-3fb9-493d-9f0e-04e2ce2ff7dc"
state: done
depends_on: ["ddbd8fec-9d87-4ba1-a2bf-58d0f159ae50"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:40:00+09:00
---

# spec-pivot から OKF の管理と記録の管理を別のスキルに分ける

## 目的

スキル spec-pivot に同居していた、移植に関係の無い文書の道具と規則（OKF の管理、タスクの管理など）を別のスキルにし、spec-pivot を移植の方法に絞る。文書の管理だけを、他のリポジトリでも使えるようにする。

## 範囲

- スキル okf-bundle: `okf_check.py`・`docmv.py`・違反例を移し、規則 `rules/bundle.md` と自身のバンドルを置く。設定を `.okf.json` にする。
- スキル work-records: `ids.py` を移し、`id_fields` と記録の形の検査（A1・B1）、`--self-test` を足す。規則 `rules/records.md`・雛形・自身のバンドルを置く。設定を `.work-records.json` にする。
- スキル spec-pivot: 規則・道具の一覧・`SKILL.md` を移植の方法に絞り、版を 0.22 にする（[スキルの ADR 22b4](../../.agents/skills/spec-pivot/references/docs/decision/22b4-split-okf-and-records-skills.md)）。
- ATRS: `trace/project.json` から `okf`・`ids` を除き、`tools/docs/legacy_ids.py`、mise のタスク、規約・`AGENTS.md` を改める（[ADR 625d](../decision/625d-adopt-okf-bundle-and-work-records-skills.md)）。

## 対象外

- 既存の記録の移動（ADR 330e・748c・87b9、backlog de90・a49c・97a7 は、来歴として spec-pivot に残す）。
- 完了済みの ADR・backlog の本文にある旧パス（来歴として残す）。
- `lean/rename.py` など、Lean と移植に使う道具（spec-pivot に残す）。

## 完了条件

- [x] `okf_check.py --self-test`・`docmv.py --self-test`・`ids.py --self-test` が通る（`mise run docs:self-test`）。
- [x] `ids.py check` が ADR・backlog の件数を保って通り、`legacy_ids.py check` が通る（`mise run docs:ids`）。
- [x] `okf_check.py` が ATRS の `docs/` と 3 つのスキルのバンドルで通る（`mise run docs:okf`）。
- [x] `trace` の自己テストとビルドが、`okf`・`ids` を除いた `trace/project.json` で通る（`mise run trace:self-test`・`trace:build`）。

## 参照

- [ADR 625d](../decision/625d-adopt-okf-bundle-and-work-records-skills.md)、[スキルの ADR 22b4](../../.agents/skills/spec-pivot/references/docs/decision/22b4-split-okf-and-records-skills.md)
- スキル [okf-bundle](../../.agents/skills/okf-bundle/SKILL.md)・[work-records](../../.agents/skills/work-records/SKILL.md)
- [rules/documentation.md](../rules/documentation.md)・[rules/decision-records.md](../rules/decision-records.md)・[rules/backlog.md](../rules/backlog.md)
