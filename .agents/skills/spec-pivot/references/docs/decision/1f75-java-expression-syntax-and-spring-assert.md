---
type: Architecture Decision Record
title: "Java の式の構文 java! と Spring の Assert を言語パックに置き、移植元のモデルを原典と同じ字面で書く"
description: "移植元のモデルの式を、原典の Java の式と同じ字面で書けるよう、LangSemantics.Java に式の構文 java!（JLS の優先順位・数値昇格・リテラルの型・キャスト・短絡評価・例外を投げうる式）を置く。展開した項は原始関数を手で書いた項と構文として同じで、証明は変えない。あわせて Spring の Assert を同じ名前で置き、原典の語彙とモデルの語彙の対応表を言語パックに書く。"
tags: [adr, java, language-pack, lean, review]
id: "1f75dff9-234a-4753-a6ee-83c506a96ae5"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T18:00:00+09:00
---

# Java の式の構文 java! と Spring の Assert を言語パックに置き、移植元のモデルを原典と同じ字面で書く

## Context and Problem Statement

`SourceModel` は原典の振る舞いを、言語の意味論ごと写す。意味論は `LangSemantics.Java` の名前付きの原始関数（`j32add`・`jdmul`・`jd2i`・`jdiv32` など）で与える。
原始関数で式を書くと、原典の 1 行が入れ子の関数適用になる。

```
Java:  (int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))
Lean:  jd2i (jdmul (jd (j32add basicFareOfRoute boardingClassFare).val) (jdmul (jd multiplicationRatio.val) (jdLit "0.01")))
```

人が原典と見比べて写しを確かめるには、この差が妨げになる。`J32 = BitVec 32` なので、Lean の `/` は符号無しの除算になり、書き誤りを招く。
Spring の `Assert.isTrue` などは、`jAssert`・`match … | none => throw …` で書かれ、名前が原典と合わない。

## Decision Drivers

* 原典と同じ字面で書けること（見比べやすさ）
* 証明を壊さないこと。展開した項は、原始関数で書いた項と同じであること
* Java の意味（JLS の優先順位・数値昇格・リテラルの型）を、構文の側で取り違えないこと
* `LangSemantics` はアプリに依存しない。メタ層（`Lean`）への依存は、構文に閉じ込める

## Considered Options

* 構文の種類 `jexpr` と項の構文 `java! e` を置き、型を見て原始関数の項に展開する（elaborator）
* `HAdd J32 JDouble JDouble` などのインスタンスで、Lean の演算子に Java の意味を与える
* 原始関数のまま書き、docstring に Java の式を写す

## Decision Outcome

Chosen option: "構文の種類 `jexpr` と項の構文 `java! e` を置き、型を見て原始関数の項に展開する", because 展開した項が手書きと同じ項になり、
証明（`simp only [jdmul, …]` など）がそのまま通るからである。インスタンスの方法では項が `HAdd.hAdd …` になり、証明の書き換えが要る。
`int` の `/` は例外を投げうるので `JResult` を返す必要があり、Lean の演算子の型では表せない。

* `LangSemantics.Java.Expr`: `java! e`。優先順位と結合は JLS 15、リテラルの型は JLS 3.10（`100` は `int`、`100L` は `long`、`0.01`・`1d` は `double`）、
  数値昇格は JLS 5.6.2、キャストは `(int)`・`(long)`・`(double)`、比較は `decide (a.val ≥ n)`（整数リテラルは値のまま）、`&&`・`||` は短絡評価、
  メソッド呼び出し `f(a, b)` は Lean の関数適用、Lean の項は `⟪t⟫` で埋め込む。整数の `/`・`%` と、`JResult` を返す呼び出しを含む式は `JResult τ` になり、
  部分式を左から `>>=` でつなぐ。扱わないもの（`double` の比較・剰余、`float` など）は誤りにする。
* 演算子ごとの `elab`（`jbin%` など）は再帰しない。再帰は `macro_rules` の展開で行うので、`partial` を使わない。
* 検査: `Test.LangSemantics.JavaExpr` が、展開した項と原始関数の項が構文として同じこと（`#guard_expr … =ₛ …`）、実行した値、扱わない式の誤りを確かめる。
* 原始関数を足した: `j32neg`・`j64neg`・`jrem64`・`JDouble.neg`・`jdneg`。
* `LangSemantics.Java.Spring`: `Assert.isTrue`・`notNull`・`notEmpty`・`hasText`（原典と同じく値を返さない）と、検査した値を返す `notNullValue`・`notEmptyValue`、
  検査を満たす場合の `rfl` の補題。`jAssert` は `Assert.isTrue` に置き換えて削除した。
* 静的検査（`check_lean.py`）: モデルの層は `Lean` を import してはならない。例外は、言語パックの式の構文のモジュール `LangSemantics.<Lang>.Expr` だけとする。
  構文の種類の定数（`Lean.Parser.Category.jexpr`）は、Lean が名付けるので `@[ns_exception]`（E3）とする。
* 文書: [lang/java/semantics.md](../lang/java/semantics.md#式の構文-java) に構文と、原典の語彙とモデルの語彙の対応表を書く。

### Consequences

* Good, because 原典の 1 行がモデルの 1 行になり、行ごとに見比べられる
* Good, because 展開した項が変わらないので、既存の証明と Merkle ハッシュの意味は変わらない（式の書き換えで Merkle が変わる定義は `rehash` で再検査する）
* Bad, because `LangSemantics.Java` が `Lean` のメタ層に依存する（構文のモジュールに限る）
* Bad, because 展開は型に依存するので、型の分からない部分式（`⟪t⟫` の中など）では誤りの報告が分かりにくいことがある

### Confirmation

`lake build`（`assets/lean`）が `Test.LangSemantics.JavaExpr` を通すこと。`check_lean.py --self-test` が式の構文のモジュールの例外を確かめること。

## More Information

* 適用先 ATRS の ADR e41c（`SourceModel` を原典のソースツリーの形に並べ、式・語彙を原典と同じ字面にする）
* 配置の検査と対照表: [ADR 8a3c](8a3c-mirror-layout-check-and-review-view.md)
