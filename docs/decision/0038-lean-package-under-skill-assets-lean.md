---
type: Architecture Decision Record
title: "スキル port-lang の Lean パッケージを assets/lean/ に置く"
description: "スキル port-lang の assets 直下にあった Lake パッケージ langSemantics（LangSemantics・Machine とその検査）を assets/lean/ に移し、assets の下を資産の種類ごとに分ける。Lean 以外の資産（assets/verus/ など）は assets/lean/ の外に置く。"
tags: [adr, layout, lean, skill]
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T18:00:00+09:00
---

# スキル port-lang の Lean パッケージを assets/lean/ に置く

## Context and Problem Statement

スキル port-lang の `assets/` の直下に、Lake パッケージ `langSemantics` の `lakefile.lean`・`lean-toolchain`・`lake-manifest.json` と、`LangSemantics`・`Machine` とその検査の Lean ソースが並んでいた。
一方、`assets/` には Lean 以外の資産も置く予定である。`LangSemantics.Rust` の Verus 版 `assets/verus/model_prelude.rs` がそれに当たる（[ADR 0035](0035-generate-verus-mirror-from-target-model.md)、[backlog 0028](../backlog/0028-verus-mirror-generator.md)）。
Lake パッケージのルートに他言語の資産が混ざると、パッケージの範囲と資産の種類の区別がつきにくい。

## Decision Drivers

* Lake パッケージの範囲を、ディレクトリで明確にすること
* 他言語の資産を、Lean のパッケージと並べて置けること
* パッケージ名・モジュール名・依存の向きを変えないこと

## Considered Options

* Lean のパッケージを `assets/lean/` に移す
* `assets/` 直下のままにして、他言語の資産をその下に置く

## Decision Outcome

Chosen option: "Lean のパッケージを `assets/lean/` に移す", because Lake パッケージの範囲と資産の種類がディレクトリで一致するため。

* `assets/lean/` を Lake パッケージ `langSemantics` のルートとする。パッケージ名・ライブラリ（`LangSemantics`・`Machine`・`LangSemanticsTest`・`MachineTest`）・モジュール名は変えない。
* Lean 以外の資産は、`assets/<種類>/`（例: `assets/verus/`）に置く。
* ATRS では、ルートの `lakefile.lean` と `lean/lakefile.lean` の `require langSemantics` と、CI（`tools/ci/lean.sh`・`tools/ci/check_lean.py`・`.github/workflows/lean.yml`）のパスを `assets/lean` に改める。

### Consequences

* Good, because Lake パッケージの範囲が `assets/lean/` で閉じ、他言語の資産と混ざらない。
* Good, because モジュール名が変わらないため、`lean/` の import と証明に影響しない。
* Bad, because スキルを Lake 依存として取り込むプロジェクトは、`require` のパスを改める必要がある。

## More Information

* [ADR 0025](0025-extract-porting-method-as-agent-skill.md)（スキルへの切り出し）、[ADR 0035](0035-generate-verus-mirror-from-target-model.md)（Verus の写し）
* スキル: [SKILL.md](../../.agents/skills/port-lang/SKILL.md)、[lean/rules.md](../../.agents/skills/port-lang/references/lean/rules.md#ルートのワークスペースlsp-用)
* ATRS への適用: [rules/atrs-porting.md](../rules/atrs-porting.md)
