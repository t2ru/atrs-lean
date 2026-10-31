---
type: Backlog Item
title: "名前付きの成分の必要性の義務と検査（G9）"
description: "ADR 0042 の成分の必要性（成分を外した R 課題の命題が偽であること）を、Machine.Adequacy の補題（always・not_of_error・not_of_mismatch・Pinned.not_of_mismatch・TotalUnder.not_always）、反例、obligation-check の G9、文書の W 課題・SPEC-006・保証の限界に反映する。"
tags: [backlog, lean, refinement, proof, traceability]
id: "0032"
state: doing
depends_on: ["0030"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:40:00+09:00
---

# 名前付きの成分の必要性の義務と検査（G9）

## 目的

[ADR 0039](../decision/0039-refinement-non-vacuity-obligations.md) の義務は、名前付きの成分（差異・環境の前提）が自明でないことは確かめるが、要ることは確かめない。
vacuity detection の考え方（[ADR 0042](../decision/0042-vacuity-literature-necessity-and-mutation.md)）に従い、成分を外すと R 課題の命題が偽になることを、義務と検査に加える。
業務モデルを書き始める前に、形を決めておく。

## 範囲

- スキル port-lang の `assets/lean/Machine/Adequacy.lean`: `always`、`Refines.not_of_error`・`not_of_mismatch`・`Pinned.not_of_mismatch`、`Machine.TotalUnder.not_always`
- `assets/lean/MachineTest/Adequacy.lean`: 反例 12（不要な差異）・13（環境の選択による吸収）と、前提型・観測型・環境の前提の必要性の正例
- `lean/Trace/Obligation.lean`: G9（成分の必要性）と、必要性の形の `@[obligation]` を G0 の誤りにしない例外。JSON の `necessity`
- テスト: `lean/Tests/ObligationFixture.lean`・`lean/Tests/Main.lean`
- 文書
  - ADR 0042
  - [abstraction.md](../spec/abstraction.md)・[refinement.md](../spec/refinement.md) の W 課題・SPEC-006・空虚化を防ぐ義務
  - [assurance.md](../spec/assurance.md)
  - スキルの architecture・traceability・verification・conformance・spec-documents

## 対象外

- 仕様の変異テスト（[backlog 0033](0033-mutation-testing-of-named-components.md)）
- 各機能の必要性の定理（W 課題として、各機能の backlog 項目で示す）

## 完了条件

- [ ] `MachineTest/Adequacy.lean` で、反例 12・13 と、必要性の正例（前提型・観測型・環境の前提）を証明した
- [ ] `obligation-check` が `Tests/ObligationFixture.lean` の正例を通し、違反例（必要性の無い差異、`Pinned` を伴わない必要性、必要性の無い環境の前提）を G9 として検出することを `lake test` で確かめた
- [ ] 必要性の形の W 課題が G0 の誤りにならないことを確かめた
- [x] 文書（ADR 0042、登録簿、保証の限界、スキル）を更新した
- [ ] `tools/ci/lean.sh` が全段通る

## 参照

- [ADR 0042](../decision/0042-vacuity-literature-necessity-and-mutation.md)
- [ADR 0039](../decision/0039-refinement-non-vacuity-obligations.md)
- [backlog 0030](0030-refinement-non-vacuity.md)
