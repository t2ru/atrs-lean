---
type: Architecture Decision Record
title: "命令型の計算の検証の道具: EStateM の Hoare 三つ組と、計算の形を求める簡約のタクティク"
description: "移植元・移植先の命令型の計算（EStateM。状態の表に対する計算やトランザクション）の性質をメソッドごとに積み上げるために、LangSemantics.Core.EStateHoare（Hoare 三つ組と合成の規則）と、状態を与えた形に簡約するタクティク estate_simp（LangSemantics.Core.EStateSimp）・java_estate_simp（LangSemantics.Java.EStateSimp）を assets に置く。Std.Do の mvcgen は使えるが、写しのメソッドを展開すると Assert などの細部が検証条件に混ざるので、経路ごとの計算の形を先に求める。"
tags: [adr, skill, lean, hoare, tactic]
id: "cd901437-577f-4c6e-956d-7c4f41b963ef"
status: stable
decision_status: accepted
date: 2026-11-02
decision-makers: プロジェクトオーナー（適用先 ATRS で、3c の前に検証の道具を整えることを決定）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T18:00:00+09:00
---

# 命令型の計算の検証の道具: EStateM の Hoare 三つ組と、計算の形を求める簡約のタクティク

## Context and Problem Statement

状態を変えるユースケースでは、移植元の計算は命令型の写しになる。例として、適用先 ATRS の予約がある。

* 計算は `EStateM`（例外で終わっても状態を返す）で書く。
* 中身は、Mapper の文、トランザクションの取消、実行環境の障害、`for` 文、Java の検査（`Assert`・`List.get`・`null` の参照）である。

リファインメントの正しさを示すには、メソッドごとに次を積み上げる必要がある。

* 正常に終わったときの値と状態
* 例外で終わったときの例外と状態

ATRS で試したところ、次のことが分かった。

* Lean 4.35 の `Std.Do`（`mvcgen`）は `EStateM` に使える。
* ただし、写しのメソッドを展開すると、検証条件に細部が残る。例: `Assert.notNullValue`、`List.get` の `match`、`decide` の長さ、`EStateM.bind` の関数の形。
* その始末が、メソッドごとの手作業になる。

## Decision Drivers

* 原則 B の正しさの義務を、メソッドの数に比例する手間で示せること。
* 道具はアプリに依存しない（`LangSemantics.Core`・`LangSemantics.Java`）。
* core だけに依存する。

## Considered Options

* (a) 自前の Hoare 三つ組と、状態を与えた形に簡約するタクティクを assets に置く。経路ごとの計算の形を求めてから、場合を分けて示す。
* (b) `Std.Do` の `mvcgen` に、基本の操作の `@[spec]` 補題を足して使う。
* (c) 道具を置かず、メソッドごとに `EStateM` の定義を展開する。

## Decision Outcome

Chosen option: "(a)"。理由は次のとおりである。

* 状態を与えた形（`m s`）で簡約すると、写しのメソッドが、障害・分岐ごとの `if` と結果の入れ子になる。
* これは、[Spec] の対応する関数と場合を分けて突き合わせられる形である。
* ATRS の選択フライトの検証（1 便・往復、便マスタの有無、障害）では、この形で各経路の対応が `sorry` なしで通った。
* (b) は、メソッドの中の `Assert` などを `@[spec]` 補題で個別に始末する必要がある。予約の規模では、(a) より手間が多い。
* (c) は、メソッドごとに同じ簡約を書き直すことになる。

### 決定

| 項目 | 決定 |
| --- | --- |
| `LangSemantics.Core.EStateHoare` | `Hoare P m Q E`: 事前条件 `P` から `m` を実行すると、正常なら `Q 値 状態`、例外なら `E 例外 状態`。<br>合成の規則:<br>- `conseq`・`pure'`・`throw'`・`bind'`・`ite'`・`of_eq`<br>- `forIn'`（`for` 文。不変条件は処理済みの接頭辞と累積値）<br>- `get'`・`set'`・`modifyGet'`<br>- `liftExcept'`（`Except` の結果の持ち上げ）<br>- `tryCatch'`<br>- `run`（`EStateM.run` の結果の性質） |
| `estate_simp [定義, …] at …`（`LangSemantics.Core.EStateSimp`） | 与えた定義と、`EStateM` の束縛・`pure`・`throw`・`get`・`set`・`modifyGet`・`tryCatch` を展開し、状態の引数を `if` と `Except` の `match` の枝に押し込む `simp only`。決定可能な閉じた命題は評価する。名前は定義の場所で解決するので、利用側で開いた名前空間に左右されない |
| `java_estate_simp`（`LangSemantics.Java.EStateSimp`） | `estate_simp` に、Java の写しの簡約を加える。<br>- `null` でない参照の `deref`<br>- `Assert` の成功<br>- `List.get` の 0・1 番目（`JList.get_cons_one` を足した）<br>- `Except` の束縛 |
| 使い方 | 1. メソッドの三つ組を `intro s hs` で状態に下ろし、`java_estate_simp [メソッド, …]` で計算の形にする。<br>2. 障害の条件・文の結果・下位のメソッドの結果で場合を分け、[Spec] の値と突き合わせる。<br>下位のメソッドの三つ組を示したら、上位では `bind'` でつなぐか、その結果の `match` で場合を分ける（`references/docs/lang/lean/rules.md#命令型の計算の検証`） |
| 例と反例 | `Test/LangSemantics/EStateHoare.lean`: 計算の形・逐次・分岐と例外・`for` の不変条件の例と、例外で終わる計算に例外の事後条件 `False` の三つ組が成り立たない反例 |
| 版 | 0.26 |

### Consequences

* Good, because 命令型の写しの検証が、メソッドごとに計算の形と場合分けの同じ手順になる
* Good, because 後続の状態を変えるユースケース（会員・認証・レポート）でも同じ道具を使える
* Bad, because 計算の形は、写しのメソッドの書き方（`do` の構造）に依存する。写しを書き換えると、場合分けの証明を直すことがある

### Confirmation

* `assets/lean` の `lake build` が、`Test/LangSemantics/EStateHoare.lean` の例・反例を含めて通る。
* 適用先 ATRS の `Abstraction.Reserve.ValidateFlights` が、この道具で `sorry` なしに通る。

## More Information

* 来歴: 適用先 ATRS の ADR ab93（予約の第 3 段）
* [lang/lean/rules.md](../lang/lean/rules.md)
