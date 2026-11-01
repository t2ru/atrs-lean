---
type: Architecture Decision Record
title: "運賃計算の double の誤差を定理で確定し、D-001・D-002 の前提を正確な条件で書く"
description: "backlog bbcc の第 1 段として、[Source] の運賃計算の double の式と [Spec] の整数の式の差を、因子の表（カーネルの評価）と閉じた形の補題で確定する。D-001 は値域内に差異があり（ABS-007 は否定的に解決）、D-001・D-002 の前提を「100 で割り切れない、または因子が安全」の形に改める。あわせて ABS-006 を ABS-026 に含めて取り消し、Java の原典実行との一致の完了条件を backlog f18c に移し、bbcc を 3 段に分ける。"
tags: [adr, abstraction, fare, double, lang-semantics]
id: "e9bcbb3d-8249-4211-98d4-6634ff10dec5"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T18:30:00+09:00
---

# 運賃計算の double の誤差を定理で確定し、D-001・D-002 の前提を正確な条件で書く

## Context and Problem Statement

[backlog bbcc](../backlog/bbcc-fare-abstraction-proofs.md) では、運賃計算の R 課題（ABS-001・002・004）を証明する。
[Source] は運賃を `double` で計算し、[Spec] は厳密な整数で計算する。

| 量 | [Source] | [Spec] |
| --- | --- | --- |
| 基本運賃 | `(int)(X * (c * 0.01))`（`X` = 区間の運賃 + 加算料金、`c` = 積算比率） | `X·c / 100`（切捨て） |
| 運賃 | `ceilFare((int)(b * (1 − r * 0.01)))`（`b` = 基本運賃、`r` = 割引率） | `ceilTo(b·(100−r) / 100, 100)` |

これまでの既知差異は、次の前提で書かれていた。

* D-001: シードの範囲の全探索では差異が 0 件で、値域全体で差異があるかは未確定（L 課題 ABS-007 で一致を試みる）。前提はシードの比率と金額の範囲。
* D-002: 1430 円・30% の例がある。前提はシード由来の基本運賃と割引率。

R 課題を証明するには、どの入力で差異が起きるかを定理で確定する必要がある。シードの値を列挙する前提では、値域の大半が前提の外になり、R 課題の適用範囲が狭い。

## Decision Drivers

* 基本原則 1〜3（[ADR c336](c336-foundational-principles.md)）。差異は、証明と文書で明示する。
* `sorry`・公理・`native_decide` を使わない（check_lean・axiom-check）
* 前提型の差異の前提は、差異が起きない入力をなるべく広く含む（R 課題の適用範囲を広げる）
* 言語意味論（スキルの assets）に、アプリに依存しない補題を置く（[ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md)）

## Considered Options

* 閉じた形の補題と因子の表で、差異が起きない十分条件を定理にする
* 差異が起きる正確な条件（`k` の仮数と因子の相対誤差の積と、半 ulp の比較）を定理にする
* シードの値を列挙する前提のまま、R 課題を証明する

## Decision Outcome

Chosen option: "閉じた形の補題と因子の表で、差異が起きない十分条件を定理にする", because 条件が整数の剰余と因子の表だけで書け、移植先の言語でも検査しやすいからである。
正確な条件は、`k` の 2 進の仮数に依存し、文書の前提として読みにくい。十分条件で前提の外になるのは、安全でない因子で、`X·c` が 100 で割り切れる入力だけである。

### 数学

因子 `F = fm·2^(−fs)` は `c/100` を double に丸めた値である。`X·F` を double に丸めて切り捨てた値は、`rneTrunc (X·fm) (2^fs)` に等しい（`jd2i_mul_nat`）。

* 因子は `c/100` の相対誤差 `2^-48` 以内にある（`Close`）。運賃の因子は、`1 − r·0.01` の引き算の桁落ちで、相対誤差が `6·2^-52` まで大きくなる（`r` = 81〜83・91〜99）。
* `X·c` が 100 で割り切れないとき、厳密値の小数部は 0.01 以上なので、誤差で整数部は変わらない。[Source] = [Spec]。
* 割り切れるとき（厳密値は整数 `k`）、[Source] は `k` か `k − 1` である。
  * 因子が `c/100` 以上か、下回っても相対誤差が `2^-54` 未満（`Safe`）なら、`k` に丸められる。[Source] = [Spec]。
* 運賃では、切り捨てた値が 1 小さくなっても、100 円単位の切上げで差になるのは `k ≡ 1 (mod 100)`（`b·(100−r) ≡ 100 (mod 10000)`）のときだけである。差は 100 円である。

### 決定

| 項目 | 決定 |
| --- | --- |
| 閉じた形の補題（スキル） | `LangSemantics.Java.JDouble` に、`floorLog2`・`roundAtExp` の性質、`toJ32 ∘ ofRat` の閉じた形 `rneTrunc`、`(int)(X * F)` の閉じた形 `jd2i_mul_nat` を置く（`JDouble.Lemmas`）。`BigDecimal` に `bdCeilHundredUp_val`（非負の値の 100 円単位の切上げ）を置く。補題のために、`JDouble.lean` の補助の関数（`pow2`・`geTwoPow`・`floorLog2`・`roundAtExp`・`truncInt`）と `roundDiv` を `private` でなくする |
| 比較の定理（ATRS） | `Abstraction.Fare.Double`（`rneTrunc` と `⌊X·c/100⌋` の比較）と `Abstraction.Fare.Factors`（因子の表、基本運賃・運賃の定理、証拠）に置く。値域（`X·c < 100·2^28`）は、[domain-model.md](../spec/domain-model.md#値域) の上限（`X ≤ 10,000,000`・`c ≤ 1,000`、`b ≤ 100,000,000`）を含む |
| 因子の表 | 積算比率 1〜1000・割引率 0〜99 のすべての因子が `Close` であること、安全でない因子の一覧（積算比率 49 個・割引率 33 個）を、カーネルの評価（`decide +kernel`）で確かめる。ビルドに約 20 秒かかる |
| 近さの許容 | `Close` の許容を `2^-48` とする。`2^-52` では運賃の因子の桁落ちを含まない。比較の定理は、許容 `2^-48` でも値域（`X·c < 100·2^28`）で成り立つ |
| D-001 | 値域内に差異がある（ABS-101: 100 円・積算比率 29% で [Source] 28 円、[Spec] 29 円）。ABS-007（値域全体での一致の試み）は否定的に解決した。ABS-007 を「[Source] は [Spec] に等しいか 1 小さく、1 小さいのは `X·c` が 100 で割り切れ、因子が安全でないときに限る」に改める（第 2 段で `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.calculateBasicFare` について示す。本段の `basicFare_src` がその中身）。前提 `dev_D001` は「`X·c` が 100 で割り切れないか、積算比率の因子が安全」に改める |
| D-002 | 前提 `dev_D002` は「`b·(100−r) mod 10000 ≠ 100` か、割引率の因子が安全」に改める（`fare_src_eq`）。シードの割引率のうち 0・5・10・20 は安全で、30 は安全でない |
| 十分条件であること | 安全でない因子でも、差異が実際に起きるとは限らない。開発中の探索では、積算比率 447（`X` ≤ 20,000）と割引率 68・92（`b` ≤ 200,000）で差異が見つからなかった。前提は十分条件なので、これらの入力も前提の外になる。[assurance.md](../spec/assurance.md) に記す |
| ABS-006 | ピーク時期の参照 `peakTimeOn`・積算比率 `multiplicationRatioOn` の一致は ABS-026（`Abstraction.MasterData.Query`）で証明済みなので、ABS-006 は ABS-026 に含めて取り消す（プロジェクトオーナーの決定） |
| 運賃の R 課題の具体側の入力 | DB のマスタと引数とし、ABS-026 の α と補題を再利用する（bbcc 第 2・3 段。プロジェクトオーナーの決定） |
| Java の原典実行との一致 | bbcc の完了条件「運賃計算の `source-model/` ベクタが Java の原典実行と一致する」を [backlog f18c](../backlog/f18c-java-oracle-harness.md) に移し、bbcc の `depends_on` から f18c を外す（プロジェクトオーナーの決定） |
| bbcc の分割 | 第 1 段（本 ADR の補題と差異の解析）、第 2 段（ABS-001・002・003・007 と W 課題 ABS-101・102）、第 3 段（ABS-004・005・112、合計金額の `Spec` の機械、SPEC-001）に分ける（プロジェクトオーナーの決定） |
| 抽象機械の置き場所（第 2 段） | 基本運賃・運賃の抽象機械 `Spec.Fare.basicFareMachine`・`fareMachine`（`Machine.pure`）と、その SPEC 課題（SPEC-001〜003・007）は第 2 段で作る。R 課題に抽象機械が要るためである。第 3 段には合計金額の機械が残る。PRE は、設定とマスタの不変条件、搭乗クラスの存在（MD-3）、値域（`routeBasicFare + extraCharge ≤ 10,000,000`、基本運賃 `≤ 100,000,000`（`Range.maxBasicFare` を追加）、割引率 `≤ 100`） |
| 具体側の入力（第 2 段） | 基本運賃は、DB のマスタ・設定・`calculateBasicFare` の引数とし、許される並びのどれかで起動時の読み込み（`SourceModel.MasterQuery.load`。`run` から切り出した）を行ってから計算する（`SourceModel.FareQuery.basicFareConcrete`）。運賃の `calculateFare` はマスタを読まないので、引数だけを入力とする（`fareConcrete`）。「DB と引数」の決定は、マスタを読む操作に当てはめる |
| D-027 の定数（第 2 段） | 引数の `null` と負の値も [Spec] の型で表せない入力として D-027 に含め、機械ごとに `@[deviation "D-027"]` の定数（`dev_D027BF`・`dev_D027F`）を置く。必要性（G9）は ID ごとに少なくとも 1 つの R 課題で示せばよく、ABS-127 で足りる |
| 差異の前提の形（第 2 段） | `dev_D001`・`dev_D002` は、安全でない因子の一覧（`unsafeBasicRatios`・`unsafeDiscountRates`。カーネルの評価の表 `basicFactor_unsafe`・`fareFactor_unsafe` と同じ）への非所属で書く。double の値を参照せず、言語に依らない数の条件になる |
| 合計金額の [Spec]（第 3 段） | `Spec.Fare.totalFare` を、フライトのキーの列と搭乗者の年齢の列の関数 `totalFareOfKeys` で書き直す（`totalFare` は `totalFareOfKeys` を呼ぶ。等しいことは `totalFare_eq`）。合計金額が観測するのはキーと年齢だけで、空席数・氏名は [Source] の入力に無いからである。抽象機械 `totalFareMachine` の入力は (設定, マスタ, キーの列, 年齢の列) とし、PRE は設定とマスタの不変条件、予約フライト数 1〜2・搭乗者数 1〜6・年齢 0〜999、便名が空白でないこと、各フライトのマスタが在ること（プロジェクトオーナーの決定） |
| 合計金額の具体側の入力（第 3 段） | DB のマスタ・設定・選択フライト情報（`SelectFlightForm`）・搭乗者とする。1 歩は、許される並びのどれかで読み込み、`TicketHelper.toFlightList`（`SourceModel.Ticket`。`@[source]` 付き）でフライト情報を組み立て、`calculateTotalFare` を呼ぶ（プロジェクトオーナーの決定） |
| D-001・D-002・D-012 の前提（第 3 段） | `dev_D001T`・`dev_D002T` は、各フライトに基本運賃・運賃の前提を課す。`dev_D012` は、各フライトで `b × (childFareRate − r) ≤ 2,147,483,647` とする。小児がいなければ折り返しは合計に現れないが、登録どおりの十分条件のまま置く。D-001・D-002 の必要性は ABS-101・102 で足りるので、ABS-004 では D-012 の必要性（ABS-112）だけを示す |
| 証人の文字列（第 3 段） | 文字列の述語（`hasText`・`AirportCd.WellFormed`）は、`String.all`・`String.any` がカーネルの評価で進まない。証人の PRE は、`toList` に書き直す補題（`string_any_toList`・`String.all_bool_eq`）で示す。[Spec] の定義は変えない |

### Consequences

* Good, because D-001 が確定し、R 課題の前提が値域の大半を含む（シードの値の列挙でなくなる）
* Good, because 前提が整数の剰余と因子の一覧で書け、移植先でも検査できる
* Good, because `(int)(X * F)` の閉じた形は、ほかのアプリの double の式にも使える
* Bad, because 前提が十分条件なので、差異の起きない入力の一部（積算比率 447 など）も前提の外になる
* Bad, because `LangSemantics.Java` の補助の関数が公開になり、名前を変えにくくなる
* Bad, because 因子の表の検査で、ビルドが約 20 秒長くなる

### Confirmation

* `Abstraction.Fare.Factors` の定理（`basicFare_src`・`basicFare_src_eq`・`fare_src`・`fare_src_eq`・`basicFactor_unsafe`・`fareFactor_unsafe`・`basicFare_witness`・`fare_witness`）が、`sorry`・公理なしでビルドされる（axiom-check）。
* 安全でない因子の一覧は、開発中に Python（ホストの binary64）で求めた一覧と一致した。
* 安全でない因子ごとの最小の反例を開発中に探索し、積算比率 47 個・割引率 31 個で差異があることを確かめた（例: 積算比率 820 で `X = 15`、割引率 80 で `b = 5`）。
* 第 2 段: R 課題 ABS-001 `basicFareRefines`・ABS-002 `fareRefines`、C 課題 ABS-003 `fare_diff`、L 課題 ABS-007 `runBasicFare_spec`、W 課題 ABS-101 `need_D001`・ABS-102 `need_D002` を証明した（obligation-check の G0〜G9 に誤り無し。D-001・D-002 の必要性を認識）。
* 第 3 段: R 課題 ABS-004 `totalFareRefines`、L 課題 ABS-005 `runTotalFare_eq`、W 課題 ABS-112 `need_D012` を証明した（obligation-check で D-012 の必要性を認識）。スキルに `int` の減算・乗算・除算の値域内の補題（`j32sub_val_of_inRange`・`j32mul_val_of_inRange`・`jdiv32_val_of_nonneg`）を加えた。

## More Information

* 補足（2026-10-31）: 本 ADR で「比較の定理（ATRS）」とした層（`Abstraction.Fare.Double` と `Factors` の因子の判定・`jd2i_factor`）は、アプリに依存しないので、スキルの `LangSemantics.Java.JDouble.Compare` に移した（[ADR edc8](../../.agents/skills/spec-pivot/references/docs/decision/edc8-skill-scripts-and-generic-lean-libraries.md)）。決定は変わらない。ATRS の `Abstraction.Fare.Factors` には、因子の表と差異の条件・証拠が残る。
* [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)、[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md)、[ADR e41d](e41d-exact-integer-arithmetic-in-abstract-model.md)
* [abstraction.md](../spec/abstraction.md#既知差異)（D-001・D-002）、[fare-calculation.md](../spec/fare-calculation.md)
