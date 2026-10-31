---
type: Backlog Item
title: "名前付きの成分の必要性の義務と検査（G9）"
description: "ADR 9ac6 の成分の必要性（成分を外した R 課題の命題が偽であること）を、Machine.Adequacy の補題（always・not_of_error・not_of_mismatch・Pinned.not_of_mismatch・TotalUnder.not_always）、反例、obligation-check の G9、文書の W 課題・SPEC-006・保証の限界に反映する。"
tags: [backlog, lean, refinement, proof, traceability]
id: "ae0448b1-af43-4d95-af6f-cfec8c58768c"
state: done
depends_on: ["f7b791e2-3d95-4436-a2d9-0320ad16a4fa"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:40:00+09:00
---

# 名前付きの成分の必要性の義務と検査（G9）

## 目的

[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md) の義務は、名前付きの成分（差異・環境の前提）が自明でないことは確かめるが、要ることは確かめない。
vacuity detection の考え方（[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）に従い、成分を外すと R 課題の命題が偽になることを、義務と検査に加える。
業務モデルを書き始める前に、形を決めておく。

## 範囲

- スキル port-lang の `assets/lean/Machine/Adequacy.lean`: `always`・`anyOf`・`Covers`・`Covers₂`、`Refines.not_of_error`・`not_of_stuck`・`not_of_mismatch`・`Pinned.not_of_mismatch`、`Machine.TotalUnder.not_always`
- `assets/lean/MachineTest/Adequacy.lean`: 反例 12（不要な差異）・13（環境の選択による吸収）と、前提型・観測型・環境の前提の必要性の正例
- `lean/Trace/Obligation.lean`: G9（差異 ID ごとの必要性と被覆、ID は定数に 1 つ、`anyOf` の葉、R 課題の基底の環境の前提）と、必要性の形の `@[obligation]` を G0 の誤りにしない例外。JSON の `necessity`
- テスト: `lean/Tests/ObligationFixture.lean`・`lean/Tests/Main.lean`
- 文書
  - ADR 9ac6
  - [abstraction.md](../spec/abstraction.md)・[refinement.md](../spec/refinement.md) の W 課題・SPEC-006・空虚化を防ぐ義務
  - [assurance.md](../spec/assurance.md)
  - スキルの architecture・traceability・verification・conformance・spec-documents

## 対象外

- 仕様の変異テスト（[backlog 0d1a](0d1a-mutation-testing-of-named-components.md)）
- 各機能の必要性の定理（W 課題として、各機能の backlog 項目で示す）

## 完了条件

- [x] `MachineTest/Adequacy.lean` で、反例 12・13 と、必要性の正例（前提型・観測型・環境の前提）を証明した
- [x] `obligation-check` が `Tests/ObligationFixture.lean` の正例を通し、違反例（必要性の無い差異、被覆の循環、ID を束ねた定数、`anyOf` の不要な葉、必要性の無い環境の前提）を G9 として検出することを `lake test` で確かめた
- [x] 必要性の形の W 課題が G0 の誤りにならないことを確かめた
- [x] 文書（ADR 9ac6、登録簿、保証の限界、スキル）を更新した
- [x] 「強すぎる前提になっていないか」を主眼に敵対的レビューを行い、指摘を直すか、直さない理由を ADR 9ac6 に記した
- [x] `tools/ci/lean.sh` が全段通る

## 参照

- [ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)
- [ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)
- [backlog f7b7](f7b7-refinement-non-vacuity.md)
