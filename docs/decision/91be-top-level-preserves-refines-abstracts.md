---
type: Architecture Decision Record
title: "トップレベルの主定理を refines・preserves・abstracts にする（adequate の廃止）"
description: "Abstraction.lean・Refinement.lean のトップレベルの主定理を、B メソッドのリファインメント refines（B refines A）、空虚化を防ぐ意味的な義務の束 preserves（A preserves B。Refines を含まない）、その組 abstracts（A abstracts B）の 3 つにする。R 課題ごとの束は *Preserves とする。移植元側の段階導入とゲートは ADR a41d から引き継ぐ。ADR a41d を置き換える。"
tags: [adr, lean, abstraction, refinement, proof]
id: "91be0644-99b4-4f70-9c52-3dbbd8eff66e"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/remote
  at: 2026-10-31T23:59:00+09:00
---

# トップレベルの主定理を refines・preserves・abstracts にする（adequate の廃止）

## Context and Problem Statement

[ADR a41d](a41d-top-level-refines-adequate-and-source-side-gate.md) は、`Abstraction.lean` のトップレベルに `Abstraction.refines`（`Machine.Refines`）と `Abstraction.adequate`（`Machine.Adequate`）を置いた。
`Machine.Adequate` は、`Refines` と空虚化を防ぐ義務の一部を混ぜた束である。そのため、`adequate` が何を主張するのかが語から分からず、`refines` と重複していた。

オーナーの依頼: 「adequate の語彙を廃止し、preserves と refine に分けたい。空虚化を防ぐ証明課題群は preserves とし、refines は含まないようできるか検討」「構造としては (A abstracts B) = (A preserves B) and (B refines A)」「B メソッドの Refines の意味と食い違っていないことも確認」「Refines と Preserves 外の証明課題が必要なら、それを含めた Abstracts 全体の定義もしてほしい」。

アプリに依存しない部分（`Machine.Preserves`・`Machine.Abstracts` の定義、B メソッドとの照合、検査の改訂）は、[スキルの ADR 6b4b](../../.agents/skills/spec-pivot/references/docs/decision/6b4b-preserves-refines-abstracts.md) で決めた。この ADR は、ATRS のトップレベルの主定理と R 課題ごとの束の形を決める。

## Decision Drivers

* 基本原則 2（[ADR c336](c336-foundational-principles.md)）: 抽象モデルと移植元モデルの間に、B メソッドの意味でのリファインメントが証明されていること。`refines` の語がその意味だけを表すこと
* 空虚化を防ぐ義務（[ADR 70eb](70eb-refinement-non-vacuity-obligations.md)）が、`Refines` と独立に、R 課題ごとに 1 つの主張として示されること
* 移植元側の段階導入とゲート（ADR a41d）を保つこと

## Considered Options

* トップレベルの主定理
  * `refines`・`preserves`・`abstracts` の 3 つを置き、`refines` と `preserves` を R 課題の並置から独立に示す
  * `abstracts` だけを置き、`refines`・`preserves` をその射影にする
  * `refines`・`adequate` の名前を残す
* R 課題ごとの束の名前
  * `*Preserves`（`queryPreserves`・`basicFarePreserves`・`farePreserves`・`totalFarePreserves`）
  * `*Abstracts`（`Refines` を含む組）

## Decision Outcome

Chosen option: "トップレベルに `refines`・`preserves`・`abstracts` を置き、R 課題ごとの束は `*Preserves` とする", because `refines` が B メソッドのリファインメントだけを、`preserves` が空虚化を防ぐ義務だけを主張し、互いに独立に証明されていることが定理の形で読めるため。
`abstracts` だけを置くと、`refines` と `preserves` の独立が証明の構成に隠れる。
`*Abstracts` を R 課題ごとに置くと、R 課題の主定理と重複する。

### トップレベルの主張

```lean
theorem Abstraction.refines :
    Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue
theorem Abstraction.preserves :
    Machine.Preserves (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
theorem Abstraction.abstracts :
    Machine.Abstracts (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
```

- `refines` は R 課題の主定理（`queryRefines`・`basicFareRefines`・`fareRefines`・`totalFareRefines`）を `Machine.Refines.sum` で並べ、`Machine.Refines.congrPre` で並置した制限に付け替えて示す。
- `preserves` は R 課題ごとの束（`queryPreserves`・`basicFarePreserves`・`farePreserves`・`totalFarePreserves`）を `Machine.Preserves.sum`・`Machine.Preserves.congrPre` で示す。`Refines` を使わない。
- `abstracts` は `⟨preserves, refines⟩` である。系 `Machine.Abstracts.run_init`・`exists_ok` が使える。
- R 課題ごとの束は、機能のモジュール（`Abstraction.MasterData`・`Abstraction.Fare`）に、R 課題と同じ課題 ID の `@[obligation]` で置く。部品（環境の前提 `env*` と証人）は `Abstraction.MasterData.Preserves`・`Abstraction.Fare.Preserves`（旧 `…Adequacy`）に置く。
- 現行の 4 課題は、基底が `Machine.pure` で、「出力のみ」の差異を使わない（D-001・D-002 は「中断」）。そのため、束の条件付きの成分（`Pinned`・`NoFaultReachable`・`FreeFrame`・`StateSafe`）は既定の証明で閉じ、トップレベルの `abstracts` は全体の定義を満たす。
- `Refinement.lean` も同じ形とし、`TargetModel` ができた時点（[backlog eff6](../backlog/eff6-target-model-fare-and-refinement.md)）で主定理を置く。

### ADR a41d から引き継ぐもの

`Spec.machine`・`SourceModel.machine` の並置、`trace/features.json` の側ごとの作業項目、移植元側の段階導入とゲート、移植元の項目の扱いは、a41d の決定をそのまま引き継ぐ。名前は上のとおりに改める（対応表は `tools/docs/lean-renames-preserves.json`）。

### Consequences

* Good, because `Abstraction.lean` の冒頭で、B メソッドのリファインメント（`refines`）と空虚化を防ぐ義務（`preserves`）が別々に読め、その組（`abstracts`）が B のリファインメントより強いことが分かる
* Good, because 束が `Refines` を含まないので、R 課題の主定理との重複が無くなる
* Bad, because 機能を取り込むたびに、`refines` と `preserves` の両方の並置に R 課題を足す。足し忘れは、R 課題ごとの束（G6・OB-P）と TR-P の検査、トップレベルの型の不一致で検出される

### Confirmation

* `tools/ci/lean.sh` が全段通る（`lake build`・obligation-check の G6・GP、`check_obligations.py` の OB-P、`trace check`）。
* `Abstraction.preserves` の証明が `Machine.Refines` の定理を参照しない。

## More Information

* 置き換える ADR: [ADR a41d](a41d-top-level-refines-adequate-and-source-side-gate.md)
* [スキルの ADR 6b4b](../../.agents/skills/spec-pivot/references/docs/decision/6b4b-preserves-refines-abstracts.md)、[ADR 70eb](70eb-refinement-non-vacuity-obligations.md)
* [backlog cb23](../backlog/cb23-adequate-to-preserves-abstracts.md)
