---
type: Backlog Item
title: "リファインメントの空虚化を防ぐ義務と検査"
description: "Machine.Adequacy（ofChoice・FreeFrame・InitIs・Pinned・NoFaultReachable・Glue.ofStd・TotalUnder・EnvWitness・InitSurj・StateSafe・Nontrivial・KernelIs・complete・run）、その反例、追跡属性 @[nondet]・@[std_abs]・@[kernel]・@[env_pre]、検査 obligation-check と check_obligations.py、文書の登録簿を整える。"
tags: [backlog, lean, refinement, proof, traceability]
id: "f7b791e2-3d95-4436-a2d9-0320ad16a4fa"
state: done
depends_on: ["be4969d4-478c-47a9-8fd9-b8cf31202bc8", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:30:00+09:00
---

# リファインメントの空虚化を防ぐ義務と検査

## 目的

`Machine.Refines` は安全性しか保証しない。そのため、緩い [Spec]・強すぎる PRE・粗い貼り合わせ・名前付きの成分の乱用・環境の非決定性による不具合の吸収でも成り立ってしまう。
業務モデルを書き始める前に、これを塞ぐ義務と検査を整える（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)）。

## 範囲

- スキル port-lang の `assets/lean/Machine/Adequacy.lean`
  - `Machine.ofChoice`・`FreeFrame`・`InitIs`、`Refines.Pinned`・`NoFaultReachable`、`Glue.ofStd`、`Machine.TotalUnder`・`Refines.EnvWitness`、`Refines.InitSurj`、`Refines.StateSafe`・`StateSafeConcrete`、`Nontrivial`・`Nontrivial₂`、`KernelIs`
  - 定理 `Refines.complete`（1 歩の可換式）・`Refines.run`（複数歩の模倣）・`Refines.congr`
- `assets/lean/MachineTest/Adequacy.lean`: 抜け道ごとの反例と正例。公理を `MachineTest/Axioms.lean` で固定する
- `lean/Trace/Attr.lean`: `@[nondet]`・`@[std_abs]`・`@[kernel]`・`@[env_pre]`。`@[obligation]` の対象に SPEC-NNN を加える
- `lean/Trace/Obligation.lean`・`lean/Tools/ObligationCheck.lean`（`lake exe obligation-check`。TR-G の G0〜G8）
- `tools/ci/check_obligations.py`（TR-N と、TR-G の文書側）
- テスト: `lean/Tests/ObligationFixture.lean`、`tools/ci/fixtures/obligations/`
- `tools/ci/lean.sh` への組み込み
- 文書
  - ADR 70eb
  - [abstraction.md](../spec/abstraction.md) の空虚化を防ぐ義務・核の列・前提型の差異の影響・入口の R 課題・SPEC-005〜007・N-NNN
  - [refinement.md](../spec/refinement.md) の同じ項目・REF-011・REF-012
  - [assurance.md](../spec/assurance.md) のモデル間の保証の限界
  - スキルの architecture・traceability・conformance・trace-attributes・spec-documents・verification・SKILL.md

## 対象外

- TR-V の実装（ベクタの実行器。[backlog a8ef](a8ef-conformance-vector-format-and-generator.md)）
- `tools/trace check` への統合と TR-P の改訂の実装（[backlog ffdc](ffdc-trace-tooling.md)）
- 各機能の付帯の義務の証明（各機能の backlog 項目）

## 完了条件

- [x] `MachineTest/Adequacy.lean` で、抜け道ごとに「`Refines` は成り立つが、新しい義務は成り立たない」ことを証明した（11 件）
- [x] すべての義務を満たす正例と、`Refines.run` の使用例を証明した
- [x] `obligation-check` が `Tests/ObligationFixture.lean` の正例を通し、違反例（実装後のレビューで作られた迂回を含む）を G0〜G8 の規則ごとに検出することを `lake test` で確かめた
- [x] `check_obligations.py --self-test` が、失敗と警告の両方について通る
- [x] `tools/ci/lean.sh` が全段通る
- [x] 実装後の敵対的レビューを行い、指摘を直すか、直さない理由を ADR 70eb に記した

## 参照

- [ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)
- [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md)
- [backlog 1ae4](1ae4-machine-refinement-framework.md)
