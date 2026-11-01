---
type: Architecture Decision Record
title: "モデルの評価を速くする実装は、元の定義と等しいことの定理を付けた @[csimp] で与える"
description: "SourceModel・Spec などの定義を、評価（適合テストベクタの実行）のために書き換えない。速い実装は別の定義とし、元の定義と等しいこと（行の並びも含めて）を定理にして @[csimp] で登録し、コンパイル後のコードだけを差し替える。証明の無い implemented_by は使わない。SQL の写しの結合のために、条件を押し下げた入れ子ループの結合 Bag.crossWhere と補題 filter_cross_split・select_cross_split を LangSemantics.Sql に置く。"
tags: [adr, skill, lean, tests, sql]
id: "b187efa0-aa73-495a-a49b-62bd6333eb43"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# モデルの評価を速くする実装は、元の定義と等しいことの定理を付けた @[csimp] で与える

## Context and Problem Statement

移植元のモデル（`SourceModel`）は、原典の構造をそのまま写す。最適化を写してはならない（[lean/rules.md](../lang/lean/rules.md#書き方)）。
SQL の文も、`LangSemantics.Sql` の演算で、字面どおりに `FROM a, b, c WHERE …` を `Bag.select`（`Bag.cross` …）と写す。
この写しをそのまま評価すると、直積の全件を作ってから選ぶことになる。

適用先 ATRS では、4 表の結合 1 回が約 650 万組になった（便マスタ 126 × 区間 20 × 空港 51 × 空港 51）。
適合テストはケースごとにこれを評価するため、シードの DB を使う照合だけで、CI で約 6 分かかっていた。
定義を書き換えずに、評価だけを速くする方法が要る。

## Decision Drivers

* モデルの定義（原典との対応・`@[source]` のハッシュ・証明）を変えないこと
* テストが評価するコードと、証明が扱う定義の一致が、定理で保証されること
* 公理・`native_decide`・証明の無い差し替え（`implemented_by`・`extern`）を持ち込まないこと
* テストの側で、モデルの関数の写しを持たないこと

## Considered Options

* 速い実装を別の定義にし、元の定義と等しいことの定理を付けて `@[csimp]` で登録する
* テストの側で、速い版の関数（照会の入口から結合まで）を書き、元の関数と等しいことを定理にする
* `@[implemented_by]` で速い実装に差し替える
* モデルの定義そのものを、条件を押し下げた形に書き換える

## Decision Outcome

Chosen option: "速い実装を別の定義にし、元の定義と等しいことの定理を付けて `@[csimp]` で登録する", because 定義も証明も変えず、テストは同じ関数を呼んだまま、コンパイル後のコードだけが定理で保証された実装になるため。
テストの側の写しは入口からの関数をすべて複製することになり、`implemented_by` は等しさの証明が無く、定義の書き換えは原典との字面の対応を壊す。

### 規則

* 評価のための速い実装は、元の定義と同じモジュールに、元の定義の直後に置く。名前は元の名前に用途を付けたもの（例: `findAllJoin`）とし、docstring に評価用であることを書く。
* `@[csimp] theorem <元の名前>_eq_<用途> : @<元の定義> = @<速い実装>` を、元の定義を使う箇所より前に置く。`@[csimp]` は、それより後にコンパイルされる宣言にだけ効く。
* 等しさは無条件（すべての入力について）でなければならない。前提の下でだけ等しい形は `@[csimp]` にできないので、テストの側の補題にとどめる。
* `@[csimp]` が変えるのはコンパイラの出力だけである。カーネルの評価（`decide`）と証明は、元の定義を見る。
* 証明の無い `implemented_by`・`extern` は、これまでどおり使わない。

### LangSemantics.Sql の道具

* `Bag.crossWhere q a b`: 左の行 `x` ごとに、右の行のうち `q x` を満たすものだけを並べる直積（入れ子ループの結合）。
* `QueryLemmas.filter_cross_split`・`select_cross_split`: 直積の選択の条件が `P (x, b) = p x && q x b` に分かれるなら、`(Bag.cross xs bs).filter P = Bag.crossWhere q (xs.filter p) bs`（行の並びも含めて等しい）。多段の直積には繰り返し使う。条件の連言の並べ替えは、`Truth.holds_and` と `Bool` の結合律・交換律で示す。

### Consequences

* Good, because 適用先 ATRS の、シードの DB を使う照合が、手元で 600 秒超から約 2 秒になった（同じ検査・同じケース数）。
* Good, because 速い実装が元の定義と違えば、定理が通らない。
* Bad, because 実行の結果は、Lean のコンパイラが `@[csimp]` を正しく扱うことに依存する。これは、ベクタの期待値をコンパイルした Lean で計算することの、既存の信頼の基盤に含まれる。
* Bad, because 元の定義の直後に、原典に無い宣言が増える（`Bag.crossWhere` を使う評価用の定義と定理）。

### Confirmation

* `@[csimp]` の定理がビルドで証明される（`lake build`）。公理は `axiom-check` で確かめる。
* 適合テストのケース数と結果が、差し替えの前と同じである（適用先の記録で確かめる）。

## Pros and Cons of the Options

### テストの側で、速い版の関数を書く

* Good, because モデルのモジュールに宣言が増えない。
* Bad, because 入口（起動時の読み込み・照会）から結合までの関数を、テストの側にすべて写すことになる。モデルの変更に追従しなければならない。

### `@[implemented_by]` で差し替える

* Good, because 等しさの証明が要らない。
* Bad, because 等しさが保証されず、テストが評価するものと証明が扱うものが食い違いうる。[lean/rules.md](../lang/lean/rules.md#全域性と安全性) で禁じている。

### モデルの定義そのものを書き換える

* Good, because 宣言が増えない。
* Bad, because 原典の SQL の字面との対応が崩れ、既存の証明も書き直しになる。

## More Information

* 規則: [lean/rules.md](../lang/lean/rules.md#書き方)
* 道具: `assets/lean/LangSemantics/Sql/Query.lean`（`Bag.crossWhere`）、`assets/lean/LangSemantics/Sql/QueryLemmas.lean`（`filter_cross_split`・`select_cross_split`）
* 来歴: 適用先 ATRS の ADR 9c1c（シードの DB を使う照合の速さ）
