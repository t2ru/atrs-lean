---
type: Backlog Item
title: "実装済みの範囲の抽象化検証（トップレベルの Refines・Adequate）と移植元側の段階導入"
description: "運賃計算・マスタの読み込みの R 課題を義務の束 Machine.Adequate に束ね、機能を並置した Spec.machine・SourceModel.machine についてトップレベルの Machine.Refines・Machine.Adequate を Abstraction.lean に示す。移植元側の追跡の検査を、移植元側の作業項目の完了で失敗扱いにする（側ごとの段階導入）。"
tags: [backlog, lean, abstraction, refinement, proof, traceability]
id: "76a63816-6065-4ee7-97a0-c0a0c60e79a0"
state: done
depends_on: ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227", "bbcce088-c475-4378-9cc6-e3d821acc0f5", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T23:30:00+09:00
---

# 実装済みの範囲の抽象化検証（トップレベルの Refines・Adequate）と移植元側の段階導入

## 目的

実装済みの範囲（マスタ・設定・コードリストの読み込みと運賃計算）は、R 課題（ABS-026・001・002・004）を個別に証明していた。
しかし、次の 2 つが欠けていた。

- トップレベルの主定理: どこを見れば移植元と [Spec] の関係が分かるかが、ファイルの上から読めない。
- 空虚化を防ぐ義務の帰結: `Refines` と `Machine.Adequacy` の義務（`Sound`・`InitIs`・`InitSurj`・`TotalUnder`・`EnvWitness`）が別々の定理に散らばり、束としてまとまっていない。

あわせて、追跡の検査が移植先側の作業項目（Rust）の完了を待って警告にとどまっていたので、以後の機能の取り込みで実装済みの範囲が壊れても CI が失敗しなかった。
これを、移植元側の作業項目の完了で失敗扱いにする（[ADR a41d](../decision/a41d-top-level-refines-adequate-and-source-side-gate.md)）。

## 範囲

- スキル spec-pivot（[スキルの ADR ab9e](../../.agents/skills/spec-pivot/references/docs/decision/ab9e-adequate-bundle-sum-and-side-staging.md)）
  - `Machine.Adequate`（義務の束）と系 `run_init`・`exists_ok`、出力が関数で決まる機械の 1 歩の可換式 `Refines.complete_fun`
  - `Machine.Sum`（機械の並置と、`Refines.sum`・`Adequate.sum`・`Adequate.congrPre`）
  - obligation-check の GA と G3' の並置、`check_obligations.py` の OB-A、`trace check` の側ごとの段階導入と、束の閉包を TR-P に含めること、`--feature`・`--rule` の絞り込み
- ATRS
  - `Spec.machine`・`SourceModel.machine`（実装済みの範囲の機能の並置）
  - `Abstraction.refines`・`Abstraction.adequate`（`Abstraction.lean` のトップレベル）
  - R 課題ごとの束 `queryAdequate`・`basicFareAdequate`・`fareAdequate`・`totalFareAdequate` と 1 歩の可換式（旧 `Abstraction.Adequacy`。いまは機能のモジュール `Abstraction.MasterData`・`Abstraction.Fare`）
  - `trace/features.json` の側ごとの作業項目と、ロケータの機能への振り直し
  - 運賃計算・マスタの読み込みの移植元の項目の `@[source]`（ドメインモデルのアクセサ・列挙定数、DDL の制約、シード、設定・MyBatis の Bean）
  - 規約（完了の定義）と文書

## 対象外

- 入口の R 課題（HTTP・レポートの受信）と入口からの到達（TR-PE。[backlog a89e](a89e-http-contract-adapter.md)・[backlog ac71](ac71-reservation-history-report.md)）
- 移植先側（`TargetModel`・`Refinement`。[backlog eff6](eff6-target-model-fare-and-refinement.md) ほか）

## 完了条件

- [x] `Abstraction.lean` に `Abstraction.refines : Machine.Refines …`・`Abstraction.adequate : Machine.Adequate …` があり、`sorry`・公理無しで証明した
- [x] R 課題ごとの束（ABS-026・001・002・004）を、同じ課題 ID の `@[obligation]` で示した（GA・OB-A が通る）
- [x] Fare・MasterData の移植元側の TR-S1・TR-P・TR-D・TR-K の指摘が 0 件で、移植元側の作業項目が完了しているので失敗扱いで判定される
- [x] 規約と文書（ADR、traceability、abstraction.md、AGENTS.md）を更新した
- [x] `tools/ci/lean.sh` が全段通る
- [x] 本項目を `done` にした状態で、`@[source]` を 1 つ外すと `trace check` が失敗することを確かめた（`SourceModel.Domain.Model.Airport` の `toString` を外した dump で TR-S1 の誤り。`doing` の間は警告）

## 参照

- [ADR a41d](../decision/a41d-top-level-refines-adequate-and-source-side-gate.md)
- [ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)
- [backlog 25f7](25f7-fare-calculation-both-models.md)、[backlog bbcc](bbcc-fare-abstraction-proofs.md)
