---
type: Backlog Item
title: "adequate の廃止: Machine.Refines・Machine.Preserves・Machine.Abstracts への分割"
description: "義務の束 Machine.Adequate を、B メソッドのリファインメント Machine.Refines（B refines A）と、空虚化を防ぐ意味的な義務のすべての束 Machine.Preserves（A preserves B。Refines を含まない）、その組 Machine.Abstracts（A abstracts B）に分ける。スキルの定義・検査と、ATRS のトップレベルの主定理・R 課題ごとの束を書き換える。"
tags: [backlog, lean, abstraction, refinement, proof, traceability]
id: "cb239af1-1f7d-4380-82de-3e09299416c5"
state: done
depends_on: ["76a63816-6065-4ee7-97a0-c0a0c60e79a0", "9ed87238-9ff7-4a2f-8a57-331dcd01710e"]
generated:
  by: claude-code/remote
  at: 2026-10-31T23:59:00+09:00
---

# adequate の廃止: Machine.Refines・Machine.Preserves・Machine.Abstracts への分割

## 目的

義務の束 `Machine.Adequate` は、リファインメントと空虚化を防ぐ義務の一部を混ぜていた。語が主張を表さず、R 課題の主定理と重複し、束の外にも空虚化を防ぐ義務が残っていた。
これを `(A abstracts B) = (A preserves B) ∧ (B refines A)` の構造に改める（[ADR 91be](../decision/91be-top-level-preserves-refines-abstracts.md)、[スキルの ADR 6b4b](../../.agents/skills/spec-pivot/references/docs/decision/6b4b-preserves-refines-abstracts.md)）。

## 範囲

- スキル spec-pivot
  - `Machine.Preserves`（条件付きの成分 `pinned`・`noFault`・`freeFrame`・`stateSafe`・`stateSafeC` を含む）・`Machine.Abstracts` と、その並置・系。モジュールの改名（`Machine.Preserves.Pred`・`Machine.{Machine,Glue,Refines}.Preserves`・`Machine.{Machine,Concrete}.Run`）
  - B メソッドの証明義務との照合（[architecture.md](../../.agents/skills/spec-pivot/references/docs/spec/architecture.md#具体機械とリファインメント)）
  - obligation-check の G6（束の `ch`・`outs` の照合）・GP、`check_obligations.py` の OB-P、`scripts/trace` の `preserves`、検査のフィクスチャ
- ATRS
  - R 課題ごとの束 `queryPreserves`・`basicFarePreserves`・`farePreserves`・`totalFarePreserves`
  - トップレベルの `Abstraction.refines`・`Abstraction.preserves`・`Abstraction.abstracts`
  - 改名の対応表 `tools/docs/lean-renames-preserves.json`、`trace/manifest.json`・`trace/features.json`、規約と文書

## 対象外

- 条件付きの成分を持つ束どうしの並置（`Choice` と「出力のみ」の層の並置）。最初の `ofChoice`・「出力のみ」の R 課題（入口の機械。[backlog a89e](a89e-http-contract-adapter.md) ほか）で足す
- 差異の必要性（G9）を `Abstracts` に含めること（課題をまたぐ義務なので W 課題のまま）
- 来歴の文書（置き換えた ADR a41d・ab9e、完了した backlog、変更履歴の過去の行）の書き換え

## 完了条件

- [x] `Machine.Preserves` が `Refines` を含まず、`Machine.Abstracts` が `Preserves ∧ Refines` である
- [x] `Machine.Refines` が B メソッドの証明義務と食い違わないことを照合し、文書に置いた
- [x] R 課題ごとの束とトップレベルの `refines`・`preserves`・`abstracts` を、`sorry`・公理無しで証明した。`preserves` は `Refines` の定理を使わない
- [x] obligation-check の G6・GP、`check_obligations.py` の OB-P、`trace check` が通る
- [x] 規約と文書（ADR、architecture・traceability、abstraction.md・refinement.md、AGENTS.md、完了の定義）を更新した
- [x] `tools/ci/lean.sh` が全段通る

## 参照

- [ADR 91be](../decision/91be-top-level-preserves-refines-abstracts.md)
- [スキルの ADR 6b4b](../../.agents/skills/spec-pivot/references/docs/decision/6b4b-preserves-refines-abstracts.md)
- [backlog 76a6](76a6-source-side-adequacy-gate.md)、[backlog 9ed8](9ed8-atrs-module-namespace-layout.md)
