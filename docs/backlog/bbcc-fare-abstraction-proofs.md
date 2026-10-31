---
type: Backlog Item
title: "運賃計算の抽象化証明"
description: "運賃計算の抽象化証明課題（ABS-001〜005・007、W 課題 ABS-101・102・112）を Abstraction.Fare で証明する。3 段に分け、第 1 段で double の誤差を定理で確定した。"
tags: [backlog, abstraction, proof, fare]
id: "bbcce088-c475-4378-9cc6-e3d821acc0f5"
state: doing
depends_on: ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T16:13:09+09:00
---

# 運賃計算の抽象化証明

## 目的

[Source] と [Spec] の運賃の差異を、一致する前提と差の上限として定理で確定させる。

## 範囲

3 段に分ける（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)。プロジェクトオーナーの決定）。

| 段 | 内容 |
| --- | --- |
| 第 1 段 | double・BigDecimal の補題（スキル）と、基本運賃・運賃の差異の条件（D-001・D-002）の定理 |
| 第 2 段 | R 課題 ABS-001（基本運賃）・ABS-002（運賃）、C 課題 ABS-003、L 課題 ABS-007、W 課題 ABS-101・102 |
| 第 3 段 | R 課題 ABS-004（合計金額）、L 課題 ABS-005、W 課題 ABS-112、運賃計算の `Spec` の機械、SPEC-001 |

- R 課題は `Machine.Refines` の形で示す。具体側の入力は DB のマスタと引数とし、ABS-026 の α と補題を再利用する
- 前提型の差異の述語 `dev_D001`・`dev_D002`・`dev_D012`（`@[deviation]`）
- ABS-006（ピーク時期）は ABS-026 に含めて取り消した（ADR e9bc）

## 対象外

- `native_decide`・`bv_decide` を証明に使うこと（[verification.md](../../.agents/skills/port-lang/references/verification.md#証明の運用)）
- 運賃計算の `source-model/` ベクタと Java オラクルとの一致（[backlog f18c](f18c-java-oracle-harness.md) に移した。ADR e9bc）

## 完了条件

- [x] D-001 を確定した（第 1 段。値域内に差異があり、証拠は 100 円・積算比率 29%。ABS-007 は否定的に解決した）
- [x] D-001・D-002 の前提を、差異が起きない十分条件の定理で書き、[abstraction.md](../spec/abstraction.md) を更新した（第 1 段）
- [ ] 各課題に対応する定理が `sorry`・`native_decide`・`bv_decide` 無しで存在する
- [ ] 運賃計算の SPEC-001 を証明した
- [ ] D-012 の前提を証明結果で更新し、TR-D が通る

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

## 参照

- [abstraction.md](../spec/abstraction.md)
- [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md)、[ADR e9bc](../decision/e9bc-fare-double-analysis.md)
