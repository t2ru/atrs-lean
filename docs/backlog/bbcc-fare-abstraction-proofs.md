---
type: Backlog Item
title: "運賃計算の抽象化証明"
description: "運賃計算の抽象化証明課題（ABS-001〜005・007、W 課題 ABS-101・102・112）を Abstraction.Fare で証明する。3 段に分け、double の誤差を定理で確定し、基本運賃・運賃・合計金額の R 課題を証明した。"
tags: [backlog, abstraction, proof, fare]
id: "bbcce088-c475-4378-9cc6-e3d821acc0f5"
state: done
depends_on: ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T17:49:17+09:00
---

# 運賃計算の抽象化証明

## 目的

[Source] と [Spec] の運賃の差異を、一致する前提と差の上限として定理で確定させる。

## 範囲

3 段に分ける（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)。プロジェクトオーナーの決定）。

| 段 | 内容 |
| --- | --- |
| 第 1 段 | double・BigDecimal の補題（スキル）と、基本運賃・運賃の差異の条件（D-001・D-002）の定理 |
| 第 2 段 | R 課題 ABS-001（基本運賃）・ABS-002（運賃）、C 課題 ABS-003、L 課題 ABS-007、W 課題 ABS-101・102、基本運賃・運賃の `Spec` の機械と SPEC 課題 |
| 第 3 段 | R 課題 ABS-004（合計金額）、L 課題 ABS-005、W 課題 ABS-112、合計金額の `Spec` の機械、SPEC-001 |

- R 課題は `Machine.Refines` の形で示す。具体側の入力は DB のマスタと引数とし、ABS-026 の α と補題を再利用する
- 前提型の差異の述語 `dev_D001`・`dev_D002`・`dev_D012`（`@[deviation]`）
- ABS-006（ピーク時期）は ABS-026 に含めて取り消した（ADR e9bc）

## 対象外

- `native_decide`・`bv_decide` を証明に使うこと（[verification.md](../../.agents/skills/port-lang/references/verification.md#証明の運用)）
- 運賃計算の `source-model/` ベクタと Java オラクルとの一致（[backlog f18c](f18c-java-oracle-harness.md) に移した。ADR e9bc）

## 完了条件

- [x] D-001 を確定した（第 1 段。値域内に差異があり、証拠は 100 円・積算比率 29%。ABS-007 は否定的に解決した）
- [x] D-001・D-002 の前提を、差異が起きない十分条件の定理で書き、[abstraction.md](../spec/abstraction.md) を更新した（第 1 段）
- [x] 基本運賃・運賃の R 課題（ABS-001・002）と ABS-003・007・101・102 の定理が `sorry`・`native_decide`・`bv_decide` 無しで存在する（第 2 段）
- [x] 基本運賃・運賃の機械の SPEC-001〜003・007 を証明した（第 2 段）
- [x] 合計金額の課題（ABS-004・005・112）の定理が `sorry`・`native_decide`・`bv_decide` 無しで存在する（第 3 段）
- [x] 合計金額の機械の SPEC-001〜003・007 を証明した（第 3 段）
- [x] D-012 の前提を証明結果で更新し、TR-D が通る（第 3 段）

## 第 1 段の結果

| 定理 | 内容 |
| --- | --- |
| `LangSemantics.Java.JDouble.jd2i_mul_nat` | `(int)((double) X * F)`（`F = fm·2^(−fs)`）の閉じた形 `min J32.maxValue (rneTrunc (X·fm) (2^fs))` |
| `LangSemantics.Java.JDouble.rneTrunc_spec` | `rneTrunc` の不等式の形（丸めた仮数と、最近接・偶数の条件） |
| `LangSemantics.Java.bdCeilHundredUp_val` | 非負の値の 100 円単位の切上げ |
| `Abstraction.Fare.rneTrunc_factor` | `rneTrunc` と `⌊X·c/100⌋` の比較（`Close` な因子。割り切れなければ一致、割り切れれば一致か 1 小さい、`Safe` なら一致） |
| `Abstraction.Fare.basicFactor_ok_all`・`fareFactor_ok_all` | 積算比率 1〜1000・割引率 0〜99 の因子は `Close`（`decide +kernel`） |
| `Abstraction.Fare.basicFactor_unsafe`・`fareFactor_unsafe` | 安全でない因子の一覧（積算比率 49 個・割引率 33 個） |
| `Abstraction.Fare.basicFare_src`・`basicFare_src_eq` | 基本運賃の [Source] と [Spec] の関係と、D-001 の前提の下での一致 |
| `Abstraction.Fare.fare_src`・`fare_src_eq` | 運賃の [Source] と [Spec] の関係（差は 0 か 100 円）と、D-002 の前提の下での一致 |
| `Abstraction.Fare.basicFare_witness`・`fare_witness` | 差異の証拠（100 円・29% で 28 と 29、1430 円・30% で 1000 と 1100） |

## 第 2 段の結果

| 定理・定義 | 内容 |
| --- | --- |
| `Spec.Fare.basicFareMachine`・`fareMachine` | 基本運賃・運賃の抽象機械（`Machine.pure`）と SPEC-001〜003・007 |
| `SourceModel.MasterQuery.load` | 起動時の読み込み（`run` から切り出した）。`Abstraction.MasterData.load_correct` |
| `SourceModel.FareQuery.basicFareConcrete`・`fareConcrete` | 基本運賃（DB のマスタ・設定・引数）・運賃（引数）の具体機械 |
| `Abstraction.Fare.aiBF`・`aiF`・`dev_D001`・`dev_D002`・`dev_D027BF`・`dev_D027F` | α と差異の述語（一覧 `unsafeBasicRatios`・`unsafeDiscountRates`） |
| `Abstraction.Fare.basicFareRefines`（ABS-001）・`fareRefines`（ABS-002） | R 課題と `InitSurj` |
| `Abstraction.Fare.runBasicFare_spec`（ABS-007）・`fare_diff`（ABS-003） | 前提によらない差の範囲 |
| `Abstraction.Fare.need_D001`（ABS-101）・`need_D002`（ABS-102） | 差異の必要性（G9） |

第 3 段に残るもの: 合計金額の抽象機械・具体機械と ABS-004・005・112、D-012。

## 第 3 段の結果

| 定理・定義 | 内容 |
| --- | --- |
| `Spec.Fare.totalFareOfKeys`・`totalFareMachine` | 合計金額をキーと年齢で書いた関数（`totalFare_eq`）と抽象機械、SPEC-001〜003・007 |
| `SourceModel.Ticket.toFlightList`・`SourceModel.FareQuery.totalFareConcrete` | 選択フライト情報からのフライト情報の組み立てと、合計金額の具体機械 |
| `Abstraction.Fare.aiTF`・`dev_D001T`・`dev_D002T`・`dev_D012`・`dev_D027TF` | α と差異の述語 |
| `Abstraction.MasterData.flightMaster_fare`・`load_correct'` | 便マスタのキャッシュの区間の運賃、読み込みの性質 |
| `Abstraction.Fare.forIn_sum_eq`・`forIn_count_eq` | `for` 文の和・計数 |
| `Abstraction.Fare.runTotalFare_eq`（ABS-005）・`totalFareRefines`（ABS-004） | 合計金額の正しさ（溢れなし）と R 課題・`InitSurj` |
| `Abstraction.Fare.need_D012`（ABS-112） | D-012 の必要性（基本運賃 1 億円・小児 1 名で 17,050,400 円と 60,000,000 円） |

## 参照

- [abstraction.md](../spec/abstraction.md)
- [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md)、[ADR e9bc](../decision/e9bc-fare-double-analysis.md)
