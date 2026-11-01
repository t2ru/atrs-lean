---
type: Backlog Item
title: "ATRS の Lean の宣言をモジュール名の下に置き、証明課題を機能のモジュールに集める"
description: "スキルの ADR 1a30 の規則（NS-1・TR-L）を ATRS の lean/ に適用する。layout-check の入口を置き、Spec・SourceModel・Abstraction・Tests・Tools の宣言をモジュール名の下へ改名し、運賃計算とマスタ参照の R・W・C 課題を Abstraction.Fare・Abstraction.MasterData に集め、文書・ベクタ・manifest を追従させる。"
tags: [backlog, lean, namespace]
id: "9ed87238-9ff7-4a2f-8a57-331dcd01710e"
state: done
depends_on: ["ce23298a-ee5e-4458-9b32-0037b17a7c02"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T22:40:00+09:00
---

# ATRS の Lean の宣言をモジュール名の下に置き、証明課題を機能のモジュールに集める

## 目的

ATRS の Lean で、名前から定義の場所が分かり、機能の証明課題が 1 つのモジュールで読めるようにする（[スキルの ADR 1a30](../../.agents/skills/spec-pivot/references/docs/decision/1a30-lean-module-namespace-layout.md)）。

## 範囲

- 入口 `lean/Tools/LayoutCheck.lean`（`lake exe layout-check`）と `tools/ci/lean.sh` の手順
- `Spec`: 複数の型をまとめたモジュールの型をモジュール名の下へ改名する（`Spec.Model.FlightType` など）。マスタの行の型は `Spec.MasterData` の下（`Spec.MasterData.Airport`）に、暦日の補助は `Spec.Prim.Date` の下に置く。参照の機械は `Spec.MasterQuery`（`Spec.MasterQuery.queryMachine`）にする。`Spec.Prim.Int`・`Format`・`Text`・`Time`、`Spec.CodeList`・`Spec.EnvPre` の名前をモジュール名の下に置く
- `SourceModel.FareQuery.ticketHelper`・`ticketReserveService`（旧 `SourceModel.MasterQuery.Providers.*`）
- `Abstraction`: 機能のモジュール `Abstraction/Fare.lean`（ABS-001・002・003・004・101・102・112）と `Abstraction/MasterData.lean`（ABS-026・127）。補題のモジュール `Abstraction.Fare.BasicFareRun`・`FareRun`・`TotalFareRun`・`Abstraction.MasterData.QueryRun`（旧 `*Refines`）。義務の束 `*Adequate` と 1 歩の可換式 `*Refines_commutes`（旧 `*Commutes`）を機能のモジュールに、その部品（環境の前提 `env*` と証人）を `Abstraction.{Fare,MasterData}.Adequacy` に置く（旧 `Abstraction.Adequacy`）。ほかの下位モジュールの名前空間をモジュール名にする
- `Tests`・`Tools` の補助の定義を、モジュール名の下に置く（`main` を除く）
- 追従: `conformance/` のベクタの `modelDef`、`tools/conformance/seed_lean.py`、`trace/checks.json`、`docs/` の名前の言及、`trace manifest`・`trace rehash` による manifest と生成区画

## 対象外

- 名前の言葉の見直し（モジュール名の下へ移すほかは、名前を変えない）
- 来歴（[log.md](../log.md)）の旧い名前の書き換え

## 完了条件

- [x] `lean/` で `lake build`・`lake test`・`lake exe axiom-check`・`lake exe obligation-check`・`lake exe layout-check`（違反 0）が通る
- [x] `trace check` が TR-L1・TR-L2 を含めて通り、`trace manifest --check` が通る
- [x] `rename.py check` で、旧い名前が来歴の他に残っていない
- [x] `tools/ci/lean.sh` が通る

## 参照

- [スキルの ADR 1a30](../../.agents/skills/spec-pivot/references/docs/decision/1a30-lean-module-namespace-layout.md)、[スキルの backlog ce23](../../.agents/skills/spec-pivot/references/docs/backlog/ce23-lean-module-namespace-layout.md)
- [rules/atrs-porting.md](../rules/atrs-porting.md#機能名層をまたいで共通)
