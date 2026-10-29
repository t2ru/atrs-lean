---
type: Architecture Decision Record
title: "移植元モデルの基本演算を、検証可能な整数エミュレーションとして定義する"
description: "[Source] の int32・double・BigDecimal・UTF-16 を整数のみでエミュレート可能な名前付き演算として定義する。"
tags: [adr, java, numeric]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 移植元モデルの基本演算を、検証可能な整数エミュレーションとして定義する

## Context and Problem Statement

[Source] モデル（[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)）は Java の基本型の意味論を再現しなければならない。
Lean 標準の `Float` は C の double に委譲される不透明な型で、算術の性質を証明できない。
また [Source] を他言語へ移植する場合にも、その言語の浮動小数点実装に依存せずに再現できることが望ましい。
どの Java の意味論を、どの表現で定義するかを決める。

## Decision Drivers

* Lean で性質を証明できること
* 任意の言語で整数演算だけでビット単位に再現できること
* 原典で実際に使われている演算に限定し、汎用 IEEE 754 実装を作らないこと

## Considered Options

* 必要な演算だけを、有理数 + 丸め関数による binary64 ソフトモデルと、BitVec 32 による int32 で定義する
* Lean 標準 `Float` と `Int32` をそのまま使う
* 汎用の IEEE 754 ライブラリを実装する

## Decision Outcome

Chosen option: "必要な演算だけのソフトモデル", because 証明可能性と移植可能性を両立し、範囲を原典の使用箇所に限定できるため。

定義する演算（名前は spec でも共通に使う）:

| 名前 | Java の対応 | 意味 |
| --- | --- | --- |
| `J32` | `int` | 32 ビット 2 の補数。Lean では `BitVec 32` |
| `j32add`, `j32sub`, `j32mul` | `+ - *` on `int` | 2^32 を法とする折り返し |
| `jdiv32` | `/` on `int` | 0 方向切捨て。`MIN_VALUE / -1 = MIN_VALUE` |
| `JDouble` | `double` | IEEE 754 binary64 の有限値・±0・±∞・NaN。Lean では符号・仮数（`Nat`）・指数（`Int`）で表し、値の意味は有理数で与える |
| `jd(n)` | `(double) n`（int → double） | 正確（|n| < 2^53） |
| `jdLit("0.01")` | リテラル `0.01` | 0.01 に最も近い binary64（`0x3F847AE147AE147B`） |
| `jdmul`, `jdsub` | `*`, `-` on `double` | 正確な有理数の結果を round-to-nearest-even で binary64 に丸める |
| `jd2i` | `(int) d` | NaN → 0、0 方向切捨て、`int` 範囲外は飽和（`Integer.MIN_VALUE`/`MAX_VALUE`） |
| `bdCeilHundredUp` | `new BigDecimal(n).setScale(-2, RoundingMode.UP).intValue()` | 100 の倍数へ **0 から遠ざかる方向** に丸める（負数は −∞ 側）。`intValue()` は下位 32 ビットへの切詰め |
| `utf16Len` | `String.length()` | UTF-16 符号単位数（補助文字は 2） |
| `jLocalDate` | `java.time.LocalDate` | 先発グレゴリオ暦の暦日。`plusDays`, `minusDays`, `isBefore`, `isAfter` |

* これらの演算はアプリケーションに依存しない言語意味論として `LangSemantics.Java` に置く（[ADR 0035](0035-generate-verus-mirror-from-target-model.md)）。ATRS が使わない演算も、同じ方針で必要になった時点で追加してよい。
* ソフトモデルの値は Lean 標準 `Float` の結果とテストで突き合わせる（テストドライバのみで `Float` を使用）。
* 他言語で [Source] を移植する場合、上表の演算をその言語の整数演算で実装するか、ネイティブ型（Java, C の double 等）を使ってもよい。ただし `conformance/source-model/` のベクタで一致を確認しなければならない。

### Consequences

* Good, because 運賃計算の [Source] と [Spec] の関係を Lean で証明できる
* Good, because double を持たない言語でも [Source] を再現できる
* Bad, because 丸め関数の実装と検証の工数がかかる

### Confirmation

* `LangSemantics.Java.JDouble` の各演算について、ネイティブ `Float` との一致を多数の入力（原典の値域を網羅する範囲）で確認するテストを置く。
* `jdLit("0.01")` のビット表現が `0x3F847AE147AE147B` であることを定理または `decide` で確認する。

## Pros and Cons of the Options

### 必要な演算だけのソフトモデル

* Good, because 証明可能・移植可能・範囲が小さい
* Bad, because 原典で新たな演算が見つかるたびに追加が必要

### Lean 標準 Float / Int32

* Good, because 実装が不要
* Bad, because `Float` の算術は証明できず、[Spec]/[Source] の関係を定理にできない

### 汎用 IEEE 754 ライブラリ

* Good, because 将来の演算追加に強い
* Bad, because 過大な工数。原典が使わない演算（除算・平方根・非正規化数の全網羅など）の検証まで必要になる

## More Information

* Java Language Specification §15.17（乗除演算）, §5.1.3（縮小変換）
* [backlog 0002](../backlog/0002-lang-semantics-java.md)
* （補足 2026-10-30）[ADR 0033](0033-foundational-principles.md) により、上の「他言語で [Source] を移植する場合」も基本原則に従う。その移植は `Spec` をリファインする移植先モデル（`TargetModel`）として扱い、[Source] と同じ振る舞いをする点は移植先の既知差異 `T-NNN` として登録する。ネイティブの double を使う場合、ベクタでの一致は保証の限界として [spec/assurance.md](../spec/assurance.md) に記載する（[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)）。`LangSemantics.Java.JDouble` とネイティブ `Float` との突き合わせは、言語意味論の忠実性の決定論的な検査として扱う（限界: 突き合わせた入力の範囲）。
