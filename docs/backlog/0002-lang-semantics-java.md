---
type: Backlog Item
title: "LangSemantics.Java: Java 基本型の意味論"
description: "int32・IEEE 754 binary64（必要部分）・BigDecimal 丸め・UTF-16 文字列・LocalDate を、アプリ非依存の検証可能なモデルとして実装する。"
tags: [backlog, lang-semantics, java]
id: "0002"
state: done
depends_on: ["0001"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T08:33:20+09:00
---

# LangSemantics.Java: Java 基本型の意味論

> 2026-10-29: スキル port-lang の assets に、LangSemantics.Java の初版（core のみ、`#guard` 検査付き、Lean 4.35.0 でビルド済み）がある（[Java.lean](../../.agents/skills/port-lang/assets/lean/LangSemantics/Java.lean)）。`lean/` はそれを Lake の依存として取り込む（`lean/LangSemantics/` には写さない）。本項目は、ATRS で不足する演算と検査を **assets 側に** 追加する作業として行う。

## 目的

[Source] の運賃計算・文字列長・日付演算を証明可能に表すため。

## 範囲

- `LangSemantics.Java.Int32`（`BitVec 32`、`j32add`, `j32sub`, `j32mul`, `jdiv32`）
- `LangSemantics.Java.JDouble`（有理数＋RNE 丸め。`jd`, `jdLit`, `jdmul`, `jdsub`, `jd2i`）
- `LangSemantics.Java.BigDecimal`（`setScale(-2, UP)` と `intValue`）
- `LangSemantics.Java.String`（UTF-16 長、`trim`、`split`）
- `LangSemantics.Java.LocalDate`（`plusDays`, `isBefore`, `ChronoUnit.YEARS.between`）

## 対象外

- ATRS 固有の型・関数
- 汎用の IEEE 754（除算・平方根など原典で使わない演算）

## 完了条件

- [x] `jdLit("0.01")` のビット表現が `0x3F847AE147AE147B` であることを証明した
- [x] `jdmul`, `jdsub`, `jd2i` がネイティブ `Float` とビット単位で一致することを、原典の値域を覆う入力で突き合わせた
- [x] `BigDecimal`・`String`・`LocalDate` の写した演算を、JVM の実行結果と固定した入力の表で突き合わせた
- [x] 突き合わせた入力の範囲を [assurance.md](../spec/assurance.md) に記載した
- [x] `jd2i(jdmul(jd(1430), jdsub(jd(1), jdmul(jd(30), jdLit("0.01")))))` が 1000 になることを確認した
- [x] ATRS 固有モジュールを import していない

## 結果

- assets（`.agents/skills/port-lang/assets/`）
  - `LangSemantics/Java/Double.lean`: 定理を追加した。
    - `jdLit_0_01_bits`: `jdLit "0.01"` のビット表現が `0x3F847AE147AE147B`
    - `jd2i_1430_30`: 1430 円・30% の例が 1000
    - どちらも `decide` で示し、公理は `propext`・`Classical.choice`・`Quot.sound` の範囲に収まる
  - `LangSemantics/Java/LocalDate.lean`: ADR 0005 の `minusDays` を追加した。
  - `LangSemanticsTest/jvm/JavaTable.java`: JVM で固定の入力表を計算し、`#guard` を生成する。生成物 `LangSemanticsTest/JavaJvm.lean` には 581 件の `#guard` があり、すべて通る。
- ATRS（`lean/Tests/JavaDouble.lean`）: 運賃計算の [Source] の double 式を、ネイティブ `Float` とビット単位で 4,006,212 件突き合わせ、すべて一致した。範囲は [assurance.md](../spec/assurance.md) に書いた。
- CI
  - `tools/ci/lean.sh` が JVM 表を再生成し、コミット済みのものと差分が無いことを確かめる。
  - `.github/workflows/lean.yml` で Temurin 17 を使う（上流の Java の版）。
- `String.split` は 1 文字の区切りだけを扱う（`jSplitChar`）。正規表現の区切りは、必要になった時点で足す。

## 参照

- [ADR 0005](../decision/0005-java-primitive-semantics.md)
- [ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md)
